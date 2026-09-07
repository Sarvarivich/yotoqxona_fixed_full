import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  @override
  Widget build(BuildContext context) {
    // ⚡ Xona hujjatining o'zini ("xonalar/{roomDocId}") REAL VAQTDA
    // tinglaymiz. Avval bu yerda faqat `widget.room` (ekranga bir marta,
    // navigatsiya paytida uzatilgan statik obyekt) ishlatilardi — shu
    // sababli talaba xonaga biriktirilgandan keyin, "Yashovchi talabalar"
    // ro'yxati DARHOL yangilanmasdi (chunki studentIds ro'yxati hamon eski
    // qiymatda qolardi), faqat ekrandan chiqib qayta kirilganda ko'rinardi.
    // Endi xona hujjati o'zgarishi bilanoq (studentIds, capacity va h.k.)
    // butun ekran avtomatik qayta chiziladi.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('xonalar')
          .doc(widget.roomDocId)
          .snapshots(),
      builder: (context, roomSnapshot) {
        if (roomSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final roomData =
            roomSnapshot.data?.data() as Map<String, dynamic>? ?? {};
        final liveStudentIds =
            List<String>.from(roomData['studentIds'] ?? widget.room.studentIds);
        final liveCapacity = (roomData['capacity'] as num?)?.toInt() ??
            (widget.room.capacity > 0 ? widget.room.capacity : 4);

        return _RoomAssignmentBody(
          widgetRoom: widget.room,
          roomDocId: widget.roomDocId,
          hostel: widget.hostel,
          liveStudentIds: liveStudentIds,
          liveCapacity: liveCapacity,
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

  const _RoomAssignmentBody({
    required this.widgetRoom,
    required this.roomDocId,
    required this.hostel,
    required this.liveStudentIds,
    required this.liveCapacity,
  });

  @override
  State<_RoomAssignmentBody> createState() => _RoomAssignmentBodyState();
}

class _RoomAssignmentBodyState extends State<_RoomAssignmentBody> {
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .where(FieldPath.documentId,
              whereIn: liveStudentIds.isEmpty ? ['__empty__'] : liveStudentIds)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final List<DocumentSnapshot> assignedStudents =
            snapshot.hasData ? snapshot.data!.docs : [];

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
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('foydalanuvchilar')
                              .where('role', isEqualTo: 'talaba')
                              .snapshots(),
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
                                studentSnapshot.data!.docs.where((doc) {
                              final data =
                                  doc.data() as Map<String, dynamic>? ?? {};
                              final roomId =
                                  (data['roomId'] ?? '').toString().trim();
                              if (roomId.isNotEmpty) {
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
                            final allStudentIds =
                                allStudents.map((doc) => doc.id).toSet();

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
                              items: allStudents.map((doc) {
                                final student = UserModel.fromJson(
                                    doc.data() as Map<String, dynamic>);
                                // Bu ro'yxatga endi faqat xonasi yo'q
                                // ("bo'sh") talabalar tushadi, shuning
                                // uchun qo'shimcha "hozir: X-xona" belgisi
                                // shart emas.
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(student.fullName),
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
                                    final userRef = FirebaseFirestore.instance
                                        .collection('foydalanuvchilar')
                                        .doc(studentId);
                                    final roomRef = FirebaseFirestore.instance
                                        .collection('xonalar')
                                        .doc(roomDocId);

                                    // Talaba boshqa xonada turgan bo'lishi
                                    // mumkin (masalan admin uni oldin
                                    // boshqa xonaga biriktirgan). Shunday
                                    // bo'lsa, avval o'sha eski xonadan
                                    // chiqaramiz — aks holda ikkita xonada
                                    // bir vaqtda "yashab qolgan" bo'lib,
                                    // hisob-kitob buziladi.
                                    final userSnap = await userRef.get();
                                    final oldRoomId = (userSnap.data())?['roomId']
                                        as String?;

                                    DocumentSnapshot? oldRoomDoc;
                                    if (oldRoomId != null &&
                                        oldRoomId.isNotEmpty &&
                                        oldRoomId !=
                                            room.roomNumber.toString()) {
                                      final oldRoomQuery =
                                          await FirebaseFirestore.instance
                                              .collection('xonalar')
                                              .where('roomNumber',
                                                  isEqualTo:
                                                      int.tryParse(oldRoomId) ??
                                                          oldRoomId)
                                              .limit(1)
                                              .get();
                                      if (oldRoomQuery.docs.isNotEmpty) {
                                        oldRoomDoc = oldRoomQuery.docs.first;
                                      }
                                    }

                                    final batch =
                                        FirebaseFirestore.instance.batch();

                                    if (oldRoomDoc != null) {
                                      final oldRoomData = oldRoomDoc.data()
                                          as Map<String, dynamic>;
                                      final oldOccupants =
                                          (oldRoomData['currentOccupants']
                                                      as num?)
                                                  ?.toInt() ??
                                              0;
                                      final oldCapacity =
                                          (oldRoomData['capacity'] as num?)
                                                  ?.toInt() ??
                                              0;
                                      final newOldOccupants = (oldOccupants - 1)
                                          .clamp(0, oldOccupants);
                                      batch.update(oldRoomDoc.reference, {
                                        'currentOccupants': newOldOccupants,
                                        'studentIds':
                                            FieldValue.arrayRemove([studentId]),
                                        'status': newOldOccupants < oldCapacity
                                            ? RoomStatus.empty.name
                                            : oldRoomData['status'],
                                      });
                                    }

                                    batch.update(userRef, {
                                      'roomId': room.roomNumber.toString(),
                                      'hostel': hostel,
                                    });
                                    batch.update(roomRef, {
                                      'currentOccupants':
                                          FieldValue.increment(1),
                                      'studentIds':
                                          FieldValue.arrayUnion([studentId]),
                                      // 🛠️ Xona to'lib qolsa, holatini ham
                                      // avtomatik "band" (occupied) qilib
                                      // qo'yamiz — aks holda statistika va
                                      // Dashboard'da xona "bo'sh" bo'lib
                                      // ko'rinib qolaveradi.
                                      'status':
                                          (currentStudentsCount + 1) >= capacity
                                              ? RoomStatus.occupied.name
                                              : room.status.name,
                                    });

                                    await batch.commit();

                                    setState(() {
                                      selectedStudentId = null;
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
                            final student = UserModel.fromJson(
                                studentDoc.data() as Map<String, dynamic>);

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
                                    final String studentId = studentDoc.id;

                                    final batch =
                                        FirebaseFirestore.instance.batch();
                                    final userRef = FirebaseFirestore.instance
                                        .collection('foydalanuvchilar')
                                        .doc(studentId);
                                    final roomRef = FirebaseFirestore.instance
                                        .collection('xonalar')
                                        .doc(roomDocId);

                                    batch.update(userRef, {
                                      // ⚠️ Avval bu yerda `''` (bo'sh
                                      // satr) yozilar edi. Ammo xona
                                      // biriktirish ekrani
                                      // (modules/xonalar/xona_taqsimlash.dart)
                                      // "bo'sh" talabalarni topish uchun
                                      // `roomId == null` shartidan
                                      // foydalanadi — shu sababli bo'sh
                                      // satr yozilgan talaba xato
                                      // ravishda "hali ham biriktirilgan"
                                      // deb ko'rinib, biriktirish
                                      // ro'yxatida umuman chiqmay qolar
                                      // edi. Endi `null` yoziladi — bu
                                      // ilova bo'ylab "xonasi yo'q"
                                      // holatining yagona standarti.
                                      'roomId': null,
                                      'hostel': hostel,
                                    });
                                    batch.update(roomRef, {
                                      'currentOccupants':
                                          FieldValue.increment(-1),
                                      'studentIds':
                                          FieldValue.arrayRemove([studentId]),
                                      // 🛠️ Agar xona avtomatik "band" deb
                                      // belgilangan bo'lsa-yu, endi joy
                                      // bo'shagan bo'lsa — holatini "bo'sh"ga
                                      // qaytaramiz. Admin qo'lda "Ta'mirlashda"
                                      // yoki "To'lov kutilmoqda" deb qo'ygan
                                      // bo'lsa, bu holatlarga tegmaymiz.
                                      'status':
                                          (room.status == RoomStatus.occupied &&
                                                  (currentStudentsCount - 1) <
                                                      capacity)
                                              ? RoomStatus.empty.name
                                              : room.status.name,
                                    });

                                    await batch.commit();

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
      },
    );
  }
}
