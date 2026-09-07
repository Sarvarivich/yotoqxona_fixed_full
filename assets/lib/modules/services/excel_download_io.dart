// Platformaga (Web / Mobil-Desktop) qarab to'g'ri implementatsiyani tanlaydi.
// - Web (dart:html mavjud) -> excel_download_web.dart
// - Mobil/Desktop (dart:io mavjud) -> excel_download_io.dart
// - Boshqa hech biri mos kelmasa -> excel_download_stub.dart
export 'excel_download_stub.dart'
    if (dart.library.io) 'excel_download_io.dart'
    if (dart.library.html) 'excel_download_web.dart';
