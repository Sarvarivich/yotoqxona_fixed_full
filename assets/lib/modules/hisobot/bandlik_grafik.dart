import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/room_model.dart';

// ─── Bandlik grafigi — KENGAYTIRILDI ─────────────────────────────
// Avval bu vidjet faqat statik (bir martalik) umumiy pie-chart edi.
// Endi:
//  1) Ma'lumot StreamBuilder orqali REAL VAQTDA yangilanadi (xona
//     holati o'zgarganda, sahifani qayta ochmasdan darhol ko'rinadi).
//  2) Pastda "Qavatlar xaritasi" — har bir qavatdagi xonalarni kichik
//     rangli katakcha (tile) sifatida ko'rsatadigan vizual xarita
//     qo'shildi. Har bir katakchani bosish orqali o'sha xona haqida
//     qisqacha ma'lumot (raqami, sig'imi, band o'rinlar, narxi) pastdan
//     chiqadigan varaqda (bottom sheet) ko'rinadi.
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
  static const Map<RoomStatus, Color> _statusColor = {
    RoomStatus.occupied: Colors.blue,
    RoomStatus.empty: Colors.green,
    RoomStatus.paymentPending: Colors.orange,
    RoomStatus.renovation: Colors.red,
  };

  static const Map<RoomStatus, String> _statusLabel = {
    RoomStatus.occupied: "Band",
    RoomStatus.empty: "Bo'sh",
    RoomStatus.paymentPending: "To'lov kutilmoqda",
    RoomStatus.renovation: "Ta'mirlashda",
  };

  // 🛠️ Eski/moslashmagan yozuvlar uchun himoya: agar xona sig'imi
  // to'lgan bo'lsa-yu, 'status' maydoni hali "empty" bo'lib qolgan
  // bo'lsa, statistikani haqiqiy bandlikka mos ravishda "band" deb
  // hisoblaymiz. Bu logika pie-chart va qavatlar xaritasi uchun ham
  // (ikkalasi ham bir xil manbadan — _normalizedStatus — foydalanadi).
  RoomStatus _normalizedStatus(Map<String, dynamic> data) {
    RoomStatus status = RoomStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => RoomStatus.empty);

    final int capacity = (data['capacity'] as num?)?.toInt() ?? 0;
    final List studentIdsList = (data['studentIds'] as List?) ?? [];
    final int occupantsCount = studentIdsList.isNotEmpty
        ? studentIdsList.length
        : ((data['currentOccupants'] as num?)?.toInt() ?? 0);

    if (status == RoomStatus.empty && capacity > 0 && occupantsCount >= capacity) {
      status = RoomStatus.occupied;
    }
    return status;
  }

  void _showRoomInfo(RoomModel room) {
    final status = room.status;
    final color = _statusColor[status] ?? Colors.grey;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.meeting_room_rounded, color: color),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${room.roomNumber}-xona",
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    Text("${room.floor}-qavat",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_statusLabel[status] ?? status.displayName,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _infoRow(Icons.people_outline_rounded, "O'rinlar",
                "${room.studentIds.isNotEmpty ? room.studentIds.length : room.currentOccupants} / ${room.capacity}"),
            const SizedBox(height: 10),
            _infoRow(Icons.payments_outlined, "Oylik narx",
                "${room.pricePerMonth.toStringAsFixed(0)} so'm"),
            if (room.notes != null && room.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoRow(Icons.notes_rounded, "Izoh", room.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text("$label: ", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('xonalar')
          .where('hostel', isEqualTo: widget.hostel)
          .snapshots(),
      builder: (context, snapshot) {
        final bool isLoading = !snapshot.hasData;

        int occupied = 0, empty = 0, paymentPending = 0, renovation = 0;
        final Map<int, List<RoomModel>> byFloor = {};

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['id'] == null || (data['id'] as String).isEmpty) {
              data['id'] = doc.id;
            }
            final status = _normalizedStatus(data);
            // RoomModel.fromJson o'z status'ini xom Firestore
            // qiymatidan o'qiydi — normallashtirilgan holatni to'g'ri
            // ko'rsatish uchun uni ustidan yozamiz.
            data['status'] = status.name;
            final room = RoomModel.fromJson(data);

            switch (status) {
              case RoomStatus.occupied:
                occupied++;
                break;
              case RoomStatus.empty:
                empty++;
                break;
              case RoomStatus.paymentPending:
                paymentPending++;
                break;
              case RoomStatus.renovation:
                renovation++;
                break;
            }

            byFloor.putIfAbsent(room.floor, () => []).add(room);
          }
          for (final rooms in byFloor.values) {
            rooms.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
          }
        }

        final total = occupied + empty + paymentPending + renovation;
        final sortedFloors = byFloor.keys.toList()..sort();

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Xonalar bandlik holati",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Jami: $total ta xona",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (total == 0)
                  const Center(
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
                else ...[
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
                                  value: occupied.toDouble(),
                                  title: "$occupied",
                                  color: Colors.blue,
                                  radius: 100,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: empty.toDouble(),
                                  title: "$empty",
                                  color: Colors.green,
                                  radius: 100,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: paymentPending.toDouble(),
                                  title: "$paymentPending",
                                  color: Colors.orange,
                                  radius: 100,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: renovation.toDouble(),
                                  title: "$renovation",
                                  color: Colors.red,
                                  radius: 100,
                                  titleStyle: const TextStyle(
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
                              _legendItem(Colors.blue, "Band", occupied, total),
                              const SizedBox(height: 12),
                              _legendItem(Colors.green, "Bo'sh", empty, total),
                              const SizedBox(height: 12),
                              _legendItem(Colors.orange, "To'lov kutilmoqda",
                                  paymentPending, total),
                              const SizedBox(height: 12),
                              _legendItem(
                                  Colors.red, "Ta'mirlashda", renovation, total),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.map_outlined, size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        "Qavatlar xaritasi",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Har bir katakcha bitta xona — rangi holatini bildiradi, bosib qisqacha ma'lumot ko'ring.",
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 14),
                  for (final floor in sortedFloors) ...[
                    _floorRow(floor, byFloor[floor]!),
                    const SizedBox(height: 14),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _floorRow(int floor, List<RoomModel> rooms) {
    final int floorOccupied =
        rooms.where((r) => r.status == RoomStatus.occupied).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$floor-qavat  ·  $floorOccupied/${rooms.length} band",
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: rooms.map((room) {
            final color = _statusColor[room.status] ?? Colors.grey;
            return GestureDetector(
              onTap: () => _showRoomInfo(room),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: 1.4),
                ),
                child: Text(
                  "${room.roomNumber}",
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "$label: $count",
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Text(
          "${percentage.toStringAsFixed(1)}%",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
