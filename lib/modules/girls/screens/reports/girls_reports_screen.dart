import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../services/excel_download.dart';
import '../../services/girls_report_service.dart';
import '../../theme/girls_theme.dart';

// ─── GirlsReportsScreen: Qizlar yotoqxonasi bo'yicha umumiy statistika,
// grafiklar va Excel eksport.
class GirlsReportsScreen extends StatefulWidget {
  const GirlsReportsScreen({super.key});

  @override
  State<GirlsReportsScreen> createState() => _GirlsReportsScreenState();
}

class _GirlsReportsScreenState extends State<GirlsReportsScreen> {
  final _reportService = GirlsReportService();
  late Future<GirlsReportStats> _statsFuture;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _statsFuture = _reportService.loadStats();
  }

  void _refresh() {
    setState(() => _statsFuture = _reportService.loadStats());
  }

  Future<void> _exportExcel(GirlsReportStats stats) async {
    setState(() => _isExporting = true);
    try {
      final excel = Excel.createExcel();
      const sheetName = "Qizlar yotoqxonasi hisoboti";
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      sheet.appendRow([TextCellValue('Korsatkich'), TextCellValue('Qiymat')]);
      sheet.appendRow(
          [TextCellValue('Jami talabalar'), IntCellValue(stats.totalStudents)]);
      sheet.appendRow([
        TextCellValue('Faol talabalar'),
        IntCellValue(stats.activeStudents)
      ]);
      sheet.appendRow(
          [TextCellValue('Jami xonalar'), IntCellValue(stats.totalRooms)]);
      sheet.appendRow(
          [TextCellValue("Band xonalar"), IntCellValue(stats.occupiedRooms)]);
      sheet.appendRow(
          [TextCellValue("Bosh xonalar"), IntCellValue(stats.emptyRooms)]);
      sheet.appendRow([
        TextCellValue("Bandlik darajasi (%)"),
        TextCellValue(stats.occupancyRate.toStringAsFixed(1))
      ]);
      sheet.appendRow([
        TextCellValue("Yigilgan tolovlar"),
        TextCellValue(stats.totalCollected.toStringAsFixed(0))
      ]);
      sheet.appendRow([
        TextCellValue("Kutilayotgan tolovlar"),
        TextCellValue(stats.totalPending.toStringAsFixed(0))
      ]);
      sheet.appendRow([
        TextCellValue("Kutilayotgan murojaatlar"),
        IntCellValue(stats.pendingComplaints)
      ]);
      sheet.appendRow([
        TextCellValue("Hal qilingan murojaatlar"),
        IntCellValue(stats.resolvedComplaints)
      ]);

      final bytes = excel.save();
      if (bytes != null) {
        await downloadExcelBytes(bytes, 'Qizlar_Yotoqxonasi_Hisobot.xlsx');
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
      backgroundColor: GTheme.bgBase,
      body: SafeArea(
        child: FutureBuilder<GirlsReportStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: GTheme.pink));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Xatolik: ${snapshot.error}',
                    style: const TextStyle(color: GTheme.soft)),
              );
            }
            final stats = snapshot.data!;
            return RefreshIndicator(
              color: GTheme.pink,
              onRefresh: () async => _refresh(),
              child: ListView(
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
                                    color: GTheme.pink, strokeWidth: 2))
                            : const Icon(Icons.download_rounded,
                                color: GTheme.pink),
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
                        color: GTheme.pink,
                      ),
                      _StatCard(
                        icon: Icons.meeting_room_rounded,
                        label: 'Jami xonalar',
                        value: '${stats.totalRooms}',
                        color: GTheme.violet,
                      ),
                      _StatCard(
                        icon: Icons.pie_chart_rounded,
                        label: 'Bandlik darajasi',
                        value: '${stats.occupancyRate.toStringAsFixed(0)}%',
                        color: GTheme.teal,
                      ),
                      _StatCard(
                        icon: Icons.forum_rounded,
                        label: 'Kutilayotgan murojaat',
                        value: '${stats.pendingComplaints}',
                        color: GTheme.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: GTheme.cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Xonalar bandligi",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: stats.totalRooms == 0
                              ? Center(
                                  child: Text('Malumot yoq',
                                      style: TextStyle(
                                          color:
                                              GTheme.white.withOpacity(0.4))))
                              : PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 36,
                                    sections: [
                                      PieChartSectionData(
                                        value: stats.occupiedRooms.toDouble(),
                                        color: GTheme.pink,
                                        title: '${stats.occupiedRooms}',
                                        radius: 46,
                                        titleStyle: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      PieChartSectionData(
                                        value: stats.emptyRooms.toDouble(),
                                        color: GTheme.mint,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LegendDot(color: GTheme.pink, label: 'Band'),
                            const SizedBox(width: 16),
                            _LegendDot(color: GTheme.mint, label: "Bo'sh"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: GTheme.cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Tolovlar holati",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        const SizedBox(height: 14),
                        _MoneyRow(
                            label: 'Yigilgan',
                            value: stats.totalCollected,
                            color: GTheme.mint),
                        const SizedBox(height: 10),
                        _MoneyRow(
                            label: 'Kutilayotgan',
                            value: stats.totalPending,
                            color: GTheme.orange),
                      ],
                    ),
                  ),
                ],
              ),
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
      decoration: GTheme.cardDecoration(),
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
          Text(label,
              style: TextStyle(
                  color: GTheme.white.withOpacity(0.5), fontSize: 11)),
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
        Text(label,
            style:
                TextStyle(color: GTheme.white.withOpacity(0.6), fontSize: 12)),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MoneyRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: GTheme.soft, fontSize: 13)),
        const Spacer(),
        Text('${GTheme.formatMoney(value)} so\'m',
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
