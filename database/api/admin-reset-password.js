const admin = require("./_firebaseAdmin");

module.exports = async (req, res) => {
  // Flutter web ilova boshqa origin'dan chaqirishi mumkin bo'lgani uchun CORS
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Faqat POST so'rovlar qabul qilinadi." });
  }

  try {
    // 1) Chaqiruvchining Firebase ID tokenini tekshiramiz
    const authHeader = req.headers.authorization || "";
    const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

    if (!idToken) {
      return res.status(401).json({ error: "Avtorizatsiya tokeni topilmadi." });
    }

    const decoded = await admin.auth().verifyIdToken(idToken);

    // 2) Chaqiruvchi rolini Firestore'dan tekshiramiz
    const callerDoc = await admin
      .firestore()
      .collection("foydalanuvchilar")
      .doc(decoded.uid)
      .get();

    const callerRole = callerDoc.exists ? callerDoc.data().role : null;

    if (callerRole !== "admin" && callerRole !== "superAdmin") {
      return res.status(403).json({
        error: "Faqat admin yoki superAdmin boshqa foydalanuvchi parolini o'zgartira oladi.",
      });
    }

    // 3) So'rov tanasini tekshiramiz
    const { uid, newPassword } = req.body || {};

    if (!uid || typeof uid !== "string") {
      return res.status(400).json({ error: "Foydalanuvchi UID si noto'g'ri." });
    }
    if (!newPassword || typeof newPassword !== "string" || newPassword.length < 6) {
      return res.status(400).json({ error: "Parol kamida 6 belgidan iborat bo'lishi kerak." });
    }

    // 4) Parolni yangilaymiz
    await admin.auth().updateUser(uid, { password: newPassword });

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error("admin-reset-password xatosi:", error);
    return res.status(500).json({
      error: `Parolni yangilashda xatolik: ${error.code || ""} ${error.message || error}`,
    });
  }
};
