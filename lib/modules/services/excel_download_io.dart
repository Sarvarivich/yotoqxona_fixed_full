// Mobil / Desktop (dart:io mavjud bo'lgan platformalar) uchun Excel faylni
// vaqtinchalik papkaga yozib, so'ng ulashish (share) oynasini ochadigan
// implementatsiya.
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadExcelBytes(List<int> bytes, String fileName) async {
  final Directory dir = await getTemporaryDirectory();
  final String path = '${dir.path}/$fileName';
  final File file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path)],
      text: fileName,
    ),
  );
}