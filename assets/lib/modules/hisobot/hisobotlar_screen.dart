import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/excel_download.dart';

// ─── HisobotlarScreen: Yotoqxona (o'g'il bolalar / umumiy) bo'yicha
// umumiy statistika, grafiklar va Excel eksport — qizlar bo'limidagi
// "Hisobotlar" bilan bir xil vizual til, lekin 'foydalanuvchilar',
// 'xonalar', 'murojaatlar', 'tolovlar' to'plamlaridan ma'lumot oladi.
// Ma'lumot JONLI (real-time): talaba o'zi ro'yxatdan o'tsa ham, admin
// tomonidan qo'shilsa/o'zgartirilsa ham raqamlar avtomatik yangilanadi.

class _C {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
  static const violet = Color(0xFFa29bfe);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFfd79a8);
  static const orange = Color(0xFFfdcb6e);
  static const white = Color(0xFFFFFFFF);
  static const soft = Color(0xB3FFFFFF);
}

class HisobotStats {
  final int totalStudents;
  final int totalRooms;
  final int occupiedRooms;
  final int emptyRooms;
  final int pendingComplaints;
  final int resolvedComplaints;
  final double totalIncome;

  HisobotStats({
    required this.totalStudents,
    required this.totalRooms,
    required this.occupiedRooms,
    required this.emptyRooms,
    required this.pendingComplaints,
    required this.resolvedComplaints,
    required this.totalIncome,
  });

  double get occupancyRate =>
      totalRooms == 0 ? 0 : (occupiedRooms / totalRooms) * 100;
}

String _formatMoney(num value) {
  final s = value.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buf.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(' ');
  }
  return buf.toString();
}

bool _isRoomOccupied(Map<String, dynamic> data) {
  if (data.containsKey('status') && data['status'] == 'occupied') return true;
  final int capacity = (data['capacity'] as num?)?.toInt() ?? 0;
  final List studentIdsList = (data['studentIds'] as List?) ?? [];
  final int occupantsCount = studentIdsList.isNotEmpty
      ? studentIdsList.length
      : ((data['currentOccupants'] as num?)?.toInt() ?? 0);
  if (capacity > 0 && occupantsCount >= capacity) return true;
  if (data.containsKey('students')) {
    return (data['students'] as List).isNotEmpty;
  }
  return false;
}

class HisobotlarScreen extends StatefulWidget {
  final String hostel;
  const HisobotlarScreen({super.key, this.hostel = 'boys'});

  @override
  State<HisobotlarScreen> createState() => _HisobotlarScreenState();
}

