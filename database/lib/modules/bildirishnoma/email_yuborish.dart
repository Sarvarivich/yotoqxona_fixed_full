import 'package:flutter/foundation.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();

  factory EmailService() {
    return _instance;
  }

  EmailService._internal();

  /// 🚀 Agar kelajakda kerak bo‘lsa (SMTP/API uchun)
  Future<void> initialize() async {
    debugPrint("EmailService initialized");
  }

  /// 📩 EMAIL YUBORISH (mock / backend ulansa shu yerga yoziladi)
  static Future<void> sendEmail({
    required String toEmail,
    required String subject,
    required String message,
  }) async {
    debugPrint("📩 Email yuborildi");
    debugPrint("To: $toEmail");
    debugPrint("Subject: $subject");
    debugPrint("Message: $message");

    // TODO: SMTP yoki API integration shu yerga yoziladi
  }
}
