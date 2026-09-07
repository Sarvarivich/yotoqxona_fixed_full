import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import 'xonalar_list.dart';

/// Xonalar bo'limining 5 ta mustaqil yotoqxona turi.
///
/// Har bir xona hujjatida `hostelType` saqlanadi. Shu sababli bir turdagi
/// xona/talaba ma'lumotlari boshqa turdagi bo'limga aralashmaydi.
class YotoqxonaTurlariScreen extends StatelessWidget {
  final bool isAdmin;
  final bool? canEdit;
  final String genderHostel;

  const YotoqxonaTurlariScreen({
    super.key,
    required this.isAdmin,
    this.canEdit,
    this.genderHostel = 'boys',
  });

  static const _items = <_HostelTypeItem>[
    _HostelTypeItem(
      type: 'university',
      title: 'Universitet yotoqxonasi',
      subtitle: 'Universitet hududidagi xonalar',
      icon: Icons.account_balance_rounded,
    ),
    _HostelTypeItem(
      type: 'medical',
      title: 'Tibbiyot kolleji yotoqxonasi',
      subtitle: 'Tibbiyot kolleji yotoqxonalari',
      icon: Icons.local_hospital_rounded,
    ),
    _HostelTypeItem(
      type: 'avto_yol',
      title: 'Avto yo‘l yotoqxonasi',
      subtitle: 'Avto yo‘l hududidagi xonalar',
      icon: Icons.directions_car_rounded,
    ),
    _HostelTypeItem(
      type: 'navoi_object',
      title: 'Navoiy obyekti',
      subtitle: 'Navoiydagi obyekt xonalari',
      icon: Icons.location_city_rounded,
    ),
    _HostelTypeItem(
      type: 'rental',
      title: 'Ijara uchun ajratilgan',
      subtitle: 'Ijara bo‘yicha ajratilgan joylar',
      icon: Icons.home_work_rounded,
    ),
  ];

