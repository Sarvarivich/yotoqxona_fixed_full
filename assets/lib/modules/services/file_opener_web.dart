import 'dart:typed_data';
import 'dart:html' as html;

/// Web'da faylni brauzer orqali yuklab olishni ishga tushiradi.
/// Xatolik bo'lsa matn qaytaradi, muvaffaqiyatli bo'lsa `null` qaytaradi.
Future<String?> openOrDownloadFile(Uint8List bytes, String fileName) async {
  try {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
    return null;
  } catch (e) {
    return "Yuklab olishda xatolik: $e";
  }
}
