const admin = require("./_firebaseAdmin");

module.exports = async (req, res) => {
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
    const authHeader = req.headers.authorization || "";
    const idToken = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

    if (!idToken) {
      return res.status(401).json({ error: "Avtorizatsiya tokeni topilmadi." });
    }

    const decoded = await admin.auth().verifyIdToken(idToken);

    const callerDoc = await admin
      .firestore()
      .collection("foydalanuvchilar")
      .doc(decoded.uid)
      .get();

    const callerRole = callerDoc.exists ? callerDoc.data().role : null;

    if (callerRole !== "admin" && callerRole !== "superAdmin") {
      return res.status(403).json({
        error: "Faqat admin yoki superAdmin foydalanuvchini o'chira oladi.",
      });
    }

    const { uid } = req.body || {};
    if (!uid || typeof uid !== "string") {
      return res.status(400).json({ error: "Foydalanuvchi UID si noto'g'ri." });
    }

    try {
      await admin.auth().deleteUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") {
        throw error;
      }
    }

    await admin.firestore().collection("foydalanuvchilar").doc(uid).delete();

    return res.status(200).json({ success: true });
  } catch (error) {
    console.error("delete-user xatosi:", error);
    return res.status(500).json({
      error: `O'chirishda xatolik: ${error.code || ""} ${error.message || error}`,
    });
  }
};
