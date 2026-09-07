import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/uzbekistan_region.dart';

// ─── Creative LIGHT palette (talabalar ro'yxati bilan bir xil til) ───
class _C {
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

/// 🌍 "Umumiy ro'yxat" — O'g'il va qiz bolalar yotoqxonalaridagi BARCHA
/// talabalarni bitta jadvalda, qidiruv va Viloyat bo'yicha filtr bilan
/// ko'rsatadigan admin bo'limi. `foydalanuvchilar` to'plamidan role=='talaba'
/// bo'lgan hujjatlarni (hostel maydonidan qat'i nazar) o'qiydi, shu bilan
/// birga xona holatini ko'rsatish uchun umumiy `xonalar` to'plamini ham
/// bitta marta o'qib, studentId -> xona xaritasini tuzadi.
class UmumiyRoyxatSahifasi extends StatefulWidget {
  const UmumiyRoyxatSahifasi({super.key});

  @override
  State<UmumiyRoyxatSahifasi> createState() => _UmumiyRoyxatSahifasiState();
}

class _UmumiyRoyxatSahifasiState extends State<UmumiyRoyxatSahifasi> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRegion = 'Barchasi';
  String _selectedHostel = 'Barchasi'; // Barchasi | boys | girls

  // ⚠️ Muhim: bu oqimlar (Stream) shu yerda — build() DAN TASHQARIDA —
  // faqat BIR MARTA yaratiladi. Agar `.snapshots()` build() ichida
  // chaqirilsa, har bir setState (masalan qidiruvga har bir harf
  // yozilganda) yangi Stream obyekti hosil qilib, StreamBuilder buni
  // "boshqa oqim" deb hisoblab, bir lahzaga "yuklanmoqda" holatiga
  // o'tardi — bu esa butun pastki daraxtni (qidiruv maydoni bilan
  // birga) qayta qurib, klaviatura fokusini yo'qotardi (har bir harfdan
  // keyin qidiruv maydonini qayta bosish kerak bo'lgan bug shundan edi).
  late final Stream<QuerySnapshot> _roomsStream =
      _firestore.collection('xonalar').snapshots();
  late final Stream<QuerySnapshot> _studentsStream = _firestore
      .collection('foydalanuvchilar')
      .where('role', isEqualTo: 'talaba')
      .snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _roomLabel(Map<String, dynamic> data, Map<String, String> roomMap) {
    final id = data['id'] as String;
    return roomMap[id] ?? "Biriktirilmagan";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          // Umumiy xonalar to'plami — studentId -> xona xaritasini tuzish uchun.
          stream: _roomsStream,
          builder: (context, roomsSnap) {
            final roomMap = <String, String>{};
            if (roomsSnap.hasData) {
              for (final doc in roomsSnap.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final roomNumber = data['roomNumber']?.toString() ?? '-';
                final floor = data['floor']?.toString() ?? '-';
                final hostel =
                    (data['hostel'] ?? 'boys').toString().toLowerCase();
                final label = "$roomNumber-xona ($floor-qavat"
                    "${hostel == 'girls' ? ', Q' : ', O'})";
                final studentIds =
                    List<String>.from(data['studentIds'] ?? const []);
                for (final sid in studentIds) {
                  roomMap[sid] = label;
                }
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _studentsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _C.purple),
                  );
                }

                final allDocs = snapshot.data?.docs ?? [];
                final allData = allDocs.map((d) {
                  final m = Map<String, dynamic>.from(
                      d.data() as Map<String, dynamic>);
                  m['id'] = d.id;
                  return m;
                }).toList();

                // ── Filtrlash: yotoqxona turi, viloyat, qidiruv ──
                var filtered = allData.where((d) {
                  final hostel =
                      (d['hostel'] ?? 'boys').toString().toLowerCase();
                  if (_selectedHostel != 'Barchasi' &&
                      hostel != _selectedHostel) {
                    return false;
                  }
                  final region = (d['region'] ?? '').toString();
                  if (_selectedRegion != 'Barchasi' &&
                      region != _selectedRegion) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final fullName =
                        (d['fullName'] ?? '').toString().toLowerCase();
                    final phone =
                        (d['phoneNumber'] ?? '').toString().toLowerCase();
                    final jshshir =
                        (d['jshshir'] ?? '').toString().toLowerCase();
                    if (!fullName.contains(q) &&
                        !phone.contains(q) &&
                        !jshshir.contains(q)) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                filtered.sort((a, b) => (a['fullName'] ?? '')
                    .toString()
                    .compareTo((b['fullName'] ?? '').toString()));

                final totalBoys = allData
                    .where((d) =>
                        (d['hostel'] ?? 'boys').toString().toLowerCase() ==
                        'boys')
                    .length;
                final totalGirls = allData
                    .where((d) =>
                        (d['hostel'] ?? 'boys').toString().toLowerCase() ==
                        'girls')
                    .length;

                return Column(
                  children: [
                    _buildHeader(allData.length, totalBoys, totalGirls),
                    _buildFilters(),
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState()
                          // 🎨 Endi ekran qanchalik katta bo'lishidan
                          // qat'i nazar, bir xil kartochka dizayni
                          // ishlatiladi — jadval shakli olib tashlandi.
                          // Keng ekranda kartochkalar bir nechta ustunga
                          // moslashib joylashadi (responsive grid).
                          : _buildCardList(filtered, roomMap),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(int total, int boys, int girls) {
    final chips = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statChip("Jami", total, _C.purple),
        const SizedBox(width: 6),
        _statChip("O'g'il", boys, _C.teal),
        const SizedBox(width: 6),
        _statChip("Qiz", girls, _C.pink),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleRow = Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _C.purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.public_rounded, color: _C.purple),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Umumiy ro'yxat",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.ink),
                    ),
                    Text(
                      "Barcha yotoqxonalar bo'yicha talabalar",
                      style: TextStyle(fontSize: 12.5, color: _C.muted),
                    ),
                  ],
                ),
              ),
            ],
          );

          // 📱 Tor ekranda statistik chiplar sarlavha bilan bitta qatorga
          // sig'may, o'ng chetdan kesilib qolardi ("Qiz" chipi kabi) — endi
          // ular sarlavha ostiga tushadi.
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleRow,
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: chips,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: titleRow),
              chips,
            ],
          );
        },
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 📱 Qidiruv maydoni qat'iy 280px edi — juda tor ekranda bu
          // o'zi ham chetdan chiqib ketardi. Endi mavjud kenglikdan
          // oshmaydi.
          final searchWidth =
              constraints.maxWidth < 280 ? constraints.maxWidth : 280.0;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: searchWidth,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Qidirish: FIO, telefon, JSHSHIR...',
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: _C.muted),
                    filled: true,
                    fillColor: _C.card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _C.faint),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _C.faint),
                    ),
                  ),
                ),
              ),
              _dropdownFilter(
                icon: Icons.map_rounded,
                value: _selectedRegion,
                items: ['Barchasi', ...kRegions],
                onChanged: (v) => setState(() => _selectedRegion = v!),
              ),
              _dropdownFilter(
                icon: Icons.home_work_rounded,
                value: _selectedHostel,
                items: const ['Barchasi', 'boys', 'girls'],
                labelBuilder: (v) => v == 'boys'
                    ? "O'g'il bolalar"
                    : v == 'girls'
                        ? 'Qiz bolalar'
                        : 'Barchasi',
                onChanged: (v) => setState(() => _selectedHostel = v!),
              ),
              if (_selectedRegion != 'Barchasi' ||
                  _selectedHostel != 'Barchasi' ||
                  _searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _selectedRegion = 'Barchasi';
                    _selectedHostel = 'Barchasi';
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Tozalash'),
                  style: TextButton.styleFrom(foregroundColor: _C.coral),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _dropdownFilter({
    required IconData icon,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    String Function(String)? labelBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.faint),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.muted),
          style: const TextStyle(
              color: _C.ink, fontSize: 13, fontWeight: FontWeight.w600),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: _C.purple),
                        const SizedBox(width: 6),
                        Text(labelBuilder != null ? labelBuilder(e) : e),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _searchQuery.isNotEmpty ||
            _selectedRegion != 'Barchasi' ||
            _selectedHostel != 'Barchasi'
        ? "Ushbu filtr bo'yicha talaba topilmadi"
        : "Hozircha talabalar yo'q";
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 56, color: _C.muted),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(
                  color: _C.muted, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // 📱 Tor ekranlar uchun: har bir talaba — o'z ichida barcha ma'lumot
  // (FIO, telefon, JSHSHIR, fakultet/kurs, viloyat, yotoqxona, xona
  // holati) joylashgan alohida kartochka. Gorizontal skroll shart emas —
  // hammasi bir marta ko'rinadi.
  Widget _buildCardList(
      List<Map<String, dynamic>> rows, Map<String, String> roomMap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 🎨 Keng ekranda kartochkalar bitta ustunga cho'zilib
        // ketmasligi uchun, mavjud kenglikka qarab necha ustun
        // sig'ishini hisoblaymiz (har biri kamida ~340px).
        const spacing = 14.0;
        final columns = (constraints.maxWidth / 360).floor().clamp(1, 4);
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: rows.map((d) {
              final hostel = (d['hostel'] ?? 'boys').toString().toLowerCase();
              final hostelColor = hostel == 'girls' ? _C.pink : _C.teal;
              final roomLabel = _roomLabel(d, roomMap);
              final hasRoom = roomLabel != 'Biriktirilmagan';
              final fullName = (d['fullName'] ?? '-').toString();
              final initial =
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

              return SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _C.faint),
                    boxShadow: [
                      BoxShadow(
                        color: _C.purple.withOpacity(0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: hostelColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Text(initial,
                                style: TextStyle(
                                    color: hostelColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.5,
                                        color: _C.ink),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: hostelColor.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text(
                                    hostel == 'girls'
                                        ? 'Qiz bolalar'
                                        : "O'g'il bolalar",
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: hostelColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Xonaga biriktirish',
                            icon: const Icon(Icons.add_home_work_rounded,
                                color: _C.purple, size: 22),
                            onPressed: () => _showRoomPickerDialog(
                              context,
                              fullName: fullName,
                              studentDocId: d['id'] as String,
                              hostel: hostel,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: _C.faint),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _infoChip(Icons.call_rounded,
                              (d['phoneNumber'] ?? '-').toString()),
                          _infoChip(Icons.badge_outlined,
                              (d['jshshir'] ?? '-').toString()),
                          _infoChip(Icons.school_outlined,
                              "${d['faculty'] ?? '-'} / ${d['course'] ?? '-'}-kurs"),
                          _infoChip(Icons.map_outlined,
                              (d['region'] ?? '-').toString()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              (hasRoom ? _C.mint : _C.coral).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasRoom
                                  ? Icons.meeting_room_rounded
                                  : Icons.meeting_room_outlined,
                              size: 14,
                              color:
                                  hasRoom ? const Color(0xFF12A181) : _C.coral,
                            ),
                            const SizedBox(width: 5),
                            Text(roomLabel,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: hasRoom
                                        ? const Color(0xFF12A181)
                                        : _C.coral)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _C.muted),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12, color: _C.ink, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // 🏠 Xona tanlash oynasi — talabaning o'z yotoqxonasidagi (boys/girls)
  // barcha xonalarini ko'rsatadi va tanlangan xonaga darhol biriktiradi.
  // `hostel` bo'yicha qat'iy Firestore so'rovi ishlatilmaydi — ba'zi eski
  // xona hujjatlarida bu maydon yo'q/bo'sh bo'lishi mumkin, shu sabab
  // barcha xonalar o'qib, mijoz tomonida normalizatsiya qilinadi.
  Future<void> _showRoomPickerDialog(
    BuildContext context, {
    required String fullName,
    required String studentDocId,
    required String hostel,
  }) async {
    final roomsSnap = await _firestore.collection('xonalar').get();
    final rooms = roomsSnap.docs.where((d) {
      final data = d.data();
      final rawHostel = (data['hostel'] ?? '').toString().trim().toLowerCase();
      final roomHostel = rawHostel.isEmpty ? 'boys' : rawHostel;
      return roomHostel == hostel;
    }).toList()
      ..sort((a, b) {
        final an = ((a.data())['roomNumber'] as num?)
                ?.toInt() ??
            0;
        final bn = ((b.data())['roomNumber'] as num?)
                ?.toInt() ??
            0;
        return an.compareTo(bn);
      });

    if (!context.mounted) return;

    if (rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Hozircha xonalar mavjud emas"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _C.faint,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.add_home_work_rounded,
                            color: _C.purple),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$fullName — qaysi xonaga biriktirilsin?",
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: _C.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Builder(builder: (context) {
                      // 🟢/🔴 Xonalarni 2 guruhga ajratamiz: bo'sh (joy bor
                      // yoki talaba hozir shu yerda) va band (to'lgan).
                      final available = <QueryDocumentSnapshot>[];
                      final full = <QueryDocumentSnapshot>[];
                      for (final roomDoc in rooms) {
                        final data = roomDoc.data();
                        final capacity =
                            (data['capacity'] as num?)?.toInt() ?? 0;
                        final studentIds =
                            List<String>.from(data['studentIds'] ?? const []);
                        final occupants = studentIds.length;
                        final alreadyHere = studentIds.contains(studentDocId);
                        final isFull = !alreadyHere &&
                            capacity > 0 &&
                            occupants >= capacity;
                        (isFull ? full : available).add(roomDoc);
                      }

                      return ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                        children: [
                          if (available.isNotEmpty) ...[
                            _sectionHeader(
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF12A181),
                              text: "Bo'sh xonalar",
                              count: available.length,
                            ),
                            ...available.map((roomDoc) => _roomTile(
                                  context: context,
                                  sheetContext: sheetContext,
                                  roomDoc: roomDoc,
                                  studentDocId: studentDocId,
                                  hostel: hostel,
                                )),
                          ],
                          if (full.isNotEmpty) ...[
                            _sectionHeader(
                              icon: Icons.lock_rounded,
                              color: _C.coral,
                              text: "Band xonalar",
                              count: full.length,
                            ),
                            ...full.map((roomDoc) => _roomTile(
                                  context: context,
                                  sheetContext: sheetContext,
                                  roomDoc: roomDoc,
                                  studentDocId: studentDocId,
                                  hostel: hostel,
                                )),
                          ],
                        ],
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🏷️ "Bo'sh xonalar" / "Band xonalar" bo'lim sarlavhasi.
  Widget _sectionHeader({
    required IconData icon,
    required Color color,
    required String text,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            "$text ($count)",
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: color.withOpacity(0.25), height: 1)),
        ],
      ),
    );
  }

  // 🧱 Bitta xona kartochkasi (avval ListView.builder ichida edi, endi
  // ikkita bo'lim uchun ham qayta ishlatiladi).
  Widget _roomTile({
    required BuildContext context,
    required BuildContext sheetContext,
    required QueryDocumentSnapshot roomDoc,
    required String studentDocId,
    required String hostel,
  }) {
    final data = roomDoc.data() as Map<String, dynamic>;
    final roomNumber = data['roomNumber']?.toString() ?? '-';
    final floor = data['floor']?.toString() ?? '-';
    final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
    final studentIds = List<String>.from(data['studentIds'] ?? const []);
    final occupants = studentIds.length;
    final alreadyHere = studentIds.contains(studentDocId);
    final isFull = !alreadyHere && capacity > 0 && occupants >= capacity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isFull
              ? null
              : () async {
                  Navigator.pop(sheetContext);
                  await _assignStudentToRoom(
                    context: context,
                    studentDocId: studentDocId,
                    hostel: hostel,
                    roomDoc: roomDoc,
                  );
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (alreadyHere
                            ? _C.mint
                            : isFull
                                ? _C.muted
                                : _C.purple)
                        .withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.meeting_room_rounded,
                    color: alreadyHere
                        ? const Color(0xFF12A181)
                        : isFull
                            ? _C.muted
                            : _C.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$roomNumber-xona",
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: _C.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$floor-qavat · $occupants/$capacity joy",
                        style: TextStyle(
                          fontSize: 12,
                          color: isFull ? _C.coral : _C.muted,
                          fontWeight:
                              isFull ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (alreadyHere)
                  const Text(
                    "Hozir shu yerda",
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF12A181)),
                  )
                else if (isFull)
                  const Text(
                    "To'lgan",
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _C.coral),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: _C.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Talabani tanlangan xonaga biriktiradi. Avval boshqa xonada bo'lsa,
  // o'sha yerdan chiqarib olinadi. Barcha yozuvlar bitta atomik "batch"
  // ichida yuboriladi.
  Future<void> _assignStudentToRoom({
    required BuildContext context,
    required String studentDocId,
    required String hostel,
    required QueryDocumentSnapshot roomDoc,
  }) async {
    try {
      final oldRoomsSnap = await _firestore
          .collection('xonalar')
          .where('studentIds', arrayContains: studentDocId)
          .get();

      final batch = _firestore.batch();

      for (final oldRoomDoc in oldRoomsSnap.docs) {
        if (oldRoomDoc.id == roomDoc.id) continue; // allaqachon shu yerda
        final oldData = oldRoomDoc.data();
        final oldOccupants = (oldData['currentOccupants'] as num?)?.toInt() ??
            List<String>.from(oldData['studentIds'] ?? const []).length;
        batch.update(oldRoomDoc.reference, {
          'studentIds': FieldValue.arrayRemove([studentDocId]),
          'currentOccupants': (oldOccupants - 1).clamp(0, oldOccupants),
        });
      }

      final roomData = roomDoc.data() as Map<String, dynamic>;
      final capacity = (roomData['capacity'] as num?)?.toInt() ?? 0;
      final currentOccupants =
          (roomData['currentOccupants'] as num?)?.toInt() ??
              List<String>.from(roomData['studentIds'] ?? const []).length;
      final alreadyThere = List<String>.from(roomData['studentIds'] ?? const [])
          .contains(studentDocId);
      final newOccupants =
          alreadyThere ? currentOccupants : currentOccupants + 1;

      batch.update(roomDoc.reference, {
        'studentIds': FieldValue.arrayUnion([studentDocId]),
        'currentOccupants': newOccupants,
        'status': capacity > 0 && newOccupants >= capacity
            ? 'occupied'
            : roomData['status'],
      });

      final roomNumber = roomData['roomNumber']?.toString() ?? '';
      batch
          .update(_firestore.collection('foydalanuvchilar').doc(studentDocId), {
        'roomId': roomNumber,
        'hostel': hostel,
      });

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Talaba $roomNumber-xonaga biriktirildi"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Xatolik: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
