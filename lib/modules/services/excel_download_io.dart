// Mobil / Desktop (dart:io mavjud bo'lgan platformalar) uchun Excel
// faylni saqlash.
//
// Platformaga qarab ikki xil ishlaydi:
//
//   Windows / macOS / Linux — fayl to'g'ridan-to'g'ri "Downloads"
//   papkasiga yoziladi. Desktopda ulashish oynasi ma'nosiz: odam
//   faylni ochmoqchi, birovga yubormoqchi emas.
//
//   Android / iOS — vaqtinchalik papkaga yozilib, ulashish oynasi
//   ochiladi. Telefonda bu to'g'ri xatti-harakat, chunki foydalanuvchi
//   faylni Telegram, pochta yoki Drive'ga yuborishi mumkin.
//
// Qaytaradi: saqlangan faylning to'liq yo'li (desktopda) yoki
// bo'sh satr (mobil qurilmada, ulashish oynasi ochilgani uchun).

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Nomi band bo'lsa, oxiriga raqam qo'shadi:
/// "hisobot.xlsx" -> "hisobot (1).xlsx" -> "hisobot (2).xlsx"
File _bandBolmaganFayl(Directory papka, String fileName) {
  final nuqta = fileName.lastIndexOf('.');
  final asos = nuqta > 0 ? fileName.substring(0, nuqta) : fileName;
  final kengaytma = nuqta > 0 ? fileName.substring(nuqta) : '';

  var fayl = File('${papka.path}${Platform.pathSeparator}$fileName');
  var n = 1;
  while (fayl.existsSync()) {
    fayl = File(
      '${papka.path}${Platform.pathSeparator}$asos ($n)$kengaytma',
    );
    n++;
    if (n > 999) break; // cheksiz aylanishdan himoya
  }
  return fayl;
}

/// Desktop uchun "Downloads" papkasini topadi.
///
/// path_provider Windows va macOS'da getDownloadsDirectory() ni
/// qo'llab-quvvatlaydi. Linux'da yoki topilmasa — hujjatlar
/// papkasiga tushamiz.
Future<Directory> _yuklashPapkasi() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      if (!downloads.existsSync()) {
        await downloads.create(recursive: true);
      }
      return downloads;
    }
  } catch (_) {
    // getDownloadsDirectory ba'zi platformalarda mavjud emas
  }

  // Zaxira variant: foydalanuvchi hujjatlari papkasi
  return await getApplicationDocumentsDirectory();
}

Future<String> downloadExcelBytes(List<int> bytes, String fileName) async {
  final desktop =
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  if (desktop) {
    final papka = await _yuklashPapkasi();
    final fayl = _bandBolmaganFayl(papka, fileName);
    await fayl.writeAsBytes(bytes, flush: true);
    return fayl.path;
  }

  // Mobil: vaqtinchalik papkaga yozib, ulashish oynasini ochamiz.
  final vaqtinchalik = await getTemporaryDirectory();
  final yol = '${vaqtinchalik.path}/$fileName';
  final fayl = File(yol);
  await fayl.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(yol)],
      text: fileName,
    ),
  );

  return '';
}
