# Hostel field migration

This is a one-time, safe migration for `foydalanuvchilar/{uid}.hostel`.

## Why

The production query optimization needs a reliable `hostel` field. Older
student documents may not contain it. This migration fills only missing values.

## Safety

- Default execution is **dry-run**.
- Existing `hostel` values are never overwritten.
- Assigned room data is used first.
- Gender is used only when it is an explicit, recognizable value.
- Conflicting or unknown cases are skipped and printed.
- No password, role, room assignment, or other user data is modified.

## Run from project root

```bash
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\service-account.json
node scripts/migrate_hostel_field.js
```

If the dry-run counts are correct:

```bash
node scripts/migrate_hostel_field.js --apply
```

On PowerShell:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account.json"
node scripts/migrate_hostel_field.js
```

## After migration

Verify that every intended user has `hostel`. Only after that should the Flutter
list screens switch from client-side fallback filtering to strict Firestore
`where('hostel', isEqualTo: ...)` queries and pagination.
