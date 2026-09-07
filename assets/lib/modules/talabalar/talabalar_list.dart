import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yotoqxona/modules/models/user_model.dart';
import 'package:yotoqxona/modules/services/auth_service.dart';

// ─── Creative LIGHT palette ───
class _LC {
  static const bg = Color(0xFFF3F1FB);
  static const card = Colors.white;
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFA29BFE);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFFD79A8);
  static const orange = Color(0xFFFDCB6E);
  static const coral = Color(0xFFE17055);
  static const ink = Color(0xFF2D2A4A);
  static const muted = Color(0xFF8B86A8);
  static const faint = Color(0xFFE9E5FA);
}

class TalabalarList extends StatefulWidget {
  final bool isAdmin;
  final String hostel;
  // Foydalanuvchini butunlay o'chirish huquqi. Berilmasa, isAdmin qiymati
  // bilan bir xil bo'ladi (eski chaqiruvlar bilan moslik uchun). Bu ajratish
  // "admin" rolidagi foydalanuvchilarga profil boshqaruvini ochiq qoldirib,
  // faqat o'chirish imkoniyatini yashirish uchun kerak (masalan: superAdmin
  // hammasini qila oladi, admin esa o'chira olmaydi).
  final bool? canDelete;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const TalabalarList(
      {super.key,
      required this.isAdmin,
      required this.hostel,
      this.canDelete,
      this.scaffoldKey});

  @override
  State<TalabalarList> createState() => _TalabalarListState();
}

