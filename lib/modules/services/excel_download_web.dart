// Flutter Web uchun Excel faylni yuklab olish.
//
// Brauzerda "Downloads" papkasi ilova nazoratida emas — fayl
// vaqtinchalik havola (blob URL) orqali beriladi va brauzer uni
// o'z sozlamalariga ko'ra saqlaydi.

// ignore: deprecated_member_use
import 'dart:html' as html;

Future<String> downloadExcelBytes(List<int> bytes, String fileName) async {
  final blob = html.Blob([
    bytes,
  ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

  final url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();

  // Havolani darhol bo'shatamiz — aks holda xotirada qolib ketadi.
  html.Url.revokeObjectUrl(url);

  // Brauzerda aniq yo'l noma'lum, shuning uchun bo'sh satr.
  return '';
}
