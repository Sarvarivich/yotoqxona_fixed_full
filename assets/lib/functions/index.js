/**
 * Firebase Cloud Functions — yotoqxona loyihasi
 * ------------------------------------------------
 * Bu fayl loyihaning ILDIZ (root) katalogidagi `functions/` papkasida
 * turishi SHART — `firebase.json` faylida ko'rsatilgan `"source": "functions"`
 * aynan shu joyni ko'zda tutadi. `lib/functions/index.js` da turgan nusxa
 * hech qachon deploy qilinmagan edi, shuning uchun `adminResetPassword`
 * chaqirilganda Firebase "internal" xatoligini qaytargan.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// ─── 1. Foydalanuvchi parolini admin/superAdmin tomonidan yangilash ───
exports.adminResetPassword = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Bu amalni bajarish uchun tizimga kirgan bo'lishingiz kerak."
    );
  }

  const { uid, newPassword } = data;

  if (!uid || typeof uid !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Foydalanuvchi UID si noto'g'ri."
    );
  }
  if (!newPassword || typeof newPassword !== "string" || newPassword.length < 6) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Parol kamida 6 belgidan iborat bo'lishi kerak."
    );
  }

  try {
    const callerDoc = await admin
      .firestore()
      .collection("foydalanuvchilar")
      .doc(context.auth.uid)
      .get();

    const callerRole = callerDoc.exists ? callerDoc.data().role : null;

    if (callerRole !== "admin" && callerRole !== "superAdmin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Faqat admin yoki superAdmin boshqa foydalanuvchi parolini o'zgartira oladi."
      );
    }

    await admin.auth().updateUser(uid, { password: newPassword });
    return { success: true };
  } catch (error) {
    // Agar bu allaqachon HttpsError bo'lsa (masalan permission-denied),
    // uni o'zgartirmasdan qayta uzatamiz. Aks holda haqiqiy sabab bilan
    // aniq "internal" xatolik qaytaramiz — shunda clientda "internal"
    // so'zi emas, aniq sabab ko'rinadi.
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "internal",
      `Parolni yangilashda xatolik: ${error.code || ""} ${error.message || error}`
    );
  }
});

// ─── 2. Foydalanuvchini to'liq o'chirish (Auth + Firestore) ───
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Bu amalni bajarish uchun tizimga kirgan bo'lishingiz kerak."
    );
  }

  const { uid } = data;
  if (!uid || typeof uid !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Foydalanuvchi UID si noto'g'ri."
    );
  }

  const callerDoc = await admin
    .firestore()
    .collection("foydalanuvchilar")
    .doc(context.auth.uid)
    .get();

  const callerRole = callerDoc.exists ? callerDoc.data().role : null;

  if (callerRole !== "admin" && callerRole !== "superAdmin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Faqat admin yoki superAdmin foydalanuvchini o'chira oladi."
    );
  }

  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") {
      throw new functions.https.HttpsError("internal", error.message);
    }
  }

  await admin.firestore().collection("foydalanuvchilar").doc(uid).delete();

  return { success: true };
});
