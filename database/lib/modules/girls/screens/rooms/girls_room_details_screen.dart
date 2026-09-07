import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/room_model.dart';
import '../../providers/girls_room_provider.dart';
import '../../providers/girls_student_provider.dart';
import '../../services/girl_student_model.dart';
import '../../theme/girls_theme.dart';
import 'add_girls_room_screen.dart';

// ─── GirlsRoomDetailsScreen: bitta xona haqida batafsil ma'lumot +
// talaba biriktirish, bir xil ekran ichida.
//
// STRUKTURA "bolalar" bo'limidagi RoomDetailsScreen
// (lib/roles/room_assignment_screen.dart) bilan AYNAN bir xil:
//   1) Xona holati bloki (Bo'sh / Band)
//   2) Xona ma'lumotlari kartasi (sig'im, bandlik, narx)
//   3) Talaba biriktirish bo'limi — BARCHA "qizlar" talabalari ko'rinadi
//      (allaqachon biror xonaga biriktirilgan bo'lsa ham), tanlansa avval
//      eski xonadan avtomatik chiqariladi, so'ng shu xonaga biriktiriladi.
//      Faqat AYNAN shu xonada turgan talabalar dropdown'da ko'rinmaydi.
//   4) Yashovchi talabalar ro'yxati (har biri uchun "chiqarish" tugmasi)
//
// Ma'lumotlar manbai bolalar bo'limidan BUTUNLAY ALOHIDA: 'girls_rooms' /
// 'girls_students' Firestore to'plamlari (GirlsRoomProvider /
// GirlsStudentProvider orqali) — faqat EKRAN STRUKTURASI va MANTIQ bir xil.
class GirlsRoomDetailsScreen extends StatefulWidget {
  final RoomModel room;
  const GirlsRoomDetailsScreen({super.key, required this.room});

  @override
  State<GirlsRoomDetailsScreen> createState() => _GirlsRoomDetailsScreenState();
}

// ✅ Talabalar ikki xil manbada saqlanadi: admin qo'lda qo'shganlari
// 'girls_students' to'plamida, o'zi ro'yxatdan o'tganlari esa
// 'foydalanuvchilar' to'plamida (Firebase Auth orqali). Xona
// biriktirish ekrani avval faqat birinchisini ko'rar edi — shu
// sabab o'zi ro'yxatdan o'tgan talabalar ro'yxatda ko'rinmas edi.
// Bu yordamchi klass ikkala manbani bitta umumiy shaklga keltiradi.
class _AssignableStudent {
  final String id;
  final String fullName;
  final String phone;
  final bool fromUsersCollection;
  _AssignableStudent({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.fromUsersCollection,
  });
}

