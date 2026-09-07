export 'excel_download_stub.dart'
    if (dart.library.io) 'excel_download_io.dart'
    if (dart.library.html) 'excel_download_web.dart';
