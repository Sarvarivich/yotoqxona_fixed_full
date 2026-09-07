#!/usr/bin/env node
/**
 * One-time Firestore migration for yotoqxona.
 *
 * Purpose:
 *   Ensure foydalanuvchilar/{uid}.hostel exists before enabling
 *   server-side hostel queries/pagination in the Flutter UI.
 *
 * Safety:
 *   - Default mode is DRY RUN. Nothing is written.
 *   - Existing non-empty hostel values are never overwritten.
 *   - A missing hostel is inferred from an assigned room when possible.
 *   - If it cannot be inferred safely, the user is reported as ambiguous.
 *   - No role, password, room assignment, or other field is changed.
 *
 * Run:
 *   node scripts/migrate_hostel_field.js
 *   node scripts/migrate_hostel_field.js --apply
 *
 * Authentication:
 *   Set GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON file.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();

const APPLY = process.argv.includes('--apply');
const BATCH_SIZE = 400;

function normalizeHostel(value) {
  const v = String(value ?? '').trim().toLowerCase();
  if (!v) return null;
  if (['boys', 'boy', 'male', 'erkak', "o'g'il", 'ogil'].includes(v)) return 'boys';
  if (['girls', 'girl', 'female', 'ayol', 'qiz'].includes(v)) return 'girls';
  return v;
}

function inferFromGender(data) {
  const raw = String(
    data.gender ?? data.jins ?? data.sex ?? data.genderType ?? ''
  ).trim().toLowerCase();
  if (!raw) return null;
  if (['female', 'f', 'girl', 'girls', 'qiz', 'qizlar', 'ayol', 'ayollar'].includes(raw)) return 'girls';
  if (['male', 'm', 'boy', 'boys', 'erkak', 'erkaklar', "o'g'il", 'ogil', 'o\'gil'].includes(raw)) return 'boys';
  return null;
}

async function main() {
  console.log(`\nHostel migration mode: ${APPLY ? 'APPLY' : 'DRY RUN'}`);

  const [usersSnap, roomsSnap] = await Promise.all([
    db.collection('foydalanuvchilar').get(),
    db.collection('xonalar').get(),
  ]);

  // One-time room map: student UID -> normalized hostel.
  // If a student appears in conflicting rooms, we do NOT guess.
  const roomHostels = new Map();
  const conflicts = new Set();

  for (const roomDoc of roomsSnap.docs) {
    const room = roomDoc.data() || {};
    const hostel = normalizeHostel(room.hostel);
    if (!hostel) continue;
    const ids = Array.isArray(room.studentIds) ? room.studentIds : [];
    for (const uid of ids) {
      if (!uid) continue;
      if (roomHostels.has(uid) && roomHostels.get(uid) !== hostel) {
        conflicts.add(uid);
      } else {
        roomHostels.set(uid, hostel);
      }
    }
  }

  const updates = [];
  const ambiguous = [];
  const alreadySet = [];

  for (const doc of usersSnap.docs) {
    const data = doc.data() || {};
    const existing = normalizeHostel(data.hostel);

    if (existing) {
      alreadySet.push(doc.id);
      continue;
    }

    let inferred = null;
    let source = null;

    if (roomHostels.has(doc.id) && !conflicts.has(doc.id)) {
      inferred = roomHostels.get(doc.id);
      source = 'room';
    }

    if (!inferred) {
      inferred = inferFromGender(data);
      if (inferred) source = 'gender';
    }

    if (!inferred) {
      ambiguous.push({
        uid: doc.id,
        role: data.role ?? null,
        fullName: data.fullName ?? '',
        email: data.email ?? '',
        reason: conflicts.has(doc.id) ? 'conflicting_room_hostel' : 'not_inferable',
      });
      continue;
    }

    updates.push({ uid: doc.id, hostel: inferred, source });
  }

  console.log(`Users total:              ${usersSnap.size}`);
  console.log(`Rooms total:              ${roomsSnap.size}`);
  console.log(`Already have hostel:      ${alreadySet.length}`);
  console.log(`Safe updates:             ${updates.length}`);
  console.log(`Ambiguous / skipped:      ${ambiguous.length}`);

  const byHostel = {};
  for (const item of updates) byHostel[item.hostel] = (byHostel[item.hostel] || 0) + 1;
  console.log('Updates by hostel:', byHostel);

  if (ambiguous.length) {
    console.log('\nAmbiguous users (first 30):');
    for (const item of ambiguous.slice(0, 30)) {
      console.log(`- ${item.uid} | ${item.fullName} | ${item.role} | ${item.reason}`);
    }
  }

  if (!APPLY) {
    console.log('\nDRY RUN: no Firestore documents were changed.');
    console.log('If the counts look correct, run again with --apply.');
    return;
  }

  let written = 0;
  for (let i = 0; i < updates.length; i += BATCH_SIZE) {
    const chunk = updates.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const item of chunk) {
      batch.update(db.collection('foydalanuvchilar').doc(item.uid), {
        hostel: item.hostel,
        hostelMigrationSource: item.source,
        hostelMigrationAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    written += chunk.length;
    console.log(`Written ${written}/${updates.length}`);
  }

  console.log(`\nMigration completed. Updated: ${written}`);
  if (ambiguous.length) {
    console.log('Ambiguous users were intentionally left unchanged.');
  }
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exitCode = 1;
});
