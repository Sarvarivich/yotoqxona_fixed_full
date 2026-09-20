import 'dart:async';
import '../../../services/api_service.dart';
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

class _GirlsRoomDetailsScreenState extends State<GirlsRoomDetailsScreen> {
  String? selectedStudentId;

  /// Tanlangan talabaning korinadigan nomi.
  ///
  /// Dropdown orniga qidiruv oynasi ishlatilgani uchun tanlangan
  /// talabani alohida saqlaymiz.
  String? selectedStudentName;

  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
  /// Ro'yxatdan o'tgan qiz talabalarni yuklaydi.
  ///
  /// Ilgari 'foydalanuvchilar' kolleksiyasi real vaqtda tinglanardi.
  /// Endi Laravel'dan bir marta olinadi.
  /// Qiz talabalarni server tomonda qidiradi.
  ///
  /// NEGA QIDIRUV, DROPDOWN EMAS
  /// ---------------------------
  /// Ilgari barcha talabalar yuklanib, dropdown ga solinardi. 2000
  /// talabada bu uch muammo tugdiradi:
  ///   1) backend bir sorovda 100 tadan kop bermaydi - qolganlari
  ///      umuman korinmasdi;
  ///   2) 2000 elementli dropdown ilovani sekinlashtiradi;
  ///   3) kerakli odamni royxatdan topish deyarli imkonsiz.
  ///
  /// Endi faqat qidiruvga mos 70 ta natija yuklanadi.
  Future<List<Map<String, dynamic>>> _talabaQidir(String matn) async {
    final natija = <Map<String, dynamic>>[];

    try {
      final parametrlar = <String, String>{
        'role': 'talaba',
        'hostel': 'girls',
        'per_page': '70',
      };
      if (matn.trim().isNotEmpty) {
        parametrlar['search'] = matn.trim();
      }

      final javob = await ApiService().get(
        'students?${Uri(queryParameters: parametrlar).query}',
      );

      // Backend ba'zan paginate() obyektini qaytaradi.
      final xom = javob['data'];
      final royxat = xom is Map ? xom['data'] : xom;

      if (royxat is List) {
        for (final e in royxat) {
          if (e is Map) natija.add(Map<String, dynamic>.from(e));
        }
      }
    } catch (e) {
      debugPrint('Talabalarni qidirishda xatolik: $e');
    }

    return natija;
  }

  /// Talaba tanlash oynasini ochadi.
  Future<void> _talabaTanlash(RoomModel liveRoom) async {
    final tanlangan = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QizTalabaQidiruvSheet(
        qidir: _talabaQidir,
        // Xonasi bor talabalar korsatilmaydi - avval ularni
        // hozirgi xonasidan chiqarish kerak.
        faqatXonasizlar: true,
        chiqarib: liveRoom.studentIds,
      ),
    );

    if (tanlangan == null || !mounted) return;

