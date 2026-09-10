import 'package:excel/excel.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'excel_download.dart';

// Xonaning narxi va o'qish uchun qulay nomi (masalan "101-xona").
class _RoomInfo {
  final String label;
  final double price;
  const _RoomInfo({required this.label, required this.price});
}

// Eksport qatori — barcha talabalar uchun bir xil ko'rinish.
//
// Ilgari ikki manba bor edi: "foydalanuvchilar" (o'zi ro'yxatdan
// o'tganlar) va "girls_students" (qo'lda qo'shilganlar). Laravel'da
// bunday ajratish yo'q — hamma `users` jadvalida, qizlar esa
// hostel = 'girls' bilan farqlanadi.
class _ExportRow {
  final String id;
  final String fullName;
  final DateTime? birthDate;
  final String? region;
  final String? district;
  final String email;
  final String phoneNumber;
  final String? faculty;
  final String? course;
  final String? hostel;
  final String? roomKey; // xona raqami yoki ID
  final DateTime? createdAt;
  final String? registeredBy;
  final String? passportId;
  final String? jshshir;
  final bool hasSocialBenefit;
  final String? benefitType;
  final String? lostParentType;
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
    this.roomKey,
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
  static final ApiService _api = ApiService();

  /// Bitta so'rovda olinadigan eng ko'p yozuv (backend limiti).
  static const int _perPage = 100;

  // ===================================================================
  // YORDAMCHI FUNKSIYALAR
  // ===================================================================

  static String _str(dynamic v) => v?.toString().trim() ?? '';

  static DateTime? _sana(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static double _son(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

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

  // Hostel bo'sh bo'lsa 'boys' deb qabul qilinadi — ilovaning
  // qolgan qismidagi qoida bilan bir xil.
  static String _hostelLabel(String? hostel) {
    switch (hostel ?? 'boys') {
      case 'girls':
        return 'Qiz bolalar yotoqxonasi';
      case 'boys':
      default:
        return "O'g'il bolalar yotoqxonasi";
    }
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return "Kiritilmagan";
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year}";
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return "Noma'lum";
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}.${two(dt.month)}.${dt.year} "
        "${two(dt.hour)}:${two(dt.minute)}";
  }

  static String _registeredByLabel(String? registeredBy) {
    switch (registeredBy) {
      case 'self':
        return "O'zi ro'yxatdan o'tgan";
      case 'admin':
      case 'superAdmin':
        return "Admin tomonidan qo'shilgan";
      case 'mudir':
        return "Mudir tomonidan qo'shilgan";
      case null:
      case '':
        return "Noma'lum";
      default:
        return registeredBy!;
    }
  }

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

  // ===================================================================
  // MA'LUMOT YUKLASH — Laravel API
  // ===================================================================

  /// Barcha foydalanuvchilarni sahifama-sahifa yuklaydi.
  ///
  /// Backend bir so'rovda 100 tadan ko'p bermaydi, shuning uchun
  /// oxirgi sahifagacha aylanamiz. 2500 talabada bu 25 ta so'rov —
  /// eksport uchun maqbul.
  ///
  /// [detailed] true bo'lsa to'liq ma'lumot keladi (JSHSHIR, pasport,
  /// tug'ilgan sana, imtiyozlar). Oddiy ro'yxatda ular yo'q.
  static Future<List<Map<String, dynamic>>> _barchaFoydalanuvchilar({
    String? role,
    bool detailed = false,
  }) async {
    final natija = <Map<String, dynamic>>[];
    int sahifa = 1;
    int oxirgiSahifa = 1;

    do {
      final parametrlar = <String, String>{
        'page': sahifa.toString(),
        'per_page': _perPage.toString(),
      };
      if (role != null && role.isNotEmpty) parametrlar['role'] = role;
      if (detailed) parametrlar['detailed'] = '1';

      final javob = await _api.get(
        'students?${Uri(queryParameters: parametrlar).query}',
      );

      final royxat = javob['data'];
      if (royxat is List) {
        for (final e in royxat) {
          if (e is Map) natija.add(Map<String, dynamic>.from(e));
        }
      }

      final meta = javob['meta'];
      if (meta is Map) {
        oxirgiSahifa = (meta['last_page'] as num?)?.toInt() ?? sahifa;
      } else {
        oxirgiSahifa = sahifa; // meta yo'q bo'lsa to'xtaymiz
      }

      sahifa++;
    } while (sahifa <= oxirgiSahifa && sahifa <= 100); // xavfsizlik chegarasi

    return natija;
  }