class _HisobotlarScreenState extends State<HisobotlarScreen> {
  final _db = FirebaseFirestore.instance;
  late final Stream<HisobotStats> _statsStream;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _statsStream = _watchStats();
  }

  Stream<HisobotStats> _watchStats() {
    QuerySnapshot<Map<String, dynamic>>? studentsSnap;
    QuerySnapshot<Map<String, dynamic>>? roomsSnap;
    QuerySnapshot<Map<String, dynamic>>? complaintsSnap;
    QuerySnapshot<Map<String, dynamic>>? paymentsSnap;

    late final StreamController<HisobotStats> controller;
    final subs = <StreamSubscription>[];

    void emitIfReady() {
      if (studentsSnap == null ||
          roomsSnap == null ||
          complaintsSnap == null ||
          paymentsSnap == null) {
        return;
      }

      final totalStudents = studentsSnap!.docs.length;
      final totalRooms = roomsSnap!.docs.length;
      final occupiedRooms =
          roomsSnap!.docs.where((d) => _isRoomOccupied(d.data())).length;

      int pendingComplaints = 0;
      int resolvedComplaints = 0;
      for (final doc in complaintsSnap!.docs) {
        final status = doc.data()['status'];
        if (status == 'resolved' || status == 'closed') {
          resolvedComplaints++;
        } else {
          pendingComplaints++;
        }
      }

      double totalIncome = 0;
      for (final doc in paymentsSnap!.docs) {
        final amt = doc.data()['amount'];
        if (amt is num) totalIncome += amt.toDouble();
        if (amt is String) totalIncome += double.tryParse(amt) ?? 0;
      }

      controller.add(HisobotStats(
        totalStudents: totalStudents,
        totalRooms: totalRooms,
        occupiedRooms: occupiedRooms,
        emptyRooms: totalRooms - occupiedRooms,
        pendingComplaints: pendingComplaints,
        resolvedComplaints: resolvedComplaints,
        totalIncome: totalIncome,
      ));
    }

    controller = StreamController<HisobotStats>.broadcast(
      onListen: () {
        subs.add(_db
            .collection('foydalanuvchilar')
            .where('role', isEqualTo: 'talaba')
            .where('hostel', isEqualTo: widget.hostel)
            .snapshots()
            .listen((s) {
          studentsSnap = s;
          emitIfReady();
        }, onError: controller.addError));
        subs.add(_db
            .collection('xonalar')
            .where('hostel', isEqualTo: widget.hostel)
            .snapshots()
            .listen((s) {
          roomsSnap = s;
          emitIfReady();
        }, onError: controller.addError));
        subs.add(_db
            .collection('murojaatlar')
            .where('hostel', isEqualTo: widget.hostel)
            .snapshots()
            .listen((s) {
          complaintsSnap = s;
          emitIfReady();
        }, onError: controller.addError));
        subs.add(_db
            .collection('tolovlar')
            .where('hostel', isEqualTo: widget.hostel)
            .snapshots()
            .listen((s) {
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

  Future<void> _exportExcel(HisobotStats stats) async {
    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Yotoqxona hisoboti';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      sheet.appendRow([TextCellValue("Ko'rsatkich"), TextCellValue('Qiymat')]);
      sheet.appendRow(
          [TextCellValue('Jami talabalar'), IntCellValue(stats.totalStudents)]);
      sheet.appendRow(
          [TextCellValue('Jami xonalar'), IntCellValue(stats.totalRooms)]);
      sheet.appendRow(
          [TextCellValue('Band xonalar'), IntCellValue(stats.occupiedRooms)]);
      sheet.appendRow(
          [TextCellValue("Bo'sh xonalar"), IntCellValue(stats.emptyRooms)]);
      sheet.appendRow([
        TextCellValue('Bandlik darajasi (%)'),
        TextCellValue(stats.occupancyRate.toStringAsFixed(1))
      ]);
      sheet.appendRow([
        TextCellValue('Yig\'ilgan tushum'),
        TextCellValue(stats.totalIncome.toStringAsFixed(0))
      ]);
      sheet.appendRow([
        TextCellValue('Kutilayotgan murojaatlar'),
        IntCellValue(stats.pendingComplaints)
      ]);
      sheet.appendRow([
        TextCellValue('Hal qilingan murojaatlar'),
        IntCellValue(stats.resolvedComplaints)
      ]);

      final bytes = excel.save();
      if (bytes != null) {
        await downloadExcelBytes(bytes, 'Yotoqxona_Hisobot.xlsx');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Hisobot yuklab olindi'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgBase,
      body: SafeArea(
        child: StreamBuilder<HisobotStats>(
          stream: _statsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(
                  child: CircularProgressIndicator(color: _C.violet));
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                      "Ma'lumotlarni yuklab bo'lmadi: ${snapshot.error}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _C.soft)),
                ),
              );
            }
            final stats = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Hisobotlar',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed:
                          _isExporting ? null : () => _exportExcel(stats),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: _C.violet, strokeWidth: 2))
                          : const Icon(Icons.download_rounded,
                              color: _C.violet),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _StatCard(
                      icon: Icons.groups_2_rounded,
                      label: 'Jami talabalar',
                      value: '${stats.totalStudents}',
                      color: _C.violet,
                    ),
                    _StatCard(
                      icon: Icons.meeting_room_rounded,
                      label: 'Jami xonalar',
                      value: '${stats.totalRooms}',
                      color: _C.teal,
                    ),
                    _StatCard(
                      icon: Icons.pie_chart_rounded,
                      label: 'Bandlik darajasi',
                      value: '${stats.occupancyRate.toStringAsFixed(0)}%',
                      color: _C.orange,
                    ),
                    _StatCard(
                      icon: Icons.forum_rounded,
                      label: 'Kutilayotgan murojaat',
                      value: '${stats.pendingComplaints}',
                      color: _C.pink,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                      color: _C.bgCard,
                      borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Xonalar bandligi',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: stats.totalRooms == 0
                            ? const Center(
                                child: Text("Ma'lumot yo'q",
                                    style: TextStyle(color: _C.soft)))
                            : PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 36,
                                  sections: [
                                    PieChartSectionData(
                                      value: stats.occupiedRooms.toDouble(),
                                      color: _C.violet,
                                      title: '${stats.occupiedRooms}',
                                      radius: 46,
                                      titleStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    PieChartSectionData(
                                      value: stats.emptyRooms.toDouble(),
                                      color: _C.mint,
                                      title: '${stats.emptyRooms}',
                                      radius: 46,
                                      titleStyle: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: _C.violet, label: 'Band'),
                          SizedBox(width: 16),
                          _LegendDot(color: _C.mint, label: "Bo'sh"),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                      color: _C.bgCard,
                      borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.payments_rounded,
                          color: _C.mint, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text("Yig'ilgan tushum",
                            style: TextStyle(color: _C.soft, fontSize: 13)),
                      ),
                      Text('${_formatMoney(stats.totalIncome)} so\'m',
                          style: const TextStyle(
                              color: _C.mint,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: _C.bgCard, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _C.soft, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _C.soft, fontSize: 12)),
      ],
    );
  }
}
