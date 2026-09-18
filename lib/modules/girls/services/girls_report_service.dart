import '../../services/api_service.dart';

// ─── GirlsReportService: Qizlar yotoqxonasi statistikasi ───────────
//
// Ma'lumot Laravel API'dan olinadi:
//   talabalar   -> GET /api/students?hostel=girls
//   xonalar     -> GET /api/rooms      (hostel_type = girls)
//   murojaatlar -> GET /api/complaints (bino bo'yicha filtr)
//   to'lovlar   -> GET /api/payments   (bino bo'yicha filtr)
//
// Ilgari beshta Firestore to'plami real vaqtda tinglanardi
// ('girls_students', 'foydalanuvchilar', 'xonalar', 'murojaatlar',
// 'girls_payments'). Laravel'da qizlar uchun alohida jadval yo'q —
// hamma narsa umumiy jadvallarda, bino esa ustun bilan farqlanadi.
//
// DIQQAT: watchStats() hamon `Stream` qaytaradi, chunki ekranlar
// `StreamBuilder` bilan yozilgan. Lekin bu bir martalik oqim —
// real vaqtda o'z-o'zidan yangilanmaydi.

class GirlsReportStats {
  final int totalStudents;
  final int activeStudents;
  final int totalRooms;
  final int occupiedRooms;
  final int emptyRooms;
  final int totalCapacity;
  final int totalOccupants;
  final int pendingComplaints;
  final int resolvedComplaints;
  final double totalCollected;
  final double totalPending;
  final Map<String, double> monthlyIncome; // "2026-07" -> summa

  // ─── Tushgan arizalar (murojaatlar) soni davr bo'yicha ───
  final int complaintsToday;
  final int complaintsThisWeek;
  final int complaintsThisMonth;
  final int complaintsAllTime;

  // ─── Yangi talabalar soni davr bo'yicha ───
  final int studentsToday;
  final int studentsThisWeek;
  final int studentsThisMonth;
  final int studentsAllTime;

  GirlsReportStats({
    required this.totalStudents,
    required this.activeStudents,
    required this.totalRooms,
    required this.occupiedRooms,
    required this.emptyRooms,
    required this.totalCapacity,
    required this.totalOccupants,
    required this.pendingComplaints,
    required this.resolvedComplaints,
    required this.totalCollected,
    required this.totalPending,
    required this.monthlyIncome,
    required this.complaintsToday,
    required this.complaintsThisWeek,
    required this.complaintsThisMonth,
    required this.complaintsAllTime,
    required this.studentsToday,
    required this.studentsThisWeek,
    required this.studentsThisMonth,
    required this.studentsAllTime,
  });

  double get occupancyRate =>
      totalCapacity == 0 ? 0 : (totalOccupants / totalCapacity) * 100;
}

