import 'dart:async';

import 'package:flutter/material.dart';
import '../modules/services/api_service.dart';
import '../modules/models/room_model.dart';
import '../modules/models/user_model.dart';

class RoomDetailsScreen extends StatefulWidget {
  final String roomDocId;
  final RoomModel room;
  final String hostel;

  const RoomDetailsScreen({
    super.key,
    required this.roomDocId,
    required this.room,
    this.hostel = 'boys',
  });

  @override
  State<RoomDetailsScreen> createState() => _RoomDetailsScreenState();
}

class _RoomDetailsScreenState extends State<RoomDetailsScreen> {
  final _api = ApiService();

  // MUHIM: Future initState'da yaratiladi. build() ichida yaratilsa,
  // har bir qayta chizishda yangi so'rov ketardi.
  late Future<Map<String, dynamic>> _xona;

  @override
  void initState() {
    super.initState();
    _xona = _yukla();
  }

  Future<Map<String, dynamic>> _yukla() async {
    try {
      final javob = await _api.getRoom(widget.roomDocId);
      final d = javob['data'];
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _qaytaYukla() async {
    if (!mounted) return;
    setState(() {
      _xona = _yukla();
    });
    await _xona;
  }

  @override
  Widget build(BuildContext context) {
    // Xona ma'lumoti Laravel'dan olinadi.
    //
    // Ilgari Firestore hujjati real vaqtda tinglanardi va talaba
    // biriktirilishi bilan ro'yxat o'zi yangilanardi. Endi har bir
    // o'zgarishdan keyin _qaytaYukla() chaqiriladi.
    return FutureBuilder<Map<String, dynamic>>(
      future: _xona,
      builder: (context, roomSnapshot) {
        if (roomSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final roomData = roomSnapshot.data ?? const <String, dynamic>{};

        // Xonadagi talabalar backend javobida keladi.
        final aktivTalabalar = roomData['active_students'];
        final talabalar = aktivTalabalar is List
            ? aktivTalabalar
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : const <Map<String, dynamic>>[];

        final liveStudentIds =
            talabalar.map((e) => (e['id'] ?? '').toString()).toList();

        final liveCapacity = int.tryParse(
              (roomData['capacity'] ?? widget.room.capacity).toString(),
            ) ??
            (widget.room.capacity > 0 ? widget.room.capacity : 4);

        return _RoomAssignmentBody(
          widgetRoom: widget.room,
          roomDocId: widget.roomDocId,
          hostel: widget.hostel,
          liveStudentIds: liveStudentIds,
          liveCapacity: liveCapacity,
          talabalar: talabalar,
          onChanged: _qaytaYukla,
        );
      },
    );
  }
}

class _RoomAssignmentBody extends StatefulWidget {
  final RoomModel widgetRoom;
  final String roomDocId;
  final String hostel;
  final List<String> liveStudentIds;
  final int liveCapacity;

  /// Xonada yashayotgan talabalar (backend javobidan).
  final List<Map<String, dynamic>> talabalar;

  /// Biriktirish yoki chiqarishdan keyin xonani qayta yuklaydi.
  final Future<void> Function() onChanged;

  const _RoomAssignmentBody({
    required this.widgetRoom,
    required this.roomDocId,
    required this.hostel,
    required this.liveStudentIds,
    required this.liveCapacity,
    required this.talabalar,
    required this.onChanged,
  });

  @override
  State<_RoomAssignmentBody> createState() => _RoomAssignmentBodyState();
}

class _RoomAssignmentBodyState extends State<_RoomAssignmentBody> {
  final _api = ApiService();

  /// Tanlangan talabaning korinadigan nomi.
  ///
  /// Dropdown orniga qidiruv oynasi ishlatilgani uchun tanlangan
  /// talabani alohida saqlaymiz - qayta yuklashda yoqolmasin.
  String? selectedStudentName;

  /// Talabalarni server tomonda qidiradi.
  ///
  /// NEGA QIDIRUV, DROPDOWN EMAS
  /// ---------------------------
  /// Ilgari barcha talabalar yuklanib, dropdown ga solinardi. 2000
  /// talabada bu uch muammo tugdiradi:
  ///   1) backend bir sorovda 100 tadan kop bermaydi - qolganlari
  ///      umuman korinmasdi;
  ///   2) 2000 elementli dropdown brauzerni sekinlashtiradi;
  ///   3) kerakli odamni royxatdan topish deyarli imkonsiz.
  ///
  /// Endi faqat qidiruvga mos 50 ta natija yuklanadi. Bu 2000 ta ham,
  /// 10 000 ta ham bir xil tez ishlaydi.
  Future<List<Map<String, dynamic>>> _talabaQidir(String matn) async {
    final natija = <Map<String, dynamic>>[];

    try {
      final parametrlar = <String, String>{
        'role': 'talaba',
        'per_page': '70',
      };
      if (matn.trim().isNotEmpty) {
        parametrlar['search'] = matn.trim();
      }

      final javob = await _api.get(
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
  Future<void> _talabaTanlash() async {
    final tanlangan = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TalabaQidiruvSheet(
        qidir: _talabaQidir,
        // Shu xonada yashayotganlar royxatda korsatilmaydi.
        chiqarib: widget.liveStudentIds,
        binoFiltri: widget.widgetRoom.hostelType == 'university'
            ? (widget.hostel.trim().isEmpty
                ? 'boys'
                : widget.hostel.trim().toLowerCase())
            : null,
      ),
    );

    if (tanlangan == null || !mounted) return;

    setState(() {
      selectedStudentId = (tanlangan['id'] ?? '').toString();
      selectedStudentName =
          (tanlangan['full_name'] ?? tanlangan['fullName'] ?? '').toString();
    });
  }

  void _showStudentInfo(BuildContext context, UserModel student) {
    final extra = student.additionalData ?? const <String, dynamic>{};
    String value(String key, [String fallback = '—']) {
      final v = extra[key];
      final text = v?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.purple.shade100,
                      child: Text(
                        student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.purple.shade700),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(student.studentId ?? 'Student ID mavjud emas', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Talaba ma’lumotlari', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _studentInfoRow(Icons.phone_outlined, 'Telefon', student.phoneNumber),
                _studentInfoRow(Icons.badge_outlined, 'JSHSHIR', student.jshshir ?? '—'),
                _studentInfoRow(Icons.school_outlined, 'Fakultet', student.faculty ?? '—'),
                _studentInfoRow(Icons.menu_book_outlined, 'Kurs', student.course ?? '—'),
                _studentInfoRow(Icons.location_on_outlined, 'Viloyat / tuman', '${student.region ?? '—'} / ${student.district ?? '—'}'),
                _studentInfoRow(Icons.groups_rounded, 'Ijtimoiy holat', value('socialStatus', value('ijtimoiyHolat', 'Oddiy holat'))),
                _studentInfoRow(Icons.apartment_rounded, 'Yotoqxona', _hostelTypeLabel(value('hostelAssignmentType', 'university'))),
                _studentInfoRow(Icons.door_front_door_outlined, 'Xona', student.roomId ?? '—'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(.07), borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    'Ariza holati: ${value('applicationStatus', '—')}  •  Bosqich: ${value('applicationStep', '—')}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _hostelTypeLabel(String type) {
    switch (type) {
      case 'medical': return 'Tibbiyot kolleji yotoqxonasi';
      case 'avto_yol': return 'Avto yo‘l yotoqxonasi';
      case 'navoi_object': return 'Navoiy obyekti';
      case 'rental': return 'Ijara uchun ajratilgan';
      default: return 'Universitet yotoqxonasi';
    }
  }

  Widget _studentInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.purple.shade600),
          const SizedBox(width: 10),
          SizedBox(width: 145, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  String? selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final room = widget.widgetRoom;
    final roomDocId = widget.roomDocId;
    final hostel = widget.hostel;
    final liveStudentIds = widget.liveStudentIds;
    final capacity = widget.liveCapacity;

    // Xonadagi talabalar allaqachon yuklangan - qo'shimcha so'rov
    // kerak emas. Backend /api/rooms/{id} javobida active_students
    // massivini qaytaradi.
    {
      {
        final assignedStudents = widget.talabalar;

        final int currentStudentsCount = assignedStudents.length;
        bool isRoomFull = currentStudentsCount >= capacity;

        return Scaffold(
          appBar: AppBar(
            title: Text("${room.roomNumber}-xona ma'lumotlari"),
            centerTitle: true,
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
                    color: isRoomFull
                        ? Colors.red.shade600
                        : Colors.green.shade600,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "${room.roomNumber}",
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        "${room.floor}-qavat",
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
                              color: isRoomFull ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Xona ma'lumotlari kartasi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Xona ma'lumotlari",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          ListTile(
                            leading:
                                const Icon(Icons.people, color: Colors.blue),
                            title: const Text("Sig'imi:"),
                            trailing: Text("$capacity kishi"),
                          ),
                          ListTile(
                            leading: Icon(Icons.person,
                                color: isRoomFull ? Colors.red : Colors.green),
                            title: const Text("Hozirgi bandlik:"),
                            trailing: Text("$currentStudentsCount / $capacity"),
                          ),
                          ListTile(
                            leading:
                                const Icon(Icons.money, color: Colors.orange),
                            title: const Text("Oylik to'lov:"),
                            trailing: Text("${room.pricePerMonth} so'm"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. TALABA BIRIKTIRISH FUNKSIYASI (QIDIRUVSIZ, TOZA DROPDOWN)
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
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        // Talaba tanlash.
                        //
                        // Ilgari bu yerda dropdown bor edi va unga barcha
                        // talabalar yuklanardi. 2000 talabada u ishlamaydi:
                        // backend 100 tadan kop bermaydi, dropdown esa
                        // sekinlashadi va kerakli odamni topib bolmaydi.
                        //
                        // Endi qidiruv oynasi: yozilgan matn serverga
                        // boradi va faqat mos 50 ta natija keladi.
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _talabaTanlash,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selectedStudentId == null
                                        ? Icons.person_search_rounded
                                        : Icons.person_rounded,
                                    color: selectedStudentId == null
                                        ? Colors.grey.shade600
                                        : Colors.purple,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedStudentName ??
                                          "Talaba tanlash uchun bosing",
                                      style: TextStyle(
                                        color: selectedStudentId == null
                                            ? Colors.grey.shade600
                                            : Colors.black87,
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
                                          size: 18),
                                      onPressed: () => setState(() {
                                        selectedStudentId = null;
                                        selectedStudentName = null;
                                      }),
                                    )
                                  else
                                    Icon(Icons.chevron_right_rounded,
                                        color: Colors.grey.shade500),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Biriktirish tugmasi
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: selectedStudentId == null
                                ? null
                                : () async {
                                    final String studentId = selectedStudentId!;

                                    // Biriktirish Laravel tomonida bitta
                                    // tranzaksiyada bajariladi: eski
                                    // biriktirish yopiladi, yangisi
                                    // ochiladi, xona bandligi va holati
                                    // yangilanadi. Sig'im tekshiruvi ham
                                    // o'sha yerda - ikki mudir bir vaqtda
                                    // oxirgi joyni band qilsa, ikkinchisi
                                    // xato oladi.
                                    try {
                                      await _api.assignStudentToRoom(
                                        studentId: studentId,
                                        roomId: roomDocId,
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Biriktirib bo'lmadi: "
                                            "${e.toString().replaceFirst('Exception: ', '')}",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    await widget.onChanged();

                                    if (!context.mounted) return;

                                    // Tanlovni tozalaymiz va talabalar
                                    // ro'yxatini qayta yuklaymiz - endi
                                    // bu talabaning xonasi o'zgargan.
                                    setState(() {
                                      selectedStudentId = null;
                                      selectedStudentName = null;
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Talaba xonaga muvaffaqiyatli biriktirildi!")),
                                    );
                                  },
                            child: const Text("Talabani biriktirish",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
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
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text("$currentStudentsCount ta",
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (assignedStudents.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text("Bu xonada hozircha hech kim yashamaydi.",
                              style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: assignedStudents.length,
                          itemBuilder: (context, index) {
                            final studentDoc = assignedStudents[index];
                            final student = UserModel.fromJson(studentDoc);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                onTap: () => _showStudentInfo(context, student),
                                leading: CircleAvatar(
                                    backgroundColor: Colors.purple.shade100,
                                    child: Text(
                                        student.fullName.isNotEmpty
                                            ? student.fullName[0].toUpperCase()
                                            : "?",
                                        style: const TextStyle(
                                            color: Colors.purple,
                                            fontWeight: FontWeight.bold))),
                                title: Text(student.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                                subtitle: Text(student.phoneNumber),
                                trailing: IconButton(
                                  icon: const Icon(Icons.logout,
                                      color: Colors.red),
                                  onPressed: () async {
                                    final String studentId =
                                        (studentDoc['id'] ?? '').toString();

                                    // Chiqarish ham Laravel tomonida
                                    // bitta tranzaksiyada bajariladi:
                                    // biriktirish yopiladi, xona
                                    // bandligi va holati yangilanadi.
                                    try {
                                      // Avval biriktirish yozuvini
                                      // topamiz - uni bekor qilish uchun
                                      // ID kerak.
                                      String? aid;
                                      final biriktirishlar =
                                          await _api.getRoomAssignments();

                                      for (final b in biriktirishlar) {
                                        if (b is! Map) continue;
                                        final d =
                                            Map<String, dynamic>.from(b);
                                        if ((d['room_id'] ?? '').toString() !=
                                            roomDocId) {
                                          continue;
                                        }
                                        if ((d['student_id'] ?? '')
                                                .toString() !=
                                            studentId) {
                                          continue;
                                        }
                                        aid = (d['id'] ?? '').toString();
                                        break;
                                      }

                                      if (aid == null || aid.isEmpty) {
                                        throw Exception(
                                            'Biriktirish yozuvi topilmadi.');
                                      }

                                      await _api.unassignRoomStudent(aid);
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Chiqarib bo'lmadi: "
                                            "${e.toString().replaceFirst('Exception: ', '')}",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    await widget.onChanged();

                                    if (!context.mounted) return;

                                    setState(() {
                                      selectedStudentName = null;
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Talaba xonadan chiqarildi.")),
                                    );
                                  },
                                ),
                              ),
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
      }
    }
  }
}

// =====================================================================
// TALABA QIDIRUV OYNASI
// =====================================================================
//
// Dropdown o'rniga ishlatiladi. Farqi: ro'yxat butunlay yuklanmaydi,
// faqat qidiruvga mos 50 ta natija keladi. Shu tufayli 2000 talabada
// ham, 10 000 talabada ham bir xil tez ishlaydi.

class _TalabaQidiruvSheet extends StatefulWidget {
  /// Serverdan qidiradigan funksiya.
  final Future<List<Map<String, dynamic>>> Function(String) qidir;

  /// Ro'yxatda ko'rsatilmaydigan talabalar (shu xonada yashayotganlar).
  final List<String> chiqarib;

  /// Bino filtri: 'boys' yoki 'girls'. null bo'lsa filtr yo'q
  /// (universitetdan boshqa yotoqxona turlarida jins bo'yicha
  /// ajratilmaydi).
  final String? binoFiltri;

  const _TalabaQidiruvSheet({
    required this.qidir,
    required this.chiqarib,
    this.binoFiltri,
  });

  @override
  State<_TalabaQidiruvSheet> createState() => _TalabaQidiruvSheetState();
}

class _TalabaQidiruvSheetState extends State<_TalabaQidiruvSheet> {
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

      if (widget.binoFiltri != null) {
        final bino =
            (d['hostel'] ?? '').toString().trim().toLowerCase();
        final normal = bino.isEmpty ? 'boys' : bino;
        if (normal != widget.binoFiltri) return false;
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
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_search_rounded,
                        color: Colors.purple),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Talaba tanlash",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
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
                  decoration: InputDecoration(
                    hintText: "Ism, email yoki JSHSHIR bo'yicha qidirish...",
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _ctrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => _ctrl.clear(),
                          ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (_yuklanmoqda) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: _natija.isEmpty && !_yuklanmoqda
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(
                              _ctrl.text.isEmpty
                                  ? "Biriktirish uchun talaba topilmadi"
                                  : "Natija topilmadi",
                              style: TextStyle(color: Colors.grey.shade600),
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
                          final student = UserModel.fromJson(d);

                          // Boshqa xonada turgan talaba bo'lsa, hozirgi
                          // xonasini ko'rsatamiz - tanlansa u shu yerga
                          // ko'chiriladi.
                          final hozirgi = student.roomNumber;
                          final qosh = <String>[
                            if (student.faculty != null &&
                                student.faculty!.isNotEmpty)
                              student.faculty!,
                            if (student.course != null &&
                                student.course!.isNotEmpty)
                              "${student.course}-kurs",
                            if (hozirgi != null && hozirgi.trim().isNotEmpty)
                              "hozir: $hozirgi-xona",
                          ].join(' · ');

                          final harf = student.fullName.isNotEmpty
                              ? student.fullName[0].toUpperCase()
                              : '?';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.grey.shade50,
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
                                          color: Colors.purple.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          harf,
                                          style: const TextStyle(
                                            color: Colors.purple,
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
                                              student.fullName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (qosh.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                qosh,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.grey.shade600,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded,
                                          color: Colors.grey.shade400),
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
