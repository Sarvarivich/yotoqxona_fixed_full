/**
 * Bir martalik skript: 'xonalar' to'plamidagi barcha "girls" (qizlar)
 * xonalarining 'status' maydonini haqiqiy bandlikka (studentIds soni)
 * moslab qo'yadi.
 *
 * Qoida:
 *   - Agar xona "ta'mirlashda" (renovation) bo'lsa — TEGILMAYDI (bu holat
 *     qo'lda boshqariladi).
 *   - Aks holda: studentIds bo'sh bo'lsa -> status = "empty"
 *                studentIds bo'sh bo'lmasa -> status = "occupied"
 *
 * ISHLATISH:
 *   1) `firebase-admin` o'rnatilgan bo'lishi kerak:
 *        npm install firebase-admin
 *   2) Firebase Console'dan yuklab olingan service account JSON faylini
 *      shu skript bilan bir papkaga qo'ying va nomini quyidagi
 *      SERVICE_ACCOUNT_PATH ga mos qiling (yoki to'liq yo'lini yozing).
 *   3) Ishga tushiring:
 *        node fix_room_status.js
 */

const admin = require("firebase-admin");

// ⚠️ Bu yerga service account JSON faylingizning nomini/yo'lini yozing.
const SERVICE_ACCOUNT_PATH = "./yotoqxona-fe7ab-firebase-adminsdk-fbsvc-ba4d6689b3.json";

admin.initializeApp({
  credential: admin.credential.cert(require(SERVICE_ACCOUNT_PATH)),
});

const db = admin.firestore();

async function main() {
  console.log("🔎 'xonalar' to'plamidan qizlar xonalarini o'qiyapman...");
  const snapshot = await db.collection("xonalar").get();

  let checked = 0;
  let updated = 0;
  let skippedRenovation = 0;

  const batch = db.batch();
  let batchCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const hostel = (data.hostel || "").toString().trim().toLowerCase();
    if (hostel !== "girls") continue; // faqat qizlar xonalari

    checked++;

    const currentStatus = (data.status || "").toString();
    if (currentStatus === "renovation") {
      skippedRenovation++;
      continue; // ta'mirlashda bo'lsa tegilmaymiz
    }

    const studentIds = Array.isArray(data.studentIds) ? data.studentIds : [];
    const correctStatus = studentIds.length > 0 ? "occupied" : "empty";

    if (currentStatus !== correctStatus) {
      batch.update(doc.ref, {
        status: correctStatus,
        currentOccupants: studentIds.length,
      });
      batchCount++;
      updated++;
      console.log(
        `  ✏️  ${data.roomNumber ?? doc.id}-xona: "${currentStatus || "(bo'sh)"}" -> "${correctStatus}" (${studentIds.length} talaba)`
      );

      // Firestore batch cheklovi 500 ta — shu chegaraga yetsa alohida commit qilamiz
      if (batchCount >= 450) {
        await batch.commit();
        batchCount = 0;
      }
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log("\n✅ Tugadi!");
  console.log(`   Tekshirilgan qizlar xonalari: ${checked}`);
  console.log(`   Yangilangan xonalar: ${updated}`);
  console.log(`   "Ta'mirlashda" bo'lgani uchun tegilmagan: ${skippedRenovation}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ Xatolik:", err);
    process.exit(1);
  });
