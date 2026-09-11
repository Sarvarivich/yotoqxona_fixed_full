// Qo'llab-quvvatlanmagan platformalar uchun zaxira implementatsiya.
//
// Amalda bu fayl deyarli hech qachon ishlatilmaydi: excel_download.dart
// dart:io bor platformalarda excel_download_io.dart ni, brauzerda esa
// excel_download_web.dart ni tanlaydi.

Future<String> downloadExcelBytes(List<int> bytes, String fileName) async {
  throw UnsupportedError(
    'Bu platformada Excel faylni saqlash qo\'llab-quvvatlanmaydi.',
  );
}