    setState(() {
      selectedStudentId = (tanlangan['id'] ?? '').toString();
      selectedStudentName =
          (tanlangan['full_name'] ?? tanlangan['fullName'] ?? '').toString();
    });
  }


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

                        // Talaba tanlash.
                        //
                        // Ilgari dropdown bor edi va unga barcha
                        // talabalar yuklanardi. 2000 talabada u
                        // ishlamaydi: backend 100 tadan kop bermaydi,
                        // dropdown esa sekinlashadi.
                        //
                        // Endi qidiruv oynasi: yozilgan matn serverga
                        // boradi va faqat mos 70 ta natija keladi.
                        Material(
                          color: GTheme.bgCard2,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _talabaTanlash(liveRoom),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selectedStudentId == null
                                        ? Icons.person_search_rounded
                                        : Icons.person_rounded,
                                    color: selectedStudentId == null
                                        ? Colors.white54
                                        : GTheme.pink,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedStudentName ??
                                          "Talaba tanlash uchun bosing",
                                      style: TextStyle(
                                        color: selectedStudentId == null
                                            ? Colors.white54
                                            : Colors.white,
                                        fontWeight: selectedStudentId == null
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (selectedStudentId != null)
                                    IconButton(
                                      tooltip: 'Bekor qilish',
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18, color: Colors.white54),
                                      onPressed: () => setState(() {
                                        selectedStudentId = null;
        selectedStudentName = null;
                                        selectedStudentName = null;
                                      }),
                                    )
                                  else
                                    const Icon(Icons.chevron_right_rounded,
                                        color: Colors.white38),
                                ],
                              ),
                            ),
                          ),
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
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _talabaQidir(''),
                          builder: (context, usersSnap) {
                            final registeredById =
                                <String, Map<String, dynamic>>{
                              for (final d in usersSnap.data ?? const [])
                                (d['id'] ?? '').toString(): d,
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
        selectedStudentName = null;
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

// =====================================================================
// QIZ TALABA QIDIRUV OYNASI
// =====================================================================
//
// Dropdown o'rniga ishlatiladi. Ro'yxat butunlay yuklanmaydi —
// faqat qidiruvga mos 70 ta natija keladi. Shu tufayli 2000
// talabada ham bir xil tez ishlaydi.

class _QizTalabaQidiruvSheet extends StatefulWidget {
  /// Serverdan qidiradigan funksiya.
  final Future<List<Map<String, dynamic>>> Function(String) qidir;

  /// true bo'lsa, xonasi bor talabalar ko'rsatilmaydi.
  final bool faqatXonasizlar;

  /// Qo'shimcha chiqarib tashlanadigan ID lar (shu xonadagilar).
  final List<String> chiqarib;

  const _QizTalabaQidiruvSheet({
    required this.qidir,
    this.faqatXonasizlar = true,
    this.chiqarib = const [],
  });

  @override
  State<_QizTalabaQidiruvSheet> createState() => _QizTalabaQidiruvSheetState();
}

class _QizTalabaQidiruvSheetState extends State<_QizTalabaQidiruvSheet> {
  final _ctrl = TextEditingController();

  List<Map<String, dynamic>> _natija = const [];
  bool _yuklanmoqda = true;
  Timer? _kutish;

  @override
  void initState() {
    super.initState();
    _qidir('');
    _ctrl.addListener(_ozgardi);
  }

  @override
  void dispose() {
    _kutish?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Har bosilgan harfda so'rov yubormaslik uchun 400 ms kutamiz.
  void _ozgardi() {
    _kutish?.cancel();
    _kutish = Timer(const Duration(milliseconds: 400), () {
      _qidir(_ctrl.text);
    });
  }

  Future<void> _qidir(String matn) async {
    if (!mounted) return;
    setState(() => _yuklanmoqda = true);

    final xom = await widget.qidir(matn);

    if (!mounted) return;

    final filtrlangan = xom.where((d) {
      final id = (d['id'] ?? '').toString();
      if (widget.chiqarib.contains(id)) return false;

      if (widget.faqatXonasizlar) {
        // Xonasi bor talabalar ko'rsatilmaydi — avval ularni
        // hozirgi xonasidan chiqarish kerak.
        final b = d['active_room_assignment'] ?? d['activeRoomAssignment'];
        if (b is Map) return false;
      }

      return true;
    }).toList();

    setState(() {
      _natija = filtrlangan;
      _yuklanmoqda = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: GTheme.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_search_rounded, color: GTheme.pink),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Talaba tanlash",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Ism yoki JSHSHIR bo'yicha qidirish...",
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: Colors.white54),
                    filled: true,
                    fillColor: GTheme.bgCard2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (_yuklanmoqda)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: GTheme.pink,
                ),
              Expanded(
                child: _natija.isEmpty && !_yuklanmoqda
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_rounded,
                                size: 48, color: Colors.white24),
                            const SizedBox(height: 10),
                            Text(
                              _ctrl.text.isEmpty
                                  ? "Xonasi yo'q talaba topilmadi"
                                  : "Natija topilmadi",
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                        itemCount: _natija.length,
                        itemBuilder: (context, i) {
                          final d = _natija[i];
                          final ism =
                              (d['full_name'] ?? d['fullName'] ?? '—')
                                  .toString();
                          final fakultet = (d['faculty'] ?? '').toString();
                          final kurs = d['course'];
                          final qosh = <String>[
                            if (fakultet.isNotEmpty) fakultet,
                            if (kurs != null) "$kurs-kurs",
                          ].join(' · ');

                          final harf =
                              ism.isNotEmpty ? ism[0].toUpperCase() : '?';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: GTheme.bgCard2,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.pop(context, d),
                                child: Padding(
                                  padding: const EdgeInsets.all(13),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: GTheme.pink.withOpacity(0.18),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          harf,
                                          style: const TextStyle(
                                            color: GTheme.pink,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ism,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (qosh.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                qosh,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.white54,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right_rounded,
                                          color: Colors.white38),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