  int _targetStudentsFor(String type) {
    switch (type) {
      case 'university':
        return 500; // 250 qizlar + 250 o'g'il bolalar
      case 'medical':
        return 150;
      case 'avto_yol':
        return 200;
      case 'navoi_object':
        return 800;
      case 'rental':
        return 500;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1FB),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Xonalar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('xonalar').snapshots(),
        builder: (context, roomSnapshot) {
          if (roomSnapshot.hasError) {
            return Center(
                child: Text('Xatolik yuz berdi: ${roomSnapshot.error}'));
          }
          if (!roomSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = roomSnapshot.data!.docs.map((doc) {
            final data =
                Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data['id'] =
                data['id']?.toString().isNotEmpty == true ? data['id'] : doc.id;
            return RoomModel.fromJson(data);
          }).toList();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Statistikada faqat talabalar ishlatiladi. Xodimlar
            // (mudir/admin/moliya/superAdmin) bu hisob-kitobga kirmaydi,
            // shuning uchun ularni real-time oqimga qo'shib kuzatishning hojati yo'q.
            stream: FirebaseFirestore.instance
                .collection('foydalanuvchilar')
                .where('role', isEqualTo: 'talaba')
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) {
                return Center(
                    child: Text(
                        'Talabalar maʼlumotida xatolik: ${userSnapshot.error}'));
              }
              if (!userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = userSnapshot.data!.docs;

              String normalizeAssignmentType(String raw) {
                switch (raw.trim().toLowerCase()) {
                  case 'medical':
                  case 'med_college':
                  case 'med_kollej':
                    return 'medical';
                  case 'avto_yol':
                  case 'avtoyol':
                  case 'avto':
                    return 'avto_yol';
                  case 'navoi_object':
                  case 'navoiy_object':
                  case 'navoi':
                    return 'navoi_object';
                  case 'rental':
                  case 'ijara':
                    return 'rental';
                  default:
                    return 'university';
                }
              }

              // Jismoniy yotoqxonalarda statistikadagi "Umumiy talaba"
              // xonalarning HAQIQIY studentIds/currentOccupants qiymatidan
              // olinadi. Shu sababli talaba qo'shilsa, o'chirilsa yoki xona
              // o'zgarsa StreamBuilder darhol statistikani yangilaydi.
              //
              // Ijara bo'limida xona bo'lmasligi mumkin, shuning uchun u
              // foydalanuvchining hostelAssignmentType qiymatidan hisoblanadi.
              final assignedByType = <String, int>{};
              for (final item in _items) {
                final type = item.type;

                if (type == 'rental') {
                  var count = 0;
                  for (final doc in users) {
                    final d = doc.data();
                    final role =
                        (d['role'] ?? 'talaba').toString().trim().toLowerCase();
                    if (role != 'talaba' && role != 'student') continue;

                    final raw =
                        (d['hostelAssignmentType'] ?? d['hostelType'] ?? '')
                            .toString();
                    if (raw.trim().isEmpty) continue;

                    if (normalizeAssignmentType(raw) == type) {
                      count++;
                    }
                  }
                  assignedByType[type] = count;
                  continue;
                }

                final typeRooms =
                    rooms.where((r) => r.hostelType == type).toList();

                var count = 0;
                for (final room in typeRooms) {
                  final idsCount = room.studentIds.length;
                  final storedCount = room.currentOccupants;
                  count += idsCount > storedCount ? idsCount : storedCount;
                }
                assignedByType[type] = count;
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1150
                      ? 3
                      : width >= 700
                          ? 2
                          : 1;
                  const gap = 16.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1450),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
                        child: Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: _items.map((item) {
                            final typeRooms = rooms
                                .where((r) => r.hostelType == item.type)
                                .toList();
                            final targetStudents =
                                _targetStudentsFor(item.type);

                            // Umumiy talaba soni foydalanuvchi profilidagi real
                            // assignmentType'dan olinadi. Xona studentIds esa
                            // xona bandligini hisoblash uchun ishlatiladi.
                            // "Umumiy talaba" endi doim real xona/ijara
                            // ma'lumotidan keladi. Foydalanuvchi yoki xona
                            // o'zgarganda yuqoridagi Firestore stream avtomatik
                            // qayta hisoblaydi.
                            final assigned = assignedByType[item.type] ?? 0;

                            int occupantsOf(RoomModel r) {
                              return r.currentOccupants > r.studentIds.length
                                  ? r.currentOccupants
                                  : r.studentIds.length;
                            }

                            final occupiedRooms = typeRooms
                                .where((r) => occupantsOf(r) > 0)
                                .length;
                            final freeRooms = typeRooms
                                .where((r) => occupantsOf(r) <= 0)
                                .length;
                            final remainingStudents =
                                (targetStudents - assigned)
                                    .clamp(0, targetStudents);
                            final cardWidth = columns == 1
                                ? width
                                : (width - gap * (columns - 1)) / columns;

                            return SizedBox(
                              width: cardWidth,
                              child: _HostelTypeCard(
                                item: item,
                                targetStudents: targetStudents,
                                remainingStudents: remainingStudents,
                                roomCount: typeRooms.length,
                                occupiedRooms: occupiedRooms,
                                freeRooms: freeRooms,
                                assignedStudents: assigned,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => XonalarList(
                                        isAdmin: isAdmin,
                                        canEdit: canEdit,
                                        hostel: genderHostel,
                                        hostelType: item.type,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HostelTypeItem {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;

  const _HostelTypeItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _HostelTypeCard extends StatelessWidget {
  final _HostelTypeItem item;
  final int targetStudents;
  final int remainingStudents;
  final int roomCount;
  final int occupiedRooms;
  final int freeRooms;
  final int assignedStudents;
  final VoidCallback onTap;

  const _HostelTypeCard({
    required this.item,
    required this.targetStudents,
    required this.remainingStudents,
    required this.roomCount,
    required this.occupiedRooms,
    required this.freeRooms,
    required this.assignedStudents,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6C5CE7);
    const violet = Color(0xFFA29BFE);
    const ink = Color(0xFF2D2A4A);
    const muted = Color(0xFF8B86A8);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE9E5FA)),
            boxShadow: [
              BoxShadow(
                color: purple.withOpacity(.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [purple, violet]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 27),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 18, color: muted),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.type == 'university'
                    ? 'Belgilangan: 500 ta (250 qizlar • 250 o‘g‘il bolalar)'
                    : item.subtitle,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                style:
                    const TextStyle(fontSize: 12.5, height: 1.2, color: muted),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 7.0;
                  final itemWidth = (constraints.maxWidth - gap * 2) / 3;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _MiniStat(
                            label: 'Belgilangan', value: '$targetStudents'),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _MiniStat(
                            label: 'Qolgan', value: '$remainingStudents'),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _MiniStat(
                            label: 'Barcha xona', value: '$roomCount'),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child:
                            _MiniStat(label: 'Bo‘sh xona', value: '$freeRooms'),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _MiniStat(
                            label: 'Band xona', value: '$occupiedRooms'),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _MiniStat(
                            label: 'Umumiy talaba', value: '$assignedStudents'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1FB),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Color(0xFF6C5CE7))),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 9.5, height: 1.05, color: Color(0xFF8B86A8)),
          ),
        ],
      ),
    );
  }
}
