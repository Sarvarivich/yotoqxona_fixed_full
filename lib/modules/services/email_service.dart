import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  static const String serviceId = "YOUR_SERVICE_ID";
  static const String templateId = "YOUR_TEMPLATE_ID";
  static const String publicKey = "YOUR_PUBLIC_KEY";

  static Future<void> sendEmail({
    required String toEmail,
    required String subject,
    required String message,
  }) async {
    final url = Uri.parse("https://api.emailjs.com/api/v1.0/email/send");

    await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "service_id": serviceId,
        "template_id": templateId,
        "user_id": publicKey,
        "template_params": {
          "to_email": toEmail,
          "subject": subject,
          "message": message,
        }
      }),
    );
  }
}
