// ✅ Platformaga qarab to'g'ri implementatsiyani tanlaydi:
// - Web bo'lsa → file_opener_web.dart (brauzer orqali yuklab olish)
// - Android/iOS/Desktop bo'lsa → file_opener_io.dart (vaqtinchalik faylga
//   yozib, standart dastur bilan ochish)
export 'file_opener_stub.dart'
    if (dart.library.html) 'file_opener_web.dart'
    if (dart.library.io) 'file_opener_io.dart';