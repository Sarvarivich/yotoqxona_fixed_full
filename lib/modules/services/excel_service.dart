import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import '../models/user_model.dart';
import 'excel_download.dart';

// Xonaning narxi va o'qish uchun qulay nomi (masalan "101-xona").
class _RoomInfo {
  final String label;
  final double price;
  const _RoomInfo({required this.label, required this.price});
}

// Ikkala hostel (o'g'il/qiz bolalar) uchun umumiy, manbasidan qat'iy
// nazar bir xil ko'rinishdagi eksport qatori. Bu orqali "foydalanuvchilar"
// (o'zi ro'yxatdan o'tgan, Firebase Auth hisobiga ega) va "girls_students"
// (Admin/Mudira tomonidan qo'lda qo'shilgan, Auth hisobisiz) talabalari
// bitta jadvalda bir xil ustunlar bilan chiqariladi.
class _ExportRow {
  final String id;
  final String fullName;
  final DateTime? birthDate;
  final String? region;
  final String? district;
  final String email;
  final String phoneNumber;
  final String? faculty;
  final String? course; // Joriy kurs: '1', '2', '3' yoki '4'
  final String? hostel;
  final String? roomId;
  final DateTime? createdAt;
  final String? registeredBy;
  final String? passportId;
  final String? jshshir;
  // 🎗️ Ijtimoiy imtiyoz — ro'yxatdan o'tishda tanlangan bo'lsa
  final bool hasSocialBenefit;
  final String? benefitType; // '1'..'6'
  final String? lostParentType; // faqat benefitType == '1' uchun: 'ota'/'ona'
  final String? deathCertificateUrl;
  final String? benefitDocumentUrl;

  _ExportRow({
    required this.id,
    required this.fullName,
    this.birthDate,
    this.region,
    this.district,
    required this.email,
    required this.phoneNumber,
    this.faculty,
    this.course,
    this.hostel,
    this.roomId,
    this.createdAt,
    this.registeredBy,
    this.passportId,
    this.jshshir,
    this.hasSocialBenefit = false,
    this.benefitType,
    this.lostParentType,
    this.deathCertificateUrl,
    this.benefitDocumentUrl,
  });
}

