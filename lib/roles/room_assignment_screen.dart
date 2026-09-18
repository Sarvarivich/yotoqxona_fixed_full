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

  // MUHIM: Future initState'da bir marta yaratiladi.
  //
  // Agar u build() ichida yaratilsa, har bir qayta chizishda yangi
  // so'rov ketardi va ro'yxat doimo o'zgarib turardi - natijada
  // DropdownButton "value bir marta uchramadi" degan xato berardi.
  late Future<List<Map<String, dynamic>>> _talabalarFuture;

  @override
  void initState() {
    super.initState();
    _talabalarFuture = _barchaTalabalar();
  }

  /// Xonaga biriktirish uchun talabalar ro'yxatini yuklaydi.
  ///
  /// Backend bir so'rovda 100 tadan ko'p bermaydi, shuning uchun
  /// oxirgi sahifagacha aylanamiz.
  Future<List<Map<String, dynamic>>> _barchaTalabalar() async {
    final natija = <Map<String, dynamic>>[];

    try {
      int sahifa = 1;
      int oxirgi = 1;

      do {
        final javob = await _api.get(
          'students?role=talaba&per_page=100&page=$sahifa',
        );

        // Backend ba'zan paginate() obyektini qaytaradi - u holda
        // ro'yxat data ichidagi data da bo'ladi.
        final xom = javob['data'];
        final royxat = xom is Map ? xom['data'] : xom;

        if (royxat is List) {
          for (final e in royxat) {
            if (e is Map) natija.add(Map<String, dynamic>.from(e));
          }
        }

        final meta = javob['meta'];
        oxirgi = meta is Map
            ? ((meta['last_page'] as num?)?.toInt() ?? sahifa)
            : sahifa;
        sahifa++;
      } while (sahifa <= oxirgi && sahifa <= 100);
    } catch (e) {
      debugPrint('Talabalarni yuklashda xatolik: $e');
    }

    return natija;
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

                        // 🔓 BARCHA talabalar ro'yxatini olish — talaba
                        // profilida (roomId maydonida) "bo'sh"/"band" holati
                        // bilan filtrlash olib tashlandi. Endi bu yerda
                        // talaba qanday yaratilganidan qat'iy nazar (admin
                        // tomonidan qo'shilgan bo'ladimi yoki o'zi
                        // ro'yxatdan o'tganmi — farqi yo'q) BARCHA "talaba"
                        // rolidagi foydalanuvchilar ko'rinadi. Faqat AYNAN
                        // shu xonada allaqachon yashayotganlar chiqarib
                        // tashlanadi (ular pastdagi "Yashovchi talabalar"
                        // ro'yxatida ko'rinadi). Boshqa xonada turgan talaba
                        // tanlansa, uni shu xonaga ko'chirish (eski xonadan
                        // avtomatik chiqarib, yangisiga biriktirish) sodir
                        // bo'ladi.
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _talabalarFuture,
                          builder: (context, studentSnapshot) {
                            if (!studentSnapshot.hasData) {
                              return const LinearProgressIndicator();
                            }

                            // ⚠️ Ba'zi (odatda eski, "hostel" maydoni
                            // qo'shilishidan oldin yaratilgan) talaba
                            // hujjatlarida "hostel" maydoni umuman yo'q
                            // yoki bo'sh bo'lishi mumkin. Firestore'ning
                            // to'g'ridan-to'g'ri `.where('hostel', ...)`
                            // so'rovi bunday hujjatlarni chetlab o'tib
                            // ketardi (bo'sh natija berardi), shuning
                            // uchun hostel solishtiruvini bu yerda,
                            // client tomonida, "bo'sh bo'lsa 'boys' deb
                            // hisoblanadi" qoidasi bilan (talabalar_list.dart
                            // dagi kabi) bajaramiz.
                            final normalizedTargetHostel = hostel.trim().isEmpty
                                ? 'boys'
                                : hostel.trim().toLowerCase();
                            final roomHostelType = widget.widgetRoom.hostelType;

                            // 🚫 Allaqachon (istalgan) xonaga biriktirilgan
                            // talabalar bu ro'yxatda UMUMAN ko'rsatilmaydi —
                            // faqat hali hech qanday xonaga tegishli
                            // bo'lmagan ("bo'sh"/yangi ro'yxatdan o'tgan)
                            // talabalar chiqadi. Boshqa xonaga o'tkazish
                            // shu ekrandan endi amalga oshirilmaydi.
                            final allStudents =
                                studentSnapshot.data!.where((data) {
                              // Shu xonada yashayotganlar ro'yxatda
                              // ko'rsatilmaydi - ular pastdagi
                              // "Yashovchi talabalar" bo'limida.
                              //
                              // Boshqa xonadagilar KO'RSATILADI: ularni
                              // shu xonaga ko'chirish mumkin, backend
                              // eski biriktirishni o'zi yopadi.
                              final id = (data['id'] ?? '').toString();
                              if (liveStudentIds.contains(id)) {
                                return false;
                              }
                              final rawHostel = (data['hostel'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              final normalizedHostel =
                                  rawHostel.isEmpty ? 'boys' : rawHostel;
                              // Universitet yotoqxonasida jins bo'yicha ajratamiz.
                              // Tibbiyot, Avto yo'l va Navoiy kabi alohida turlarda
                              // xona o'zining hostelType bo'yicha ajratilgani uchun
                              // gender bilan cheklamaymiz.
                              if (roomHostelType != 'university') return true;
                              return normalizedHostel == normalizedTargetHostel;
                            }).toList();

                            if (allStudents.isEmpty) {
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

                            // Dropdown uchun doim UNIKAL va MAVJUD qiymatlardan
                            // foydalanamiz: Firestore doc.id (student.id emas,
                            // chunki u bo'sh/bir xil bo'lib qolishi mumkin).
                            final allStudentIds = allStudents
                                .map((d) => (d['id'] ?? '').toString())
                                .toSet();

                            // Agar tanlangan talaba ro'yxatdan chiqib ketgan
                            // bo'lsa (masalan, Firestore optimistik yozuvi
                            // sabab ro'yxat darhol yangilanib ketsa, ammo
                            // selectedStudentId hali null qilinmagan bo'lsa),
                            // dropdown value'sini xavfsiz ravishda null qilib
                            // yuboramiz — shu orqali "0 yoki 2+" assertion
                            // xatoligining oldi olinadi.
                            final safeValue =
                                allStudentIds.contains(selectedStudentId)
                                    ? selectedStudentId
                                    : null;

                            return DropdownButtonFormField<String>(
                              // key ro'yxat o'zgarganda widget'ni qayta
                              // yaratadi. Ansiz Form maydoni eski
                              // tanlangan qiymatni ichida saqlab qolardi
                              // va u ro'yxatdan chiqib ketganda
                              // "value bir marta uchramadi" xatosi
                              // chiqardi.
                              key: ValueKey(
                                '${allStudentIds.length}_${safeValue ?? ''}',
                              ),
                              initialValue: safeValue,
                              hint: const Text("Talabalar ro'yxati"),
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              items: allStudents.map((d) {
                                final student = UserModel.fromJson(d);

                                // Boshqa xonada turgan talaba bo'lsa,
                                // hozirgi xonasini ham ko'rsatamiz -
                                // tanlaganda u shu yerga ko'chiriladi.
                                final hozirgi = student.roomNumber;
                                final matn = hozirgi != null &&
                                        hozirgi.trim().isNotEmpty
                                    ? '${student.fullName}  ·  hozir: $hozirgi-xona'
                                    : student.fullName;

                                return DropdownMenuItem<String>(
                                  value: (d['id'] ?? '').toString(),
                                  child: Text(
                                    matn,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => selectedStudentId = val),
                            );
                          },
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
                                      _talabalarFuture = _barchaTalabalar();
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
                                      _talabalarFuture = _barchaTalabalar();
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
