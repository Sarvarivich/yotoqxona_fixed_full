import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── GirlsReportService: Qizlar yotoqxonasi bo'yicha umumiy statistika
// va hisobotlar uchun barcha girls_* to'plamlari + umumiy
// 'foydalanuvchilar'/'murojaatlar' to'plamlaridan agregatsiya.
//
// ⚠️ MUHIM — TALABALAR IKKI XIL YO'L BILAN TIZIMGA KIRADI:
// 1) O'ZI ro'yxatdan o'tsa -> 'foydalanuvchilar' to'plamiga
//    (role == 'talaba', hostel == 'girls') yoziladi.
// 2) ADMIN/mudira qo'lda qo'shsa -> 'girls_students' to'plamiga
//    yoziladi (add_girl_student_screen.dart orqali).
// Ikkalasi ham HAQIQIY talaba hisoblanadi, shuning uchun umumiy son va
// davr bo'yicha (bugun/hafta/oy) statistika ikkalasini ham qo'shib
// hisoblaydi.
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

  // ─── Yangi talabalar soni davr bo'yicha (o'zi ro'yxatdan o'tgan +
  // admin qo'shgan — ikkalasi ham) ───
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
  if (raw is Timestamp) return raw.toDate();
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

class GirlsReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Admin/mudira tomonidan qo'lda qo'shilgan qiz talabalar.
  CollectionReference<Map<String, dynamic>> get _studentsCol =>
      _db.collection('girls_students');

  // O'zi ro'yxatdan o'tgan qiz talabalar (umumiy foydalanuvchilar
  // to'plamida, rol va yotoqxona bo'yicha filtrlangan).
  Query<Map<String, dynamic>> get _registeredStudentsCol => _db
      .collection('foydalanuvchilar')
      .where('role', isEqualTo: 'talaba')
      .where('hostel', isEqualTo: 'girls');

  // ⚠️ Xonalar endi umumiy 'xonalar' to'plamida ('girls_rooms' emas) —
  // GirlsRoomService bilan bir xil manba, hostel == 'girls' filtri bilan.
  Query<Map<String, dynamic>> get _roomsCol =>
      _db.collection('xonalar').where('hostel', isEqualTo: 'girls');

  // ⚠️ MUHIM: talabalar murojaatni HAR DOIM umumiy 'murojaatlar'
  // to'plamiga ('hostel' maydoni bilan) yozadi (bunga qarang:
  // modules/murojaat/murojaat_yozish.dart). Alohida 'girls_complaints'
  // to'plami hech qachon talabalar tomonidan to'ldirilmaydi, shuning
  // uchun statistikani shu yerdan emas, 'murojaatlar'dan (hostel ==
  // 'girls' filtri bilan) olamiz.
  Query<Map<String, dynamic>> get _complaintsCol =>
      _db.collection('murojaatlar').where('hostel', isEqualTo: 'girls');

  CollectionReference<Map<String, dynamic>> get _paymentsCol =>
      _db.collection('girls_payments');

  // ─── Bir martalik yuklash (masalan Hisobotlar bo'limi uchun) ───
  Future<GirlsReportStats> loadStats() async {
    final studentsSnap = await _studentsCol.get();
    final registeredSnap = await _registeredStudentsCol.get();
    final roomsSnap = await _roomsCol.get();
    final complaintsSnap = await _complaintsCol.get();
    final paymentsSnap = await _paymentsCol.get();
    return _computeStats(
      studentsDocs: studentsSnap.docs,
      registeredStudentsDocs: registeredSnap.docs,
      roomsDocs: roomsSnap.docs,
      complaintsDocs: complaintsSnap.docs,
      paymentsDocs: paymentsSnap.docs,
    );
  }

  // ─── Jonli (real-time) statistika oqimi ───
  // Talaba o'zi ro'yxatdan o'tsa ham, admin/mudira tomonidan qo'shilsa
  // ham — tegishli to'plam o'zgarishi bilanoq dashboard/hisobotlar
  // avtomatik yangilanadi, sahifani qayta ochish yoki pastga tortib
  // yangilash shart emas.
  Stream<GirlsReportStats> watchStats() {
    late final StreamController<GirlsReportStats> controller;

    QuerySnapshot<Map<String, dynamic>>? studentsSnap;
    QuerySnapshot<Map<String, dynamic>>? registeredSnap;
    QuerySnapshot<Map<String, dynamic>>? roomsSnap;
    QuerySnapshot<Map<String, dynamic>>? complaintsSnap;
    QuerySnapshot<Map<String, dynamic>>? paymentsSnap;

    void emitIfReady() {
      if (studentsSnap == null ||
          registeredSnap == null ||
          roomsSnap == null ||
          complaintsSnap == null ||
          paymentsSnap == null) {
        return;
      }
      controller.add(_computeStats(
        studentsDocs: studentsSnap!.docs,
        registeredStudentsDocs: registeredSnap!.docs,
        roomsDocs: roomsSnap!.docs,
        complaintsDocs: complaintsSnap!.docs,
        paymentsDocs: paymentsSnap!.docs,
      ));
    }

    final subs = <StreamSubscription>[];

    controller = StreamController<GirlsReportStats>.broadcast(
      onListen: () {
        subs.add(_studentsCol.snapshots().listen((s) {
          studentsSnap = s;
          emitIfReady();
        }, onError: controller.addError));
        subs.add(_registeredStudentsCol.snapshots().listen((s) {
          registeredSnap = s;
          emitIfReady();
        }, onError: controller.addError));
        subs.add(_roomsCol.snapshots().listen((s) {
          roomsSnap = s;
          emitIfReady();
        }, onError: controller.addError));
        subs.add(_complaintsCol.snapshots().listen((s) {
          complaintsSnap = s;
          emitIfReady();
        }, onError: controller.addError));
        subs.add(_paymentsCol.snapshots().listen((s) {
          paymentsSnap = s;
          emitIfReady();
        }, onError: controller.addError));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
        subs.clear();
      },
    );

    return controller.stream;
  }

  GirlsReportStats _computeStats({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> studentsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>>
        registeredStudentsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> roomsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> complaintsDocs,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> paymentsDocs,
  }) {
    final totalStudents = studentsDocs.length + registeredStudentsDocs.length;
    final activeStudents = studentsDocs
            .where((d) => (d.data()['isActive'] ?? true) == true)
            .length +
        registeredStudentsDocs.length; // ro'yxatdan o'tganlar doim faol

    final totalRooms = roomsDocs.length;
    int occupiedRooms = 0;
    int totalCapacity = 0;
    int totalOccupants = 0;
    for (final doc in roomsDocs) {
      final data = doc.data();
      final capacity = (data['capacity'] ?? 0) as int;
      final occupants = (data['currentOccupants'] ?? 0) as int;
      totalCapacity += capacity;
      totalOccupants += occupants;
      if (occupants > 0) occupiedRooms++;
    }

    int pendingComplaints = 0;
    int resolvedComplaints = 0;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    int complaintsToday = 0;
    int complaintsThisWeek = 0;
    int complaintsThisMonth = 0;
    final complaintsAllTime = complaintsDocs.length;

    for (final doc in complaintsDocs) {
      final data = doc.data();
      final status = data['status'] as String?;
      if (status == 'resolved' || status == 'closed') {
        resolvedComplaints++;
      } else {
        pendingComplaints++;
      }

      final createdAt = _parseDate(data['createdAt']);
      if (createdAt == null) continue;

      if (!createdAt.isBefore(startOfMonth)) complaintsThisMonth++;
      if (!createdAt.isBefore(startOfWeek)) complaintsThisWeek++;
      if (!createdAt.isBefore(startOfToday)) complaintsToday++;
    }

    // ─── Yangi talabalar soni davr bo'yicha (ikkala manba birga) ───
    int studentsToday = 0;
    int studentsThisWeek = 0;
    int studentsThisMonth = 0;
    final studentsAllTime = totalStudents;

    void countStudentPeriod(dynamic createdAtRaw) {
      final createdAt = _parseDate(createdAtRaw);
      if (createdAt == null) return;
      if (!createdAt.isBefore(startOfMonth)) studentsThisMonth++;
      if (!createdAt.isBefore(startOfWeek)) studentsThisWeek++;
      if (!createdAt.isBefore(startOfToday)) studentsToday++;
    }

    for (final doc in studentsDocs) {
      countStudentPeriod(doc.data()['createdAt']);
    }
    for (final doc in registeredStudentsDocs) {
      countStudentPeriod(doc.data()['createdAt']);
    }

    double totalCollected = 0;
    double totalPending = 0;
    final Map<String, double> monthlyIncome = {};
    for (final doc in paymentsDocs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      final status = data['status'] as String?;
      final month = data['month'] as String? ?? 'Nomaʼlum';
      if (status == 'paid') {
        totalCollected += amount;
        monthlyIncome[month] = (monthlyIncome[month] ?? 0) + amount;
      } else {
        totalPending += amount;
      }
    }

    return GirlsReportStats(
      totalStudents: totalStudents,
      activeStudents: activeStudents,
      totalRooms: totalRooms,
      occupiedRooms: occupiedRooms,
      emptyRooms: totalRooms - occupiedRooms,
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
      complaintsAllTime: complaintsAllTime,
      studentsToday: studentsToday,
      studentsThisWeek: studentsThisWeek,
      studentsThisMonth: studentsThisMonth,
      studentsAllTime: studentsAllTime,
    );
  }
}