  /// Xonalar: ID va raqam bo'yicha narx/nom xaritasi.
  ///
  /// Ikkala kalit ham qo'shiladi, chunki talabaning xonasi ba'zan
  /// UUID, ba'zan raqam ko'rinishida keladi.
  static Future<Map<String, _RoomInfo>> _xonalarXaritasi() async {
    final map = <String, _RoomInfo>{};
    try {
      final xonalar = await _api.getRooms();
      for (final x in xonalar) {
        if (x is! Map) continue;
        final d = Map<String, dynamic>.from(x);

        final price = _son(d['price_per_month'] ?? d['pricePerMonth']);
        final roomNum = d['room_number'] ?? d['roomNumber'];
        final label = roomNum != null ? '$roomNum-xona' : 'Xona';
        final info = _RoomInfo(label: label, price: price);

        final id = _str(d['id']);
        if (id.isNotEmpty) map[id] = info;
        if (roomNum != null) map[roomNum.toString()] = info;
      }
    } catch (e) {
      // Xonalar yuklanmasa eksport baribir davom etadi —
      // faqat xona ustunlari "Biriktirilmagan" bo'ladi.
    }
    return map;
  }

  /// Har bir talabaning tasdiqlangan to'lovlari yig'indisi.
  static Future<Map<String, double>> _tolanganXaritasi() async {
    final natija = <String, double>{};
    try {
      final tolovlar = await _api.getPayments();
      for (final t in tolovlar) {
        if (t is! Map) continue;
        final d = Map<String, dynamic>.from(t);

        final holat = _str(d['status']).toLowerCase();
        final tasdiqlangan = holat == 'approved' ||
            holat == 'paid' ||
            d['paid_at'] != null;
        if (!tasdiqlangan) continue;

        final studentId = _str(d['student_id'] ?? d['studentId']);
        if (studentId.isEmpty) continue;

        natija[studentId] = (natija[studentId] ?? 0) + _son(d['amount']);
      }
    } catch (e) {
      // To'lovlar yuklanmasa qarz ustuni "Xona narxi belgilanmagan"
      // yoki to'liq narx bo'lib chiqadi.
    }
    return natija;
  }

  static String _roomLabel(String? roomKey, Map<String, _RoomInfo> roomInfo) {
    if (roomKey == null || roomKey.isEmpty) return "Biriktirilmagan";
    return roomInfo[roomKey]?.label ?? "Biriktirilmagan";
  }

  static String _paymentStatusLabel(
    String studentId,
    String? roomKey,
    Map<String, _RoomInfo> roomInfo,
    Map<String, double> totalPaid,
  ) {
    if (roomKey == null || roomKey.isEmpty) return "Xona biriktirilmagan";
    final info = roomInfo[roomKey];
    if (info == null || info.price <= 0) return "Xona narxi belgilanmagan";
    final paid = totalPaid[studentId] ?? 0;
    final debt = info.price - paid;
    return _formatSom(debt < 0 ? 0 : debt);
  }

  /// API javobidan xona kalitini ajratadi.
  static String? _xonaKaliti(Map<String, dynamic> u) {
    final biriktirish =
        u['active_room_assignment'] ?? u['activeRoomAssignment'];
    if (biriktirish is Map) {
      final xona = biriktirish['room'];
      if (xona is Map) {
        final raqam = xona['room_number'] ?? xona['roomNumber'];
        if (raqam != null) return raqam.toString();
      }
      final roomId = biriktirish['room_id'] ?? biriktirish['roomId'];
      if (roomId != null) return roomId.toString();
    }
    final togridan = u['room_id'] ?? u['roomId'];
    return togridan?.toString();
  }

  // ===================================================================
  // 1-EKSPORT: BARCHA FOYDALANUVCHILAR (qisqa)
  // ===================================================================