class ExcelExportService {
  // Rol nomini o'qish uchun chiroyli formatga o'giradi.
  static String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.mudir:
        return 'Yotoqxona Mudiri';
      case UserRole.moliyachi:
        return 'Moliyachi';
      case UserRole.talaba:
        return 'Talaba';
    }
  }

  // Yotoqxona turini o'qish uchun chiroyli formatga o'giradi.
  // ⚠️ Ilovaning boshqa barcha joylarida (login, dashboard, mudir_screen,
  // talaba profili va h.k.) "hostel" maydoni bo'sh (null) bo'lsa, u
  // avtomatik "boys" deb qabul qilinadi (masalan: `user.hostel ?? 'boys'`).
  // Odatda bu — Firestore'da "hostel" maydoni umuman yozilmagan eski
  // hisoblar (masalan superAdmin/admin/mudir sifatida ilova boshida qo'lda
  // yaratilgan yozuvlar). Shu sababli bu yerda ham xuddi shu qoidaga rioya
  // qilinadi — aks holda ular "Ko'rsatilmagan" bo'lib chiqib, aslida
  // qaysi yotoqxonaga tegishli ekani noaniq bo'lib qolardi.
  static String _hostelLabel(String? hostel) {
    switch (hostel ?? 'boys') {
      case 'girls':
        return 'Qiz bolalar yotoqxonasi';
      case 'boys':
      default:
        return "O'g'il bolalar yotoqxonasi";
    }
  }

  // "Kun.Oy.Yil" formatida sana (masalan: tug'ilgan sana uchun).
  static String _formatDate(DateTime? dt) {
    if (dt == null) return "Kiritilmagan";
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year}";
  }

  // "Kun.Oy.Yil Soat:Daqiqa" formatida sana+vaqt (ro'yxatdan o'tgan vaqt uchun).
  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return "Noma'lum";
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  // Talaba o'zi ro'yxatdan o'tganmi yoki Admin/Mudir tomonidan
  // qo'lda qo'shilganmi — o'qish uchun qulay matnga o'giradi.
  static String _registeredByLabel(String? registeredBy) {
    switch (registeredBy) {
      case 'self':
        return "O'zi ro'yxatdan o'tgan";
      case 'admin':
        return "Admin tomonidan qo'shilgan";
      default:
        // Bu maydon qo'shilishidan oldingi eski hisoblar uchun.
        return "Noma'lum (eski hisob)";
    }
  }

  // Imtiyoz turi kodini ('1'..'6') o'qish uchun to'liq matnga o'giradi.
  static String _benefitTypeLabel(String? type) {
    switch (type) {
      case '1':
        return "Boquvchini yo'qotgan talaba";
      case '2':
        return "1 yoki 2 guruh nogironligi bo'lgan talaba";
      case '3':
        return "To'liq davlat ta'minotida bo'lgan talaba (chin yetim)";
      case '4':
        return "Temir daftariga tushgan talaba";
      case '5':
        return "Yoshlar daftariga tushgan talaba";
      case '6':
        return "Ayollar daftariga tushgan talaba";
      default:
        return "Kiritilmagan";
    }
  }

  // 'ota' / 'ona' kodini o'qish uchun matnga o'giradi.
  static String _lostParentLabel(String? value) {
    switch (value) {
      case 'ota':
        return 'Ota';
      case 'ona':
        return 'Ona';
      default:
        return "Tegishli emas";
    }
  }

  // Rol bo'yicha tartiblash uchun ustuvorlik (Excel'da yuqorida ko'rinishi
  // kerak bo'lgan lavozimlar birinchi qatorlarda chiqadi).
  static int _rolePriority(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 0;
      case UserRole.admin:
        return 1;
      case UserRole.mudir:
        return 2;
      case UserRole.moliyachi:
        return 3;
      case UserRole.talaba:
        return 4;
    }
  }

  /// Barcha foydalanuvchilarni (o'g'il bolalar VA qiz bolalar yotoqxonasi,
  /// barcha rollar — superAdmin/admin/mudir/moliyachi/talaba) bitta Excel
  /// faylga eksport qiladi. Har bir qatorda foydalanuvchining roli va
  /// yotoqxonasi ham ko'rsatiladi.
  static Future<void> exportAllUsersToExcel() async {
    try {
      // 1. Firebase Firestore'dan BARCHA foydalanuvchilarni olamiz —
      // hech qanday role yoki hostel filtri qo'llanilmaydi, shuning
      // uchun qizlar yotoqxonasidagi hisoblar ham ro'yxatga kiradi.
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('foydalanuvchilar').get();

      if (snapshot.docs.isEmpty) {
        print("Eksport qilish uchun foydalanuvchilar topilmadi.");
        return;
      }

      // 2. UserModel'ga o'giramiz va o'qish qulay bo'lishi uchun
      // avval yotoqxona, so'ng rol, so'ng F.I.O bo'yicha tartiblaymiz.
      final users = snapshot.docs
          .map((doc) => MapEntry(
              doc.id, UserModel.fromJson(doc.data() as Map<String, dynamic>)))
          .toList()
        ..sort((a, b) {
          final hostelCmp =
              (a.value.hostel ?? 'boys').compareTo(b.value.hostel ?? 'boys');
          if (hostelCmp != 0) return hostelCmp;
          final roleCmp = _rolePriority(a.value.role)
              .compareTo(_rolePriority(b.value.role));
          if (roleCmp != 0) return roleCmp;
          return a.value.fullName.compareTo(b.value.fullName);
        });

      // 3. Excel yaratish
      var excel = Excel.createExcel();
      String sheetName = "Foydalanuvchilar Ro'yxati";
      Sheet sheetObject = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // 4. JADVAL BOSHI (Header) — CellValue orqali yoziladi.
      // Rol va Yotoqxona ustunlari qo'shildi.
      sheetObject.appendRow([
        TextCellValue("T/r"),
        TextCellValue("Foydalanuvchi ID"),
        TextCellValue("To'liq ismi (F.I.O)"),
        TextCellValue("Email"),
        TextCellValue("Telefon raqami"),
        TextCellValue("Rol"),
        TextCellValue("Yotoqxona turi"),
        TextCellValue("Xona raqami"),
      ]);

      // 5. MA'LUMOTLARNI QATORMA-QATOR QO'SHISH
      int index = 1;
      for (final entry in users) {
        final docId = entry.key;
        final user = entry.value;

        sheetObject.appendRow([
          IntCellValue(index), // int turi uchun IntCellValue
          TextCellValue(docId), // String turlari uchun TextCellValue
          TextCellValue(user.fullName),
          TextCellValue(user.email),
          TextCellValue(user.phoneNumber),
          TextCellValue(_roleLabel(user.role)),
          TextCellValue(_hostelLabel(user.hostel)),
          TextCellValue(user.roomId ?? "Biriktirilmagan"),
        ]);
        index++;
      }

      // 6. Faylni platformaga mos usulda yuklab olish / ulashish
      // (Web'da brauzer orqali yuklanadi, mobil/desktopda vaqtinchalik
      // papkaga yozilib ulashish oynasi ochiladi)
      final List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        await downloadExcelBytes(
          fileBytes,
          'Yotoqxona_Foydalanuvchilar_Ruyxati.xlsx',
        );
      }
    } catch (e) {
      print("Excel eksportda xatolik: $e");
      rethrow;
    }
  }

  // Eski nom bilan chaqiruvchi joylar buzilmasligi uchun qoldirilgan
  // moslashuvchi (compatibility) qatlam — endi bu ham BARCHA
  // foydalanuvchilarni (talaba bilan cheklanmagan holda) eksport qiladi.
  @Deprecated('Buning o\'rniga exportAllUsersToExcel() dan foydalaning')
  static Future<void> exportTalabalarToExcel() => exportAllUsersToExcel();

  // "xonalar" kolleksiyasidan har bir xonaning narxi va o'qish uchun
  // qulay nomini ("101-xona") oladi. Xona ID ham, xona raqami ham
  // kalit sifatida qo'shiladi — chunki ilovada talabaning roomId
  // maydoniga ba'zan xonaning hujjat ID'si, ba'zan esa to'g'ridan-to'g'ri
  // xona RAQAMI yozilishi mumkin (qarang: qarzdorlar_royxati.dart).
  static Future<Map<String, _RoomInfo>> _fetchRoomInfoMap() async {
    final roomsSnap =
        await FirebaseFirestore.instance.collection('xonalar').get();
    final Map<String, _RoomInfo> map = {};
    for (final doc in roomsSnap.docs) {
      final d = doc.data();
      final price =
          (d['pricePerMonth'] as num? ?? d['monthlyRate'] as num? ?? 0)
              .toDouble();
      final roomNum = d['roomNumber'];
      final label = roomNum != null ? '$roomNum-xona' : 'Xona';
      final info = _RoomInfo(label: label, price: price);
      map[doc.id] = info;
      if (roomNum != null) map[roomNum.toString()] = info;
    }
    return map;
  }

  // Har bir talabaning BARCHA tasdiqlangan to'lovlari yig'indisi.
  // O'g'il bolalar uchun 'tolov_cheklari' (status == 'approved'),
  // qiz bolalar uchun 'girls_payments' (status == 'paid') manbalaridan.
  static Future<Map<String, double>> _fetchTotalPaidMap() async {
    final fs = FirebaseFirestore.instance;
    final Map<String, double> totalPaid = {};
    try {
      final checksSnap = await fs
          .collection('tolov_cheklari')
          .where('status', isEqualTo: 'approved')
          .get();
      for (final doc in checksSnap.docs) {
        final d = doc.data();
        final studentId = d['studentId'] as String?;
        if (studentId == null) continue;
        final amount = (d['amount'] as num? ?? 0).toDouble();
        totalPaid[studentId] = (totalPaid[studentId] ?? 0) + amount;
      }
    } catch (_) {}
    try {
      final girlsPaymentsSnap = await fs
          .collection('girls_payments')
          .where('status', isEqualTo: 'paid')
          .get();
      for (final doc in girlsPaymentsSnap.docs) {
        final d = doc.data();
        final studentId = d['studentId'] as String?;
        if (studentId == null || studentId.isEmpty) continue;
        final amount = (d['amount'] as num? ?? 0).toDouble();
        totalPaid[studentId] = (totalPaid[studentId] ?? 0) + amount;
      }
    } catch (_) {}
    return totalPaid;
  }

  // "120 000" kabi minglik bo'luvchi bo'shliqlar bilan formatlaydi.
  static String _formatSom(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(' ');
    }
    return "${buf.toString()} so'm";
  }

  // Xona raqamini o'qish uchun qulay "101-xona" ko'rinishida qaytaradi.
  static String _roomLabel(String? roomId, Map<String, _RoomInfo> roomInfo) {
    if (roomId == null || roomId.isEmpty) return "Biriktirilmagan";
    return roomInfo[roomId]?.label ?? "Biriktirilmagan";
  }

  // Xona to'lovi holati: xona narxidan talabaning tasdiqlangan
  // to'lovlari ayiriladi. Agar to'liq (yoki ortiqcha) to'langan bo'lsa
  // "0 so'm" chiqadi, aks holda qolgan qarz summasi (masalan
  // "120 000 so'm") ko'rsatiladi.
  static String _paymentStatusLabel(
    String studentId,
    String? roomId,
    Map<String, _RoomInfo> roomInfo,
    Map<String, double> totalPaid,
  ) {
    if (roomId == null || roomId.isEmpty) return "Xona biriktirilmagan";
    final info = roomInfo[roomId];
    if (info == null || info.price <= 0) return "Xona narxi belgilanmagan";
    final paid = totalPaid[studentId] ?? 0;
    final debt = info.price - paid;
    return _formatSom(debt < 0 ? 0 : debt);
  }

  /// Sarlavha qatorini (header) ikkala hostel eksporti uchun bir xil
  /// tartibda yozadi.
  static void _writeHeader(Sheet sheetObject) {
    sheetObject.appendRow([
      TextCellValue("T/r"),
      TextCellValue("Talaba ID"),
      TextCellValue("To'liq ismi (F.I.O)"),
      TextCellValue("Tug'ilgan sanasi"),
      TextCellValue("Viloyat"),
      TextCellValue("Tuman/Shahar"),
      TextCellValue("Email"),
      TextCellValue("Telefon raqami"),
      TextCellValue("Fakultet"),
      TextCellValue("Joriy kurs"),
      TextCellValue("Yotoqxona turi"),
      TextCellValue("Pasport seriya-raqami"),
      TextCellValue("JSHSHIR"),
      TextCellValue("Biriktirilgan xona raqami"),
      TextCellValue("Xona to'lovi holati (qarzi)"),
      TextCellValue("Ro'yxatdan o'tgan vaqti"),
      TextCellValue("Ro'yxatdan o'tish turi"),
      TextCellValue("Ijtimoiy imtiyoz"),
      TextCellValue("Imtiyoz turi"),
      TextCellValue("Boquvchi (ota/ona)"),
      TextCellValue("O'lim varaqasi (havola)"),
      TextCellValue("Imtiyoz ma'lumotnomasi (havola)"),
    ]);
  }

  /// Bitta `_ExportRow`ni Excel qatoriga yozadi.
  static void _writeRow(
    Sheet sheetObject,
    int index,
    _ExportRow row,
    Map<String, _RoomInfo> roomInfo,
    Map<String, double> totalPaid,
  ) {
    sheetObject.appendRow([
      IntCellValue(index),
      TextCellValue(row.id),
      TextCellValue(row.fullName),
      TextCellValue(_formatDate(row.birthDate)),
      TextCellValue(row.region ?? "Kiritilmagan"),
      TextCellValue(row.district ?? "Kiritilmagan"),
      TextCellValue(row.email.isEmpty ? "Kiritilmagan" : row.email),
      TextCellValue(row.phoneNumber),
      TextCellValue(row.faculty ?? "Kiritilmagan"),
      TextCellValue(row.course != null && row.course!.isNotEmpty
          ? "${row.course}-kurs"
          : "Kiritilmagan"),
      TextCellValue(_hostelLabel(row.hostel)),
      TextCellValue(row.passportId ?? "Kiritilmagan"),
      TextCellValue(row.jshshir ?? "Kiritilmagan"),
      TextCellValue(_roomLabel(row.roomId, roomInfo)),
      TextCellValue(
          _paymentStatusLabel(row.id, row.roomId, roomInfo, totalPaid)),
      TextCellValue(_formatDateTime(row.createdAt)),
      TextCellValue(_registeredByLabel(row.registeredBy)),
      TextCellValue(row.hasSocialBenefit ? "Ha" : "Yo'q"),
      TextCellValue(row.hasSocialBenefit
          ? _benefitTypeLabel(row.benefitType)
          : "Tegishli emas"),
      TextCellValue(row.benefitType == '1'
          ? _lostParentLabel(row.lostParentType)
          : "Tegishli emas"),
      TextCellValue(row.deathCertificateUrl ?? "Yuklanmagan"),
      TextCellValue(row.benefitDocumentUrl ?? "Yuklanmagan"),
    ]);
  }

  // "girls_students" kolleksiyasidagi (Admin/Mudira tomonidan qo'lda
  // qo'shilgan, Firebase Auth hisobisiz) talabalarni umumiy `_ExportRow`
  // ko'rinishiga o'giradi. Bu model 'foydalanuvchilar'dan farqli bo'lgani
  // uchun (email, pasport, JSHSHIR, tug'ilgan sana kabi maydonlar yo'q),
  // ular "Kiritilmagan" sifatida chiqadi.
  static List<_ExportRow> _girlsStudentsToRows(QuerySnapshot snap) {
    return snap.docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      DateTime? createdAt;
      final rawCreatedAt = d['createdAt'];
      if (rawCreatedAt is String) {
        createdAt = DateTime.tryParse(rawCreatedAt);
      } else if (rawCreatedAt != null) {
        try {
          createdAt = (rawCreatedAt as dynamic).toDate();
        } catch (_) {}
      }
      return _ExportRow(
        id: doc.id,
        fullName: (d['fullName'] as String?) ?? '',
        email: '',
        phoneNumber: (d['phone'] as String?) ?? '',
        faculty: d['faculty'] as String?,
        course: d['course'] as String?,
        hostel: 'girls',
        roomId: d['roomId'] as String?,
        createdAt: createdAt,
        registeredBy: 'admin',
      );
    }).toList();
  }

  /// BARCHA TALABALARNI (O'g'il bolalar VA Qiz bolalar yotoqxonasi,
  /// ikkala manbadan — o'zi ro'yxatdan o'tganlar VA Admin/Mudira tomonidan
  /// qo'lda qo'shilganlar) to'liq shaxsiy ma'lumotlari bilan Excel'ga
  /// eksport qiladi. Admin bo'limidagi "Sozlamalar" sahifasidagi eksport
  /// tugmasi shu funksiyani chaqiradi — shu bois natija endi qizlar
  /// yotoqxonasidagi foydalanuvchilarga ham ta'sir qiladi.
  ///
  /// Ustunlar: F.I.O, tug'ilgan sana, viloyat/tuman, email, telefon,
  /// fakultet, yotoqxona turi, Pasport seriya-raqami, JSHSHIR,
  /// biriktirilgan xona raqami ("101-xona"), xona to'lovi holati
  /// (qolgan qarz summasi, masalan "0 so'm" yoki "120 000 so'm"),
  /// ro'yxatdan o'tgan vaqti va turi.
  static Future<void> exportBoysStudentsToExcel() async {
    try {
      // 1. "foydalanuvchilar" kolleksiyasidan faqat "talaba" rolidagilarni
      // so'raymiz — BU YERDA endi hostel bo'yicha filtr YO'Q, shu sabab
      // o'g'il bolalar VA qiz bolalar (o'zi ro'yxatdan o'tgan) talabalari
      // birga keladi.
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .where('role', isEqualTo: UserRole.talaba.name)
          .get();

      final selfRegisteredRows = snapshot.docs.map((doc) {
        final user = UserModel.fromJson(doc.data() as Map<String, dynamic>);
        final benefitData = user.additionalData ?? const {};
        return _ExportRow(
          id: user.id,
          fullName: user.fullName,
          birthDate: user.birthDate,
          region: user.region,
          district: user.district,
          email: user.email,
          phoneNumber: user.phoneNumber,
          faculty: user.faculty,
          course: user.course,
          hostel: user.hostel,
          roomId: user.roomId,
          createdAt: user.createdAt,
          registeredBy: user.registeredBy,
          passportId: user.passportId,
          jshshir: user.jshshir,
          hasSocialBenefit: benefitData['hasSocialBenefit'] == true,
          benefitType: benefitData['benefitType'] as String?,
          lostParentType: benefitData['lostParentType'] as String?,
          deathCertificateUrl: benefitData['deathCertificateUrl'] as String?,
          benefitDocumentUrl: benefitData['benefitDocumentUrl'] as String?,
        );
      }).toList();

      // 2. "girls_students" kolleksiyasidan Admin/Mudira tomonidan qo'lda
      // qo'shilgan (Firebase Auth hisobisiz) qiz bolalar talabalarini ham
      // qo'shamiz — aks holda ular eksportda umuman ko'rinmasdi.
      List<_ExportRow> adminAddedGirlsRows = [];
      try {
        final girlsStudentsSnap =
            await FirebaseFirestore.instance.collection('girls_students').get();
        adminAddedGirlsRows = _girlsStudentsToRows(girlsStudentsSnap);
      } catch (_) {}

      final allRows = [...selfRegisteredRows, ...adminAddedGirlsRows]
        ..sort((a, b) {
          final hostelCmp = (a.hostel ?? 'boys').compareTo(b.hostel ?? 'boys');
          if (hostelCmp != 0) return hostelCmp;
          return a.fullName.compareTo(b.fullName);
        });

      if (allRows.isEmpty) {
        print("Eksport qilish uchun talabalar topilmadi.");
        return;
      }

      // 3. Xona narxlari/nomlari va to'langan summalar xaritalarini
      // OLDINDAN bir marta yuklaymiz — har bir talaba uchun alohida
      // so'rov yubormaslik uchun.
      final roomInfo = await _fetchRoomInfoMap();
      final totalPaid = await _fetchTotalPaidMap();

      // 4. Excel yaratish
      var excel = Excel.createExcel();
      String sheetName = "Talabalar (O'g'il va Qiz bolalar)";
      Sheet sheetObject = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // 5. JADVAL BOSHI (Header)
      _writeHeader(sheetObject);

      // 6. MA'LUMOTLARNI QATORMA-QATOR QO'SHISH
      int index = 1;
      for (final row in allRows) {
        _writeRow(sheetObject, index, row, roomInfo, totalPaid);
        index++;
      }

      // 7. Faylni platformaga mos usulda yuklab olish / ulashish
      final List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        await downloadExcelBytes(
          fileBytes,
          "Yotoqxona_Talabalar_Ruyxati.xlsx",
        );
      }
    } catch (e) {
      print("Talabalarni eksport qilishda xatolik: $e");
      rethrow;
    }
  }
}
