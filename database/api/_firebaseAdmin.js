// Vercel serverless funksiyalar orasida Firebase Admin SDK'ni
// bir marta ishga tushiradi (cold start'larda qayta-qayta
// initializeApp() chaqirilmasligi uchun).
const admin = require("firebase-admin");

if (!admin.apps.length) {
  const base64Key = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;

  if (!base64Key) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_BASE64 muhit o'zgaruvchisi Vercel'da o'rnatilmagan."
    );
  }

  const serviceAccount = JSON.parse(
    Buffer.from(base64Key, "base64").toString("utf-8")
  );

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

module.exports = admin;