class _TalabalarListState extends State<TalabalarList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String _selectedHostel;
  // 🏠 Faqat talabalar (rol=talaba) uchun: xonaga biriktirilganlik holati
  // bo'yicha filtr. 'all' | 'assigned' | 'unassigned'.
  String _roomFilter = 'all';

  // ⚠️ Muhim: bu oqimlar build() DAN TASHQARIDA, faqat BIR MARTA
  // yaratiladi. Aks holda har bir setState (masalan qidiruvga har bir
  // harf yozilganda) yangi Stream obyekti hosil qilib, StreamBuilder
  // buni "boshqa oqim" deb hisoblab, bir lahzaga qayta yuklanardi — bu
  // esa qidiruv maydonini ham qayta qurib, klaviatura fokusini
  // yo'qotib, har bir harfdan keyin maydonni qayta bosishga majbur
  // qilardi.
  late final Stream<QuerySnapshot> _roomsStream =
      _firestore.collection('xonalar').snapshots();
  late final Stream<QuerySnapshot> _usersStream =
      _firestore.collection('foydalanuvchilar').snapshots();

  bool get _canDelete => widget.canDelete ?? widget.isAdmin;

  @override
  void initState() {
    super.initState();
    // ✅ Ekran ochilganda "all" kabi hech qanday hujjatga mos kelmaydigan
    // qiymat emas, balki admin/mudirning o'z yotoqxonasi (widget.hostel)
    // tanlangan bo'lib boshlanadi. Avvalgi versiyada bu yerda doim "all"
    // turib qolar edi va hech bir tugma bosilmagunicha ro'yxat butunlay
    // bo'sh ko'rinar edi (aynan shu sabab "O'g'il bolalar" bo'limi hech
    // narsa ko'rsatmayotgandek tuyular edi).
    _selectedHostel =
        (widget.hostel.trim().isEmpty ? 'boys' : widget.hostel.trim())
            .toLowerCase();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterDocs(
      List<QueryDocumentSnapshot> docs, Set<String> assignedIds) {
    Iterable<QueryDocumentSnapshot> result = docs;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final fullName = (data['fullName'] ?? '').toString().toLowerCase();

        final firstName = (data['firstName'] ?? '').toString().toLowerCase();

        final lastName = (data['lastName'] ?? '').toString().toLowerCase();

        return fullName.contains(query) ||
            firstName.contains(query) ||
            lastName.contains(query);
      });
    }

    if (_roomFilter != 'all') {
      result = result.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final role = (data['role'] ?? '').toString();
        // Xodimlar (talaba bo'lmaganlar) xona filtridan qat'i nazar ro'yxatda
        // qoladi — filtr faqat talabalarga tegishli.
        if (role != 'talaba') return true;
        final isAssigned = assignedIds.contains(doc.id);
        return _roomFilter == 'assigned' ? isAssigned : !isAssigned;
      });
    }

    return result.toList();
  }

  // Foydalanuvchini o'chirishdan oldin tasdiqlash dialogi
  void _confirmDelete(BuildContext context, String docId, String fullName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _LC.coral),
            SizedBox(width: 8),
            Text('O\'chirishni tasdiqlang'),
          ],
        ),
        content: Text(
          '"$fullName" foydalanuvchisini tizimdan butunlay o\'chirmoqchimisiz?\n\nBu amalni qaytarib bo\'lmaydi!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete, color: Colors.white, size: 18),
            label:
                const Text('O\'chirish', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteUser(context, docId, fullName);
            },
          ),
        ],
      ),
    );
  }

  // 🗑️ Foydalanuvchini xavfsiz o'chirish:
  // - Barcha yozuvlar (xona yangilanishi + user hujjatini o'chirish) BITTA
  //   atomik "batch" ichida yuboriladi. Avvalgi versiyada bu amallar ketma-ket
  //   (bir nechta alohida await) bajarilar edi — shu paytda ekranda ochiq
  //   turgan StreamBuilder("users".snapshots()) oraliq holatni ko'rib qolib,
  //   Firestore SDK ichida "internal" xatolikni chaqirib yuborishi mumkin edi.
  // - "internal"/"unavailable" kabi vaqtinchalik (transient) xatoliklar
  //   Firestore'ning o'zida ma'lum muammo bo'lgani uchun, birinchi urinish
  //   muvaffaqiyatsiz bo'lsa, qisqa kutishdan so'ng avtomatik ravishda
  //   yana bir marta qayta uriniladi.
  Future<void> _deleteUser(
    BuildContext context,
    String docId,
    String fullName, {
    int attempt = 1,
  }) async {
    try {
      // Talaba biriktirilgan xona(lar)ni topib, undan chiqarib olamiz —
      // aks holda xona sig'imi (currentOccupants/studentIds) eskicha qolib
      // ketadi. `hostel` bo'yicha filtrlanmaydi — ba'zi xona hujjatlarida
      // bu maydon yo'q/bo'sh bo'lishi mumkin va shu sabab noto'g'ri
      // chetlab qo'yilib, talaba o'chirilgach xonada "arvoh" bo'lib
      // qolishi mumkin edi.
      final roomsSnap = await _firestore
          .collection('xonalar')
          .where('studentIds', arrayContains: docId)
          .get();

      final batch = _firestore.batch();
      for (final roomDoc in roomsSnap.docs) {
        batch.update(roomDoc.reference, {
          'studentIds': FieldValue.arrayRemove([docId]),
          'currentOccupants': FieldValue.increment(-1),
        });
      }
      batch.delete(_firestore.collection('foydalanuvchilar').doc(docId));
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$fullName" muvaffaqiyatli o\'chirildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseException catch (e) {
      // Firestore'ning o'zi tomonidan qaytariladigan vaqtinchalik xatoliklar
      // ("internal", "unavailable", "aborted") uchun 1 marta qayta urinamiz.
      final isTransient = e.code == 'internal' ||
          e.code == 'unavailable' ||
          e.code == 'aborted' ||
          e.code == 'unknown';
      if (isTransient && attempt < 3) {
        await Future.delayed(Duration(milliseconds: 400 * attempt));
        return _deleteUser(context, docId, fullName, attempt: attempt + 1);
      }
      if (context.mounted) {
        final message = e.code == 'permission-denied'
            ? 'Sizda bu foydalanuvchini o\'chirish uchun ruxsat yo\'q.'
            : 'O\'chirishda xatolik (${e.code}): ${e.message ?? e.code}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('O\'chirishda xatolik: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _selectedHostel == "boys" ? _LC.purple : Colors.white,
                      foregroundColor:
                          _selectedHostel == "boys" ? Colors.white : _LC.purple,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedHostel = "boys";
                      });
                    },
                    child: const Text("O'g'il bolalar"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedHostel == "girls"
                          ? _LC.purple
                          : Colors.white,
                      foregroundColor: _selectedHostel == "girls"
                          ? Colors.white
                          : _LC.purple,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedHostel = "girls";
                      });
                    },
                    child: const Text("Qiz bolalar"),
                  ),
                ),
              ],
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        leading: _isSearching
            ? null
            : widget.scaffoldKey != null
                ? IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () =>
                        widget.scaffoldKey!.currentState?.openDrawer(),
                  )
                : null,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_LC.purple, _LC.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Ism yoki email bo\'yicha izlash...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: Colors.white70),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Colors.white70),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              )
            : const Text(
                'Talabalar va Hodimlar',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🏠 Xonalar — talabalarning biriktirilganlik holati va xona
        // raqamini bitta marta o'qib, xarita (map) tuzish uchun.
        // ⚠️ Muhim: bu yerda `.where('hostel', isEqualTo: ...)` ISHLATILMAYDI.
        // Ba'zi xona hujjatlarida `hostel` maydoni umuman yo'q yoki bo'sh
        // bo'lishi mumkin (eski yozuvlar) — Firestore'ning qat'iy tenglik
        // so'rovi bunday hujjatlarni butunlay chetlab o'tadi, natijada
        // haqiqatda xonaga biriktirilgan talaba "Biriktirilmagan" deb
        // noto'g'ri ko'rsatiladi. Shuning uchun BARCHA xonalar o'qiladi va
        // `hostel` maydoni `xonalar_list.dart`dagi kabi mijoz tomonida
        // normalizatsiya qilinadi (trim + lowercase, bo'sh bo'lsa 'boys').
        stream: _roomsStream,
        builder: (context, roomsSnap) {
          final roomLabelById = <String, String>{};
          final assignedIds = <String>{};
          if (roomsSnap.hasData) {
            for (final roomDoc in roomsSnap.data!.docs) {
              final roomData = roomDoc.data() as Map<String, dynamic>;
              final rawHostel =
                  (roomData['hostel'] ?? '').toString().trim().toLowerCase();
              final roomHostel = rawHostel.isEmpty ? 'boys' : rawHostel;
              if (roomHostel != widget.hostel) continue;
              final roomNumber = roomData['roomNumber']?.toString() ?? '-';
              final floor = roomData['floor']?.toString() ?? '-';
              final label = "$roomNumber-xona ($floor-qavat)";
              final studentIds =
                  List<String>.from(roomData['studentIds'] ?? const []);
              for (final sid in studentIds) {
                roomLabelById[sid] = label;
                assignedIds.add(sid);
              }
            }
          }
          return _buildBody(context, roomLabelById, assignedIds);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, String> roomLabelById,
      Set<String> assignedIds) {
    return StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _LC.purple),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 56, color: _LC.muted),
                  const SizedBox(height: 12),
                  const Text(
                    "Foydalanuvchilar topilmadi.",
                    style: TextStyle(
                        fontSize: 15,
                        color: _LC.muted,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          final hostelDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final hostel =
                (data["hostel"] ?? "").toString().trim().toLowerCase();

            // ⚠️ Ba'zi (odatda eski, "hostel" maydoni qo'shilishidan oldin
            // yaratilgan) foydalanuvchi hujjatlarida "hostel" maydoni
            // umuman yo'q yoki bo'sh bo'lishi mumkin. Bunday hujjatlar
            // hech qaysi filtrga mos kelmay, "yo'qolib" qolmasligi uchun,
            // ularni standart (birinchi/asosiy) yotoqxona — "boys" — ga
            // tegishli deb hisoblaymiz.
            final normalizedHostel = hostel.isEmpty ? 'boys' : hostel;

            return normalizedHostel == _selectedHostel.toLowerCase();
          }).toList();

          final docs = _filterDocs(hostelDocs, assignedIds);

          Widget listArea;
          if (docs.isEmpty) {
            // ✅ Qidiruv bo'sh bo'lsa (ya'ni foydalanuvchi hech narsa
            // izlamagan, shunchaki tanlangan yotoqxonada hujjat yo'q),
            // '"" bo\'yicha natija topilmadi' kabi chalkashtiruvchi
            // xabar o'rniga aniqroq xabar ko'rsatamiz.
            final hostelLabel =
                _selectedHostel == "boys" ? "O'g'il bolalar" : "Qiz bolalar";
            final message = _searchQuery.isEmpty && _roomFilter == 'all'
                ? "$hostelLabel yotoqxonasida hozircha foydalanuvchi yo'q"
                : _searchQuery.isNotEmpty
                    ? '"$_searchQuery" bo\'yicha natija topilmadi'
                    : "Ushbu filtr bo'yicha talaba topilmadi";
            listArea = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                      _searchQuery.isEmpty
                          ? Icons.people_outline_rounded
                          : Icons.search_off_rounded,
                      size: 56,
                      color: _LC.muted),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                        color: _LC.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          } else {
            listArea = ListView.builder(
              itemCount: docs.length,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final docData = doc.data() as Map<String, dynamic>;
                // Hujjat ichidagi 'id' maydoniga emas, Firestore'ning
                // haqiqiy hujjat ID'siga tayanamiz — aks holda 'id' maydoni
                // yo'q yoki bo'sh bo'lgan (masalan eski) foydalanuvchilarda
                // keyinchalik parol/ma'lumot yangilashda
                // "A document path must be a non-empty string" xatoligi chiqadi.
                docData['id'] = doc.id;
                final currentUser = UserModel.fromJson(docData);
                final roleColor = _getRoleColor(currentUser.role);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _LC.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _LC.faint),
                    boxShadow: [
                      BoxShadow(
                        color: _LC.purple.withOpacity(0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        _openUserManagementDialog(context, currentUser);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child:
                                  Icon(Icons.person_rounded, color: roleColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentUser.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                        color: _LC.ink),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    currentUser.email,
                                    style: const TextStyle(
                                        color: _LC.muted, fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (currentUser.role == UserRole.talaba) ...[
                                    const SizedBox(height: 5),
                                    Builder(builder: (context) {
                                      final roomLabel = roomLabelById[doc.id];
                                      final hasRoom = roomLabel != null;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color:
                                              (hasRoom ? _LC.mint : _LC.coral)
                                                  .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              hasRoom
                                                  ? Icons.meeting_room_rounded
                                                  : Icons.meeting_room_outlined,
                                              size: 12,
                                              color: hasRoom
                                                  ? const Color(0xFF12A181)
                                                  : _LC.coral,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              roomLabel ?? 'Biriktirilmagan',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: hasRoom
                                                    ? const Color(0xFF12A181)
                                                    : _LC.coral,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    currentUser.role
                                        .toString()
                                        .split('.')
                                        .last
                                        .toUpperCase(),
                                    style: TextStyle(
                                        color: roleColor,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                                // ℹ️ Xonaga biriktirish tugmasi olib
                                // tashlandi — bu funksiya endi faqat
                                // "Umumiy ro'yxat" sahifasida mavjud.
                                if (_canDelete) ...[
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _confirmDelete(
                                        context, doc.id, currentUser.fullName),
                                    child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: _LC.coral,
                                        size: 19),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }

          return Column(
            children: [
              _buildRoomFilterChips(),
              Expanded(child: listArea),
            ],
          );
        });
  }

  // 🏠 "Barchasi / Biriktirilgan / Biriktirilmagan" filtr chiplari —
  // faqat talabalar ro'yxatini xona holati bo'yicha filtrlash uchun.
  Widget _buildRoomFilterChips() {
    Widget chip(String label, String value, IconData icon) {
      final selected = _roomFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _roomFilter = value),
          avatar:
              Icon(icon, size: 15, color: selected ? Colors.white : _LC.purple),
          label: Text(label),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _LC.ink,
          ),
          selectedColor: _LC.purple,
          backgroundColor: _LC.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: selected ? _LC.purple : _LC.faint),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Barchasi', 'all', Icons.groups_rounded),
            chip(
                'Xonaga biriktirilgan', 'assigned', Icons.meeting_room_rounded),
            chip('Biriktirilmagan', 'unassigned', Icons.meeting_room_outlined),
          ],
        ),
      ),
    );
  }

  // Rollarga qarab rang ajratish uchun yordamchi funksiya
  Color _getRoleColor(UserRole role) {
    switch (role.toString().split('.').last) {
      case 'admin':
        return _LC.coral;
      case 'mudir':
        return _LC.purple;
      case 'manager':
        return _LC.orange;
      default:
        return _LC.teal;
    }
  }

  // 🏠 Talabaga biriktirilgan xona haqida ma'lumot olish
  // (rooms kolleksiyasidan studentIds massivi orqali qidiriladi)
  Future<String?> _getAssignedRoomInfo(String userId) async {
    try {
      // ⚠️ `.where('hostel', isEqualTo: ...)` qo'shilmaydi — ba'zi eski xona
      // hujjatlarida `hostel` maydoni yo'q/bo'sh bo'lishi mumkin, bu esa
      // Firestore'ning qat'iy tenglik so'rovida ularni chetlab qo'yib,
      // haqiqatda biriktirilgan talabani "biriktirilmagan" deb ko'rsatib
      // yuborishi mumkin edi. `studentIds` global miqyosda unikal bo'lgani
      // uchun faqat shu shart yetarli.
      final snap = await _firestore
          .collection('xonalar')
          .where('studentIds', arrayContains: userId)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final roomData = snap.docs.first.data();
        final roomNumber = roomData['roomNumber']?.toString() ?? '-';
        final floor = roomData['floor']?.toString() ?? '-';
        return "$roomNumber-xona ($floor-qavat)";
      }
      return null; // Xonaga biriktirilmagan
    } catch (e) {
      return "Xatolik: $e";
    }
  }

  // 🌟 Dialogni ochishdan oldin (agar talaba bo'lsa) xona ma'lumotini
  // oldindan yuklab olamiz — shu tufayli dialog ichida "Yuklanmoqda..."
  // holatida osilib qolish muammosi butunlay bartaraf etiladi.
  Future<void> _openUserManagementDialog(
      BuildContext context, UserModel selectedUser) async {
    String? roomInfo;
    if (selectedUser.role == UserRole.talaba) {
      roomInfo = await _getAssignedRoomInfo(selectedUser.id);
    }
    if (!context.mounted) return;
    _showUserManagementDialog(context, selectedUser,
        assignedRoomInfo: roomInfo);
  }

  // 🌟 ADMIN UCHUN TANLANGAN FOYDALANUVCHINI BOSGANDA CHIQUVCHI ASOSIY DIALOG
  void _showUserManagementDialog(BuildContext context, UserModel selectedUser,
      {String? assignedRoomInfo}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.manage_accounts, color: _LC.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedUser.fullName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor:
                      _getRoleColor(selectedUser.role).withOpacity(0.1),
                  child: Icon(Icons.person,
                      size: 40, color: _getRoleColor(selectedUser.role)),
                ),
                const SizedBox(height: 16),

                // 1. FIO Ko'rinishi va tahrirlash
                ListTile(
                  leading: const Icon(Icons.person_outline, color: _LC.purple),
                  title: const Text("FIO"),
                  subtitle: Text(selectedUser.fullName),
                  trailing:
                      const Icon(Icons.edit, size: 18, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _editUserField(context, selectedUser, "FIO", "fullName",
                        selectedUser.fullName);
                  },
                ),

                // 2. Telefon Ko'rinishi va tahrirlash
                ListTile(
                  leading: const Icon(Icons.phone_android, color: _LC.teal),
                  title: const Text("Telefon"),
                  subtitle: Text(selectedUser.phoneNumber ?? "Kiritilmagan"),
                  trailing:
                      const Icon(Icons.edit, size: 18, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _editUserField(context, selectedUser, "Telefon",
                        "phoneNumber", selectedUser.phoneNumber ?? "");
                  },
                ),

                // 3. Email (O'zgartirib bo'lmaydi)
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Colors.grey),
                  title: const Text("Email"),
                  subtitle: Text(selectedUser.email),
                ),

                // 4. Rol ko'rinishi
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings,
                      color: Colors.purple),
                  title: const Text("Tizimdagi roli"),
                  subtitle: Text(selectedUser.role
                      .toString()
                      .split('.')
                      .last
                      .toUpperCase()),
                ),

                // 4.1. Faqat talabalar uchun: biriktirilgan xona ma'lumoti
                if (selectedUser.role == UserRole.talaba)
                  ListTile(
                    leading: const Icon(Icons.meeting_room_outlined,
                        color: _LC.teal),
                    title: const Text("Biriktirilgan xona"),
                    subtitle: Text(
                      assignedRoomInfo ?? "Hali xonaga biriktirilmagan",
                      style: TextStyle(
                        color: assignedRoomInfo != null &&
                                !assignedRoomInfo.startsWith("Xatolik")
                            ? _LC.ink
                            : _LC.coral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Divider(),

                // 🔐 5. ADMIN UCHUN PAROLNI TO'G'RIDAN-TO'G'RI YANGILASH
                ListTile(
                  leading: const Icon(Icons.lock_open, color: _LC.coral),
                  title: const Text(
                    "Parolni majburiy yangilash",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.red),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _adminChangeUserPassword(context, selectedUser);
                  },
                ),

                if (_canDelete) ...[
                  const Divider(),

                  // 🗑️ 6. FOYDALANUVCHINI O'CHIRISH
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: _LC.coral),
                    title: const Text(
                      "Foydalanuvchini o'chirish",
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.red),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _confirmDelete(
                          context, selectedUser.id, selectedUser.fullName);
                    },
                  ),
                ],
              ],
            ),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Yopish"),
            ),
          ],
        );
      },
    );
  }

  // 📝 FOYDALANUVCHI MA'LUMOTLARINI (FIO, TELEFON) TAHRIRLASH DIALOGI
  void _editUserField(BuildContext context, UserModel selectedUser,
      String label, String fieldName, String currentValue) {
    final TextEditingController fieldController =
        TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$label tahrirlash"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: fieldController,
            decoration: InputDecoration(
              labelText: label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? "Maydon bo'sh bo'lishi mumkin emas"
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openUserManagementDialog(context, selectedUser);
            },
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              String newValue = fieldController.text.trim();
              try {
                await _firestore
                    .collection('foydalanuvchilar')
                    .doc(selectedUser.id)
                    .update({fieldName: newValue});

                if (context.mounted) {
                  Navigator.pop(context);
                  final updatedUser = UserModel(
                    id: selectedUser.id,
                    fullName: fieldName == 'fullName'
                        ? newValue
                        : selectedUser.fullName,
                    email: selectedUser.email,
                    role: selectedUser.role,
                    phoneNumber: fieldName == 'phoneNumber'
                        ? newValue
                        : selectedUser.phoneNumber,
                  );
                  _openUserManagementDialog(context, updatedUser);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("$label muvaffaqiyatli o'zgartirildi!"),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Xatolik yuz berdi: $e"),
                      backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text("Saqlash", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🔐 ADMIN UCHUN FOYDALANUVCHI PAROLINI MAJBURIY YANGILASH DIALOGI
  void _adminChangeUserPassword(BuildContext context, UserModel selectedUser) {
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final passwordFormKey = GlobalKey<FormState>();
    // 🔓 Standart holatda KO'RINADIGAN qilib qo'ydik (yashirin emas) —
    // chunki bu SuperAdmin BOSHQA birovning (talabaning) yangi parolini
    // o'rnatyapti, o'zining shaxsiy paroli emas. Yashirin bo'lsa, xato
    // yozilgan harf/raqamni hech kim ko'rmaydi va shu "ko'rinmas xato"
    // aynan "email yoki parol xato" shikoyatining asosiy sababi bo'lgan.
    bool obscurePassword = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: _LC.coral),
                  SizedBox(width: 8),
                  Text("Yangi parol o'rnatish"),
                ],
              ),
              content: Form(
                key: passwordFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${selectedUser.fullName} uchun yangi kirish parolini belgilang.",
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Yangi kirish paroli",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Parol kiriting";
                        }
                        if (value.length < 6) {
                          return "Parol kamida 6 belgidan iborat bo'lsin";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // 🆕 Tasdiqlash maydoni: ikkala maydonga bir xil parol
                    // yozilmasa, formani yuborib bo'lmaydi. Shu orqali
                    // ko'rinmas yozuv xatosi (typo) sababli talaba keyin
                    // "to'g'ri" parol bilan ham kira olmay qolishining oldi
                    // olinadi.
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscurePassword,
                      decoration: const InputDecoration(
                        labelText: "Parolni tasdiqlang",
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12))),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Parolni qayta kiriting";
                        }
                        if (value != newPasswordController.text) {
                          return "Parollar mos kelmayapti";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openUserManagementDialog(context, selectedUser);
                  },
                  child: const Text("Bekor qilish"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!passwordFormKey.currentState!.validate()) return;
                    final String newPassword =
                        newPasswordController.text.trim();
                    try {
                      // ✅ Endi Firestore'ga emas — haqiqiy Firebase
                      // Authentication parolini serverdagi Cloud Function
                      // (Admin SDK) orqali yangilaydi. Shu tufayli
                      // o'zgartirilgan yangi parol bilan darhol kirish
                      // mumkin bo'ladi.
                      await AuthService.adminResetPassword(
                          selectedUser.id, newPassword);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _openUserManagementDialog(context, selectedUser);
                        // 📋 Yangi parolni aniq ko'rsatamiz va nusxalash
                        // imkonini beramiz — shunda talabaga og'zaki yoki
                        // yozib aytilganda xato ketmaydi (aynan shu turdagi
                        // "typo" xatolari "email/parol xato" shikoyatlarining
                        // eng ko'p uchraydigan sababi bo'lган).
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text("Parol yangilandi"),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${selectedUser.fullName} uchun yangi parol:",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          newPassword,
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded,
                                            size: 18),
                                        tooltip: "Nusxalash",
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: newPassword));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text("Parol nusxalandi")),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "Buni talabaga aynan shu ko'rinishda (katta-kichik harflarga e'tibor berib) yetkazing.",
                                  style: TextStyle(
                                      fontSize: 11.5, color: Colors.grey),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Yopish"),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Parol yangilanishida xatolik: $e"),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Yangilash",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