class _GirlsRoomDetailsScreenState extends State<GirlsRoomDetailsScreen> {
  String? selectedStudentId;
  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RoomModel?>(
      stream: context.read<GirlsRoomProvider>().watchRoom(widget.room.id),
      initialData: widget.room,
      builder: (context, roomSnap) {
        final liveRoom = roomSnap.data ?? widget.room;
        final capacity = liveRoom.capacity > 0 ? liveRoom.capacity : 4;
        final currentStudentsCount = liveRoom.studentIds.length;
        final bool isRoomFull = currentStudentsCount >= capacity;

        return Scaffold(
          backgroundColor: GTheme.bgBase,
          appBar: AppBar(
            backgroundColor: GTheme.bgBase,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text("${liveRoom.roomNumber}-xona ma'lumotlari",
                style: const TextStyle(color: Colors.white)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: GTheme.pink),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddGirlsRoomScreen(room: liveRoom)),
                ),
              ),
              IconButton(
                icon:
                    const Icon(Icons.delete_outline_rounded, color: GTheme.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: GTheme.bgCard,
                      title: const Text('Ochirish',
                          style: TextStyle(color: Colors.white)),
                      content: const Text('Xona ochirilsinmi?',
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
                    await context.read<GirlsRoomProvider>().delete(liveRoom.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Xona holati (Dinamik blok)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    gradient: isRoomFull
                        ? LinearGradient(colors: [
                            Colors.red.shade400,
                            Colors.red.shade700,
                          ])
                        : GTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "${liveRoom.roomNumber}",
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        "${liveRoom.floor}-qavat",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          isRoomFull ? "Band" : "Bo'sh",
                          style: TextStyle(
                              color: isRoomFull ? Colors.red : GTheme.pink,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Xona ma'lumotlari kartasi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: GTheme.cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Xona ma'lumotlari",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const Divider(color: GTheme.faint),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.people, color: GTheme.violet),
                          title: const Text("Sig'imi:",
                              style: TextStyle(color: Colors.white)),
                          trailing: Text("$capacity kishi",
                              style: const TextStyle(color: Colors.white)),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.person,
                              color: isRoomFull ? GTheme.red : GTheme.mint),
                          title: const Text("Hozirgi bandlik:",
                              style: TextStyle(color: Colors.white)),
                          trailing: Text("$currentStudentsCount / $capacity",
                              style: const TextStyle(color: Colors.white)),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.money, color: GTheme.orange),
                          title: const Text("Oylik to'lov:",
                              style: TextStyle(color: Colors.white)),
                          trailing: Text(
                              "${GTheme.formatMoney(liveRoom.pricePerMonth)} so'm",
                              style: const TextStyle(color: Colors.white)),
                        ),
                        if (liveRoom.amenities.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: liveRoom.amenities
                                .map((a) => Chip(
                                      label: Text(a,
                                          style: const TextStyle(fontSize: 11)),
                                      backgroundColor:
                                          GTheme.pink.withOpacity(0.12),
                                      labelStyle:
                                          const TextStyle(color: GTheme.pink),
                                      side: BorderSide.none,
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // 3. TALABA BIRIKTIRISH BO'LIMI
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isRoomFull) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              "Ushbu xona to'lgan / band!",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ] else ...[
                        const Text("Yangi talaba biriktirish",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 12),

                        // ✅ Ikkala manbadan ham (admin qo'shgan +
                        // o'zi ro'yxatdan o'tgan) talabalarni olamiz.
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('foydalanuvchilar')
                              .where('role', isEqualTo: 'talaba')
                              .snapshots(),
                          builder: (context, usersSnapshot) {
                            final registeredGirls =
                                (usersSnapshot.data?.docs ?? []).where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final rawHostel = (data['hostel'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              return rawHostel == 'girls';
                            }).map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return _AssignableStudent(
                                id: doc.id,
                                fullName: (data['fullName'] ?? '').toString(),
                                phone: (data['phoneNumber'] ?? '').toString(),
                                fromUsersCollection: true,
                              );
                            }).toList();

                            return StreamBuilder<List<GirlStudentModel>>(
                              stream:
                                  context.read<GirlsStudentProvider>().students,
                              builder: (context, studentSnapshot) {
                                if (!studentSnapshot.hasData) {
                                  return const LinearProgressIndicator();
                                }

                                final manualGirls = studentSnapshot.data!
                                    .where((s) => s.roomId.isEmpty)
                                    .map((s) => _AssignableStudent(
                                          id: s.id,
                                          fullName: s.fullName,
                                          phone: s.phone,
                                          fromUsersCollection: false,
                                        ))
                                    .toList();

                                final combined = [
                                  ...manualGirls,
                                  ...registeredGirls,
                                ]
                                    .where((s) =>
                                        !liveRoom.studentIds.contains(s.id))
                                    .toList();

                                if (combined.isEmpty) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      "⚠️ Biriktirish uchun talaba topilmadi.",
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }

                                final allStudentIds =
                                    combined.map((s) => s.id).toSet();
                                final safeValue =
                                    allStudentIds.contains(selectedStudentId)
                                        ? selectedStudentId
                                        : null;

                                return DropdownButtonFormField<String>(
                                  initialValue: safeValue,
                                  dropdownColor: GTheme.bgCard,
                                  hint: const Text("Talabalar ro'yxati",
                                      style: TextStyle(color: Colors.white70)),
                                  isExpanded: true,
                                  decoration: GTheme.inputDecoration('Talaba'),
                                  items: combined.map((student) {
                                    return DropdownMenuItem<String>(
                                      value: student.id,
                                      child: Text(
                                        student.fullName,
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => selectedStudentId = val),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (selectedStudentId == null || _isAssigning)
                                    ? null
                                    : () => _assignStudent(liveRoom),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: GTheme.pink,
                            ),
                            child: _isAssigning
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add,
                                          color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        "Biriktirish",
                                        style: TextStyle(
                                            fontSize: 18, color: Colors.white),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: GTheme.violet.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 20, color: GTheme.violet),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Talaba biriktirilgandan so'ng, u xona ma'lumotlarini ko'ra oladi",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GTheme.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Yashovchi talabalar ro'yxati
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Yashovchi talabalar",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          Text("$currentStudentsCount ta",
                              style: TextStyle(
                                  color: GTheme.white.withOpacity(0.5))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (liveRoom.studentIds.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Bu xonada hozircha hech kim yashamaydi.",
                              style: TextStyle(
                                  color: GTheme.white.withOpacity(0.5))),
                        )
                      else
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('foydalanuvchilar')
                              .where('role', isEqualTo: 'talaba')
                              .snapshots(),
                          builder: (context, usersSnap) {
                            final registeredById =
                                <String, Map<String, dynamic>>{
                              for (final doc in usersSnap.data?.docs ?? [])
                                doc.id: doc.data() as Map<String, dynamic>,
                            };

                            return StreamBuilder<List<GirlStudentModel>>(
                              stream:
                                  context.read<GirlsStudentProvider>().students,
                              builder: (context, studentSnap) {
                                final allStudents = studentSnap.data ?? [];

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: liveRoom.studentIds.length,
                                  itemBuilder: (context, index) {
                                    final id = liveRoom.studentIds[index];
                                    GirlStudentModel? student;
                                    for (final s in allStudents) {
                                      if (s.id == id) {
                                        student = s;
                                        break;
                                      }
                                    }

                                    // Agar 'girls_students'da topilmasa,
                                    // 'foydalanuvchilar'dan (o'zi ro'yxatdan
                                    // o'tgan talaba) qidiramiz.
                                    final registeredData = registeredById[id];
                                    final displayName = student?.fullName ??
                                        (registeredData?['fullName']
                                            as String?) ??
                                        id;
                                    final displayPhone = student?.phone ??
                                        (registeredData?['phoneNumber']
                                            as String?) ??
                                        '';

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      decoration: GTheme.cardDecoration(),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                            backgroundColor:
                                                GTheme.pink.withOpacity(0.15),
                                            child: Text(
                                                displayName.isNotEmpty
                                                    ? displayName[0]
                                                        .toUpperCase()
                                                    : "?",
                                                style: const TextStyle(
                                                    color: GTheme.pink,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        title: Text(displayName,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500)),
                                        subtitle: Text(displayPhone,
                                            style: TextStyle(
                                                color: GTheme.white
                                                    .withOpacity(0.5))),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.logout,
                                              color: GTheme.red),
                                          tooltip: "Xonadan chiqarish",
                                          onPressed: () async {
                                            await context
                                                .read<GirlsRoomProvider>()
                                                .unassignStudent(
                                                    liveRoom.id, id);
                                            // Faqat 'girls_students'da
                                            // mavjud bo'lgan talabalar
                                            // uchun roomId maydonini
                                            // tozalaymiz — bo'lmasa
                                            // (o'zi ro'yxatdan o'tgan
                                            // talaba) bunday maydon yo'q,
                                            // uni yozishga urinish xato
                                            // beradi.
                                            if (student != null) {
                                              await context
                                                  .read<GirlsStudentProvider>()
                                                  .setRoomId(id, '');
                                            }

                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        "Talaba xonadan chiqarildi.")),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _assignStudent(RoomModel liveRoom) async {
    setState(() => _isAssigning = true);

    try {
      final roomProvider = context.read<GirlsRoomProvider>();
      final studentProvider = context.read<GirlsStudentProvider>();
      final String studentId = selectedStudentId!;

      // Avval bu ID 'girls_students' to'plamida bormi tekshiramiz.
      final allStudents = await studentProvider.students.first;
      GirlStudentModel? current;
      for (final s in allStudents) {
        if (s.id == studentId) {
          current = s;
          break;
        }
      }

      if (current != null) {
        // Admin qo'lda qo'shgan talaba — eski moslikni saqlab,
        // roomId maydonini ham yangilaymiz.
        final oldRoomId = current.roomId;
        if (oldRoomId.isNotEmpty && oldRoomId != liveRoom.id) {
          await roomProvider.unassignStudent(oldRoomId, studentId);
        }
        await roomProvider.assignStudent(liveRoom.id, studentId);
        await studentProvider.setRoomId(studentId, liveRoom.id);
      } else {
        // O'zi ro'yxatdan o'tgan talaba ('foydalanuvchilar') — bunday
        // hujjatda alohida roomId maydoni yo'q, shuning uchun faqat
        // xonaning studentIds ro'yxatiga qo'shamiz.
        await roomProvider.assignStudent(liveRoom.id, studentId);
      }

      if (!mounted) return;
      setState(() {
        _isAssigning = false;
        selectedStudentId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Talaba muvaffaqiyatli biriktirildi"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAssigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
      );
    }
  }
}