  /// Barcha rollardagi foydalanuvchilarni qisqa ko'rinishda eksport
  /// qiladi: F.I.O, email, telefon, rol, yotoqxona, xona.
  static Future<void> exportAllUsersToExcel() async {
    try {
      final xom = await _barchaFoydalanuvchilar();

      if (xom.isEmpty) {
        throw Exception("Eksport qilish uchun foydalanuvchilar topilmadi.");
      }

      final users = xom
          .map((d) => MapEntry(_str(d['id']), UserModel.fromJson(d)))
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

      final xonalar = await _xonalarXaritasi();

      final excel = Excel.createExcel();
      const sheetName = "Foydalanuvchilar Ro'yxati";
      final sheetObject = excel[sheetName];
      excel.setDefaultSheet(sheetName);

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

      int index = 1;
      for (int i = 0; i < users.length; i++) {
        final docId = users[i].key;
        final user = users[i].value;
        final roomKey = _xonaKaliti(xom.firstWhere(
          (e) => _str(e['id']) == docId,
          orElse: () => <String, dynamic>{},
        ));

        sheetObject.appendRow([
          IntCellValue(index),
          TextCellValue(docId),
          TextCellValue(user.fullName),
          TextCellValue(user.email),
          TextCellValue(user.phoneNumber),
          TextCellValue(_roleLabel(user.role)),
          TextCellValue(_hostelLabel(user.hostel)),
          TextCellValue(_roomLabel(roomKey, xonalar)),
        ]);
        index++;
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        await downloadExcelBytes(
          fileBytes,
          'Yotoqxona_Foydalanuvchilar_Ruyxati.xlsx',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  @Deprecated('Buning o\'rniga exportAllUsersToExcel() dan foydalaning')
  static Future<void> exportTalabalarToExcel() => exportAllUsersToExcel();

  // ===================================================================
  // 2-EKSPORT: TALABALAR (to'liq)
  // ===================================================================

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
      TextCellValue(_roomLabel(row.roomKey, roomInfo)),
      TextCellValue(
          _paymentStatusLabel(row.id, row.roomKey, roomInfo, totalPaid)),
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

  /// Barcha talabalarni (o'g'il va qiz bolalar) to'liq shaxsiy
  /// ma'lumotlari bilan Excel'ga eksport qiladi.
  ///
  /// Ilgari ikki manbadan yig'ilardi ("foydalanuvchilar" va
  /// "girls_students"). Laravel'da hammasi bitta jadvalda, qizlar
  /// hostel = 'girls' bilan farqlanadi.
  static Future<void> exportBoysStudentsToExcel() async {
    try {
      // detailed=1 — JSHSHIR, pasport, tug'ilgan sana, imtiyozlar
      // uchun to'liq ma'lumot kerak.
      final xom = await _barchaFoydalanuvchilar(
        role: 'talaba',
        detailed: true,
      );

      if (xom.isEmpty) {
        throw Exception("Eksport qilish uchun talabalar topilmadi.");
      }

      final qatorlar = xom.map((d) {
        // Ijtimoiy imtiyoz ma'lumoti additional_data ichida saqlanadi.
        final qoshimcha = d['additional_data'] ?? d['additionalData'];
        final imtiyoz = qoshimcha is Map
            ? Map<String, dynamic>.from(qoshimcha)
            : <String, dynamic>{};

        final kurs = d['course'];

        return _ExportRow(
          id: _str(d['id']),
          fullName: _str(d['full_name'] ?? d['fullName']),
          birthDate: _sana(d['birth_date'] ?? d['birthDate']),
          region: _str(d['region']).isEmpty ? null : _str(d['region']),
          district: _str(d['district']).isEmpty ? null : _str(d['district']),
          email: _str(d['email']),
          phoneNumber: _str(d['phone'] ?? d['phoneNumber']),
          faculty: _str(d['faculty']).isEmpty ? null : _str(d['faculty']),
          course: kurs == null ? null : kurs.toString(),
          hostel: _str(d['hostel']).isEmpty ? null : _str(d['hostel']),
          roomKey: _xonaKaliti(d),
          createdAt: _sana(d['created_at'] ?? d['createdAt']),
          registeredBy: _str(d['registered_by'] ?? d['registeredBy']),
          passportId:
              _str(d['passport_id'] ?? d['passportId']).isEmpty
                  ? null
                  : _str(d['passport_id'] ?? d['passportId']),
          jshshir: _str(d['jshshir']).isEmpty ? null : _str(d['jshshir']),
          hasSocialBenefit: imtiyoz['hasSocialBenefit'] == true ||
              imtiyoz['has_social_benefit'] == true,
          benefitType:
              (imtiyoz['benefitType'] ?? imtiyoz['benefit_type'])?.toString(),
          lostParentType: (imtiyoz['lostParentType'] ??
                  imtiyoz['lost_parent_type'])
              ?.toString(),
          deathCertificateUrl: (imtiyoz['deathCertificateUrl'] ??
                  imtiyoz['death_certificate_url'])
              ?.toString(),
          benefitDocumentUrl: (imtiyoz['benefitDocumentUrl'] ??
                  imtiyoz['benefit_document_url'])
              ?.toString(),
        );
      }).toList()
        ..sort((a, b) {
          final hostelCmp = (a.hostel ?? 'boys').compareTo(b.hostel ?? 'boys');
          if (hostelCmp != 0) return hostelCmp;
          return a.fullName.compareTo(b.fullName);
        });

      final roomInfo = await _xonalarXaritasi();
      final totalPaid = await _tolanganXaritasi();

      final excel = Excel.createExcel();
      const sheetName = "Talabalar (O'g'il va Qiz bolalar)";
      final sheetObject = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      _writeHeader(sheetObject);

      int index = 1;
      for (final row in qatorlar) {
        _writeRow(sheetObject, index, row, roomInfo, totalPaid);
        index++;
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        await downloadExcelBytes(
          fileBytes,
          "Yotoqxona_Talabalar_Ruyxati.xlsx",
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}