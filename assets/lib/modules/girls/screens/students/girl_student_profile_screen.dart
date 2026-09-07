import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/room_model.dart';
import '../../providers/girls_payment_provider.dart';
import '../../providers/girls_room_provider.dart';
import '../../providers/girls_student_provider.dart';
import '../../services/girl_student_model.dart';
import '../../services/girls_payment_model.dart';
import '../../theme/girls_theme.dart';
import 'edit_girl_student_screen.dart';

// ─── GirlStudentProfileScreen: bitta talaba haqida to'liq ma'lumot,
// shu jumladan uning to'lovlar tarixi.
class GirlStudentProfileScreen extends StatelessWidget {
  final GirlStudentModel student;
  const GirlStudentProfileScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GTheme.bgBase,
      appBar: AppBar(
        backgroundColor: GTheme.bgBase,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title:
            const Text('Talaba profili', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: GTheme.pink),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EditGirlStudentScreen(student: student)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: GTheme.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: GTheme.bgCard,
                  title: const Text('Ochirish',
                      style: TextStyle(color: Colors.white)),
                  content: const Text("Talaba o'chirilsinmi?",
                      style: TextStyle(color: GTheme.soft)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Bekor qilish')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("O'chirish",
                            style: TextStyle(color: GTheme.red))),
                  ],
                ),
              );
              if (confirm == true) {
                await context.read<GirlsStudentProvider>().delete(student.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: GTheme.pink.withOpacity(0.15),
                    backgroundImage: student.imageUrl.isNotEmpty
                        ? NetworkImage(student.imageUrl)
                        : null,
                    child: student.imageUrl.isEmpty
                        ? Text(
                            student.fullName.isNotEmpty
                                ? student.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: GTheme.pink,
                                fontSize: 30,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(student.fullName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (student.isActive ? GTheme.mint : GTheme.red)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      student.isActive ? 'Faol' : 'Faol emas',
                      style: TextStyle(
                          color: student.isActive ? GTheme.mint : GTheme.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: GTheme.cardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(
                      icon: Icons.school_outlined,
                      label: 'Fakultet',
                      value: student.faculty),
                  _InfoRow(
                      icon: Icons.numbers_rounded,
                      label: 'Kurs',
                      value: student.course),
                  _InfoRow(
                      icon: Icons.groups_2_outlined,
                      label: 'Guruh',
                      value: student.group),
                  _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Telefon',
                      value: student.phone,
                      isLast: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 10, left: 4),
              child: Text('Yotoqxona',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
            // ─── Xona ma'lumotlari — bolalar bo'limidagi
            // talaba_profile_screen.dart / _YotoqxonaTab bilan bir xil
            // struktura: talaba biror xonaga biriktirilgan bo'lsa, uning
            // TO'LIQ xona ma'lumotlari (raqam, qavat, sig'im, holati,
            // narx) ko'rsatiladi — faqat xom roomId matni emas.
            student.roomId.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: GTheme.cardDecoration(),
                    child: Column(
                      children: [
                        Icon(Icons.apartment_outlined,
                            size: 40, color: GTheme.muted.withOpacity(0.6)),
                        const SizedBox(height: 10),
                        const Text(
                          "Talabaga hali xona biriktirilmagan",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: GTheme.soft),
                        ),
                      ],
                    ),
                  )
                : FutureBuilder<RoomModel?>(
                    future: context
                        .read<GirlsRoomProvider>()
                        .getRoomById(student.roomId),
                    builder: (context, roomSnap) {
                      if (roomSnap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child:
                                CircularProgressIndicator(color: GTheme.pink),
                          ),
                        );
                      }
                      final room = roomSnap.data;
                      if (room == null) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: GTheme.cardDecoration(),
                          child: const Text(
                            "Xona topilmadi (o'chirilgan bo'lishi mumkin)",
                            style: TextStyle(color: GTheme.soft),
                          ),
                        );
                      }
                      return Container(
                        decoration: GTheme.cardDecoration(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.door_front_door_outlined,
                              label: 'Xona raqami',
                              value: '№ ${room.roomNumber}',
                            ),
                            _InfoRow(
                              icon: Icons.layers_outlined,
                              label: 'Qavat',
                              value: '${room.floor}',
                            ),
                            _InfoRow(
                              icon: Icons.groups_outlined,
                              label: "Sig'im",
                              value:
                                  '${room.currentOccupants}/${room.capacity}',
                            ),
                            _InfoRow(
                              icon: Icons.info_outline,
                              label: 'Holati',
                              value: room.status.displayName,
                            ),
                            _InfoRow(
                              icon: Icons.payments_outlined,
                              label: 'Oylik narx',
                              value:
                                  "${GTheme.formatMoney(room.pricePerMonth)} so'm",
                              isLast: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 10, left: 4),
              child: Text("To'lovlar tarixi",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
            StreamBuilder<List<GirlsPaymentModel>>(
              stream:
                  context.read<GirlsPaymentProvider>().forStudent(student.id),
              builder: (context, snapshot) {
                final payments = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: GTheme.pink),
                  ));
                }
                if (payments.isEmpty) {
                  return Text("Hozircha to'lovlar yo'q",
                      style: TextStyle(color: GTheme.white.withOpacity(0.5)));
                }
                return Column(
                  children: payments
                      .map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: GTheme.cardDecoration(),
                            child: ListTile(
                              leading: Icon(
                                p.status == GirlsPaymentStatus.paid
                                    ? Icons.check_circle_rounded
                                    : Icons.schedule_rounded,
                                color: p.status == GirlsPaymentStatus.paid
                                    ? GTheme.mint
                                    : GTheme.orange,
                              ),
                              title: Text(
                                  '${GTheme.formatMoney(p.amount)} so\'m',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${p.month} • ${p.status.displayName}',
                                  style: TextStyle(
                                      color: GTheme.white.withOpacity(0.5))),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        children: [
          Icon(icon, color: GTheme.pink, size: 18),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: GTheme.white.withOpacity(0.5), fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
