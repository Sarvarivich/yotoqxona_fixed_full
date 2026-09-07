import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

/// Android/iOS/Desktop'da faylni vaqtinchalik papkaga yozib,
/// qurilmadagi standart dastur bilan ochadi.
/// Xatolik bo'lsa matn qaytaradi, muvaffaqiyatli bo'lsa `null` qaytaradi.
Future<String?> openOrDownloadFile(Uint8List bytes, String fileName) async {
  try {
    final dir = await getTemporaryDirectory();
    final safeName = fileName.isEmpty ? 'chek_fayli' : fileName;
    final filePath = '${dir.path}/$safeName';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      return "Faylni ochib bo'lmadi: ${result.message}";
    }
    return null;
  } catch (e) {
    return "Faylni ochishda xatolik: $e";
  }
}
