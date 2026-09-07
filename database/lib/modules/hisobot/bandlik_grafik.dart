import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/room_model.dart';

class BandlikGrafik extends StatefulWidget {
  final String hostel;

  const BandlikGrafik({
    super.key,
    required this.hostel,
  });

  @override
  _BandlikGrafikState createState() => _BandlikGrafikState();
}

class _BandlikGrafikState extends State<BandlikGrafik> {
  int _occupied = 0;
  int _empty = 0;
  int _paymentPending = 0;
  int _renovation = 0;
  int _total = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _occupied = 0;
    _empty = 0;
    _paymentPending = 0;
    _renovation = 0;
    _total = 0;
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('xonalar')
        .where('hostel', isEqualTo: widget.hostel)
        .get();
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      RoomStatus status = RoomStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => RoomStatus.empty);

      // 🛠️ Eski/moslashmagan yozuvlar uchun himoya: agar xona sig'imi
      // to'lgan bo'lsa-yu, 'status' maydoni hali "empty" bo'lib qolgan
      // bo'lsa (masalan avvalgi versiyada holat avtomatik yangilanmagan
      // bo'lsa), statistikani haqiqiy bandlikka mos ravishda "band" deb
      // hisoblaymiz.
      final int capacity = (data['capacity'] as num?)?.toInt() ?? 0;
      final List studentIdsList = (data['studentIds'] as List?) ?? [];
      final int occupantsCount = studentIdsList.isNotEmpty
          ? studentIdsList.length
          : ((data['currentOccupants'] as num?)?.toInt() ?? 0);

      if (status == RoomStatus.empty &&
          capacity > 0 &&
          occupantsCount >= capacity) {
        status = RoomStatus.occupied;
      }

      switch (status) {
        case RoomStatus.occupied:
          _occupied++;
          break;
        case RoomStatus.empty:
          _empty++;
          break;
        case RoomStatus.paymentPending:
          _paymentPending++;
          break;
        case RoomStatus.renovation:
          _renovation++;
          break;
      }
    }

    _total = _occupied + _empty + _paymentPending + _renovation;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Xonalar bandlik holati",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Jami: $_total ta xona",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_total == 0)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.analytics, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("Ma'lumotlar mavjud emas"),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 280,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: _occupied.toDouble(),
                              title: "$_occupied",
                              color: Colors.blue,
                              radius: 100,
                              titleStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            PieChartSectionData(
                              value: _empty.toDouble(),
                              title: "$_empty",
                              color: Colors.green,
                              radius: 100,
                              titleStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            PieChartSectionData(
                              value: _paymentPending.toDouble(),
                              title: "$_paymentPending",
                              color: Colors.orange,
                              radius: 100,
                              titleStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            PieChartSectionData(
                              value: _renovation.toDouble(),
                              title: "$_renovation",
                              color: Colors.red,
                              radius: 100,
                              titleStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          startDegreeOffset: -90,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _legendItem(Colors.blue, "Band", _occupied, _total),
                          SizedBox(height: 12),
                          _legendItem(Colors.green, "Bo'sh", _empty, _total),
                          SizedBox(height: 12),
                          _legendItem(Colors.orange, "To'lov kutilmoqda",
                              _paymentPending, _total),
                          SizedBox(height: 12),
                          _legendItem(
                              Colors.red, "Ta'mirlashda", _renovation, _total),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, int count, int total) {
    double percentage = total > 0 ? (count / total) * 100 : 0;
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            "$label: $count",
            style: TextStyle(fontSize: 12),
          ),
        ),
        Text(
          "${percentage.toStringAsFixed(1)}%",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
