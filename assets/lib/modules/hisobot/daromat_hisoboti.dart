import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../hisobot/daromad_tafsilotlarri.dart';

class DaromadHisobot extends StatefulWidget {
  final String period;
  const DaromadHisobot({super.key, 
    required this.period,
  });
  @override
  _DaromadHisobotState createState() => _DaromadHisobotState();
}

class _DaromadHisobotState extends State<DaromadHisobot> {
  DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  double _parseAmount(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0.0;
    return 0.0;
  }

  String _formatSum(double v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(2)}M so'm";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(0)}K so'm";
    return "${v.toStringAsFixed(0)} so'm";
  }

  // 🌍 O'g'il bolalar ('tolovlar') va qiz bolalar ('girls_payments')
  // to'lovlari endi IKKALASI BIRGALIKDA, real vaqtda o'qiladi va bitta
  // umumiy grafik/statistikaga birlashtiriladi.
  Stream<QuerySnapshot> get _boysStream => FirebaseFirestore.instance
      .collection('tolovlar')
      .where('hostel', isEqualTo: 'boys')
      .snapshots();

  Stream<QuerySnapshot> get _girlsStream => FirebaseFirestore.instance
      .collection('girls_payments')
      .where('status', isEqualTo: 'paid')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    // ⚡ Real vaqtda: ikkita jonli oqim (o'g'il + qiz bolalar) bir vaqtda
    // tinglanadi — qaysi biri o'zgarsa ham, UI darhol yangilanadi.
    return StreamBuilder<QuerySnapshot>(
      stream: _boysStream,
      builder: (context, boysSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _girlsStream,
          builder: (context, girlsSnapshot) {
            if (boysSnapshot.hasError || girlsSnapshot.hasError) {
              return _messageCard(
                icon: Icons.error_outline,
                iconColor: Colors.red,
                text: "Xatolik: ${boysSnapshot.error ?? girlsSnapshot.error}",
              );
            }

            if (!boysSnapshot.hasData || !girlsSnapshot.hasData) {
              return const Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            // 🔗 Ikkala manbadan kelgan hujjatlarni ('date' yoki
            // 'paidAt'/'createdAt' maydoni bilan birga) bitta ro'yxatga
            // birlashtiramiz.
            final entries = <MapEntry<Map<String, dynamic>, String>>[
              for (final doc in boysSnapshot.data!.docs)
                MapEntry(doc.data() as Map<String, dynamic>, 'boys'),
              for (final doc in girlsSnapshot.data!.docs)
                MapEntry(doc.data() as Map<String, dynamic>, 'girls'),
            ];

            final now = DateTime.now();
            final startOfToday = DateTime(now.year, now.month, now.day);
            final startOfWeek =
                startOfToday.subtract(Duration(days: now.weekday - 1));
            final startOfMonth = DateTime(now.year, now.month, 1);

            double totalIncome = 0;
            double todayIncome = 0;
            double weekIncome = 0;
            double monthIncome = 0;

            final Map<String, double> incomeData = {};

            for (final entry in entries) {
              final data = entry.key;
              final source = entry.value;
              // Qizlar yotoqxonasida 'date' maydoni mavjud emas — to'lov
              // sanasi 'paidAt' (yoki bo'lmasa 'createdAt') orqali olinadi.
              final date = source == 'girls'
                  ? _parseDate(data['paidAt'] ?? data['createdAt'])
                  : _parseDate(data['date']);
              final amount = _parseAmount(data['amount']);

              totalIncome += amount;
              if (!date.isBefore(startOfToday)) todayIncome += amount;
              if (!date.isBefore(startOfWeek)) weekIncome += amount;
              if (!date.isBefore(startOfMonth)) monthIncome += amount;

              String key;
              if (widget.period == 'week') {
                key = "${date.day}.${date.month}";
              } else if (widget.period == 'month') {
                key = "${date.month}.${date.year}";
              } else {
                key = "${date.year}";
              }
              incomeData[key] = (incomeData[key] ?? 0) + amount;
            }

            final labels = incomeData.keys.toList();
            if (widget.period == 'month') {
              labels.sort((a, b) {
                final monthA = int.parse(a.split('.')[0]);
                final monthB = int.parse(b.split('.')[0]);
                return monthA.compareTo(monthB);
              });
            } else if (widget.period == 'year') {
              labels.sort();
            }

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Daromad hisoboti",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            _liveBadge(),
                          ],
                        ),
                        // 🔎 "Jami" chipi bosilganda, shu summa orqasida turgan
                        // har bir tasdiqlangan chekni (talaba, summa, sana,
                        // rasm) alohida-alohida — "Oldingi"/"Keyingi" tugmalari
                        // bilan sirg'alib — ko'rish uchun tafsilotlar ekraniga
                        // olib boradi.
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DaromadTafsilotlari(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Jami: ${_formatSum(totalIncome)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(Icons.chevron_right_rounded,
                                    size: 15, color: Colors.green.shade700),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ─── Kunlik / Haftalik / Oylik tushum — real vaqtda ───
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 420;
                        final cards = [
                          _PeriodStat(
                            label: "Bugun",
                            value: _formatSum(todayIncome),
                            icon: Icons.today_rounded,
                            color: Colors.deepPurple,
                          ),
                          _PeriodStat(
                            label: "Bu hafta",
                            value: _formatSum(weekIncome),
                            icon: Icons.date_range_rounded,
                            color: Colors.teal,
                          ),
                          _PeriodStat(
                            label: "Bu oy",
                            value: _formatSum(monthIncome),
                            icon: Icons.calendar_month_rounded,
                            color: Colors.orange,
                          ),
                        ];
                        if (isNarrow) {
                          return Column(
                            children: cards
                                .map((c) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: c,
                                    ))
                                .toList(),
                          );
                        }
                        return Row(
                          children: cards
                              .map((c) => Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: c,
                                    ),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    if (incomeData.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.attach_money,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text("To'lov ma'lumotlari mavjud emas"),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 300,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: incomeData.values
                                    .reduce((a, b) => a > b ? a : b) *
                                1.2,
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 50,
                                  getTitlesWidget: (value, meta) {
                                    if (value >= 1000000) {
                                      return Text(
                                          "${(value / 1000000).toStringAsFixed(0)}M");
                                    } else if (value >= 1000) {
                                      return Text(
                                          "${(value / 1000).toStringAsFixed(0)}K");
                                    }
                                    return Text(value.toInt().toString());
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 &&
                                        value.toInt() < labels.length) {
                                      return Text(
                                        labels[value.toInt()],
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 40,
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: labels.asMap().entries.map((entry) {
                              final index = entry.key;
                              final label = entry.value;
                              final value = incomeData[label] ?? 0;

                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: value,
                                    color: Colors.blue,
                                    width: 30,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              );
                            }).toList(),
                            gridData: const FlGridData(
                                show: true, drawVerticalLine: false),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.trending_up, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getSummaryText(incomeData, totalIncome),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 📋 Har bir tasdiqlangan chekni alohida ko'rish (superadmin
                    // uchun) — "Oldingi"/"Keyingi" navigatsiyasi bilan.
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: BorderSide(color: Colors.deepPurple.shade100),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text(
                          "Barcha tasdiqlangan cheklarni ko'rish",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DaromadTafsilotlari(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: Colors.redAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            "Jonli",
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700),
          ),
        ],
      ),
    );
  }

  Widget _messageCard(
      {required IconData icon,
      required Color iconColor,
      required String text}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  String _getSummaryText(Map<String, double> incomeData, double totalIncome) {
    if (incomeData.isEmpty) return "Ma'lumotlar mavjud emas";

    final maxIncome = incomeData.values.reduce((a, b) => a > b ? a : b);
    final avgIncome = totalIncome / incomeData.length;

    return "Eng yuqori daromad: ${_formatSum(maxIncome)} | "
        "O'rtacha: ${_formatSum(avgIncome)}";
  }
}

class _PeriodStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _PeriodStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      TextStyle(fontSize: 11, color: color.withOpacity(0.85)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