DateTime? _parseDate(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

class GirlsReportService {
  final ApiService _api = ApiService();

  static const String _hostel = 'girls';

  double _son(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _butun(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Yozuv qaysi binoga tegishli ekanini aniqlaydi.
  ///
  /// Bino to'g'ridan-to'g'ri (`hostel`, `hostel_type`), bog'langan
  /// xona ichida yoki talabaning maydonida bo'lishi mumkin.
  String _bino(Map<String, dynamic> d) {
    var bino = (d['hostel_type'] ?? '').toString().trim().toLowerCase();

    if (bino.isEmpty) {
      final h = d['hostel'];
      if (h is Map) {
        bino = (h['code'] ?? '').toString().trim().toLowerCase();
        if (bino.isEmpty) {
          final nom = (h['name'] ?? '').toString().toLowerCase();
          if (nom.isNotEmpty) bino = nom.contains('qiz') ? 'girls' : 'boys';
        }
      } else if (h != null) {
        bino = h.toString().trim().toLowerCase();
      }
    }

    if (bino.isEmpty) {
      final xona = d['room'];
      if (xona is Map) {
        bino = (xona['hostel_type'] ?? '').toString().toLowerCase();
      }
    }

    if (bino.isEmpty) {
      final talaba = d['student'];
      if (talaba is Map) {
        bino = (talaba['hostel'] ?? '').toString().toLowerCase();
      }
    }

    return bino.isEmpty ? 'boys' : bino;
  }

  /// Sahifama-sahifa yuklaydi (backend bir so'rovda 100 tadan
  /// ko'p bermaydi).
  Future<List<Map<String, dynamic>>> _sahifalab(String endpoint) async {
    final natija = <Map<String, dynamic>>[];
    int sahifa = 1;
    int oxirgi = 1;

    do {
      final ajratgich = endpoint.contains('?') ? '&' : '?';
      final javob =
          await _api.get('$endpoint${ajratgich}per_page=100&page=$sahifa');

      final royxat = javob['data'];
      if (royxat is List) {
        for (final e in royxat) {
          if (e is Map) natija.add(Map<String, dynamic>.from(e));
        }
      }

      final meta = javob['meta'];
      oxirgi = meta is Map
          ? ((meta['last_page'] as num?)?.toInt() ?? sahifa)
          : sahifa;
      sahifa++;
    } while (sahifa <= oxirgi && sahifa <= 100);

    return natija;
  }

  Future<List<Map<String, dynamic>>> _royxat(String endpoint) async {
    final natija = <Map<String, dynamic>>[];
    try {
      final javob = await _api.get(endpoint);
      final royxat = javob['data'];
      if (royxat is List) {
        for (final e in royxat) {
          if (e is Map) natija.add(Map<String, dynamic>.from(e));
        }
      }
    } catch (_) {
      // Bitta manba ishlamasa qolgan raqamlar baribir hisoblanadi.
    }
    return natija;
  }

  // ─── Bir martalik yuklash ───
  Future<GirlsReportStats> loadStats() async {
    List<Map<String, dynamic>> talabalar = const [];
    try {
      talabalar = await _sahifalab('students?role=talaba&hostel=$_hostel');
    } catch (_) {}

    final xonalar = (await _royxat('rooms'))
        .where((d) => _bino(d) == _hostel)
        .toList();

    final murojaatlar = (await _royxat('complaints'))
        .where((d) => _bino(d) == _hostel)
        .toList();

    final tolovlar = (await _royxat('payments'))
        .where((d) => _bino(d) == _hostel)
        .toList();

    return _computeStats(
      talabalar: talabalar,
      xonalar: xonalar,
      murojaatlar: murojaatlar,
      tolovlar: tolovlar,
    );
  }

  // ─── Statistika oqimi ───
  //
  // Ilgari beshta Firestore oqimi birlashtirilardi va har qanday
  // o'zgarishda dashboard avtomatik yangilanardi. Endi ma'lumot
  // ekran ochilganda bir marta yuklanadi.
  Stream<GirlsReportStats> watchStats() => Stream.fromFuture(loadStats());

  GirlsReportStats _computeStats({
    required List<Map<String, dynamic>> talabalar,
    required List<Map<String, dynamic>> xonalar,
    required List<Map<String, dynamic>> murojaatlar,
    required List<Map<String, dynamic>> tolovlar,
  }) {
    final hozir = DateTime.now();
    final bugun = DateTime(hozir.year, hozir.month, hozir.day);
    final haftaBoshi = bugun.subtract(Duration(days: hozir.weekday - 1));
    final oyBoshi = DateTime(hozir.year, hozir.month, 1);

    // ─── Talabalar ───
    int activeStudents = 0;
    int studentsToday = 0;
    int studentsThisWeek = 0;
    int studentsThisMonth = 0;

    for (final d in talabalar) {
      if (d['is_active'] != false) activeStudents++;

      final sana = _parseDate(d['created_at']);
      if (sana == null) continue;

      if (!sana.isBefore(bugun)) studentsToday++;
      if (!sana.isBefore(haftaBoshi)) studentsThisWeek++;
      if (!sana.isBefore(oyBoshi)) studentsThisMonth++;
    }

    // ─── Xonalar ───
    int totalCapacity = 0;
    int totalOccupants = 0;
    int occupiedRooms = 0;

    for (final d in xonalar) {
      final sigim = _butun(d['capacity']);
      final band = _butun(d['current_occupants'] ?? d['currentOccupants']);

      totalCapacity += sigim;
      totalOccupants += band;
      if (band > 0) occupiedRooms++;
    }

    // ─── Murojaatlar ───
    int pendingComplaints = 0;
    int resolvedComplaints = 0;
    int complaintsToday = 0;
    int complaintsThisWeek = 0;
    int complaintsThisMonth = 0;

    for (final d in murojaatlar) {
      final holat = (d['status'] ?? '').toString().toLowerCase();
      if (holat == 'resolved' || holat == 'closed') {
        resolvedComplaints++;
      } else {
        pendingComplaints++;
      }

      final sana = _parseDate(d['created_at']);
      if (sana == null) continue;

      if (!sana.isBefore(bugun)) complaintsToday++;
      if (!sana.isBefore(haftaBoshi)) complaintsThisWeek++;
      if (!sana.isBefore(oyBoshi)) complaintsThisMonth++;
    }

    // ─── To'lovlar ───
    double totalCollected = 0;
    double totalPending = 0;
    final monthlyIncome = <String, double>{};

    for (final d in tolovlar) {
      final summa = _son(d['amount']);
      final holat = (d['status'] ?? '').toString().toLowerCase();

      if (holat == 'approved' || holat == 'paid') {
        totalCollected += summa;

        // Oy kaliti: avval `period` maydoni, bo'lmasa to'lov sanasi.
        var oy = (d['period'] ?? '').toString();
        if (oy.isEmpty) {
          final sana = _parseDate(d['paid_at'] ?? d['created_at']);
          if (sana != null) {
            oy = '${sana.year}-${sana.month.toString().padLeft(2, '0')}';
          }
        }
        if (oy.isNotEmpty) {
          monthlyIncome[oy] = (monthlyIncome[oy] ?? 0) + summa;
        }
      } else if (holat == 'pending') {
        totalPending += summa;
      }
    }

    return GirlsReportStats(
      totalStudents: talabalar.length,
      activeStudents: activeStudents,
      totalRooms: xonalar.length,
      occupiedRooms: occupiedRooms,
      emptyRooms: xonalar.length - occupiedRooms,
      totalCapacity: totalCapacity,
      totalOccupants: totalOccupants,
      pendingComplaints: pendingComplaints,
      resolvedComplaints: resolvedComplaints,
      totalCollected: totalCollected,
      totalPending: totalPending,
      monthlyIncome: monthlyIncome,
      complaintsToday: complaintsToday,
      complaintsThisWeek: complaintsThisWeek,
      complaintsThisMonth: complaintsThisMonth,
      complaintsAllTime: murojaatlar.length,
      studentsToday: studentsToday,
      studentsThisWeek: studentsThisWeek,
      studentsThisMonth: studentsThisMonth,
      studentsAllTime: talabalar.length,
    );
  }
}
