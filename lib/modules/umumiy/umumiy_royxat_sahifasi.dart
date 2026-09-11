import 'package:flutter/material.dart';
import '../models/uzbekistan_region.dart';
import '../services/api_service.dart';

// в”Ђв”Ђв”Ђ Creative LIGHT palette (talabalar ro'yxati bilan bir xil til) в”Ђв”Ђв”Ђ
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

/// "Umumiy ro'yxat" вЂ” O'g'il va qiz bolalar yotoqxonalaridagi BARCHA
/// talabalarni bitta jadvalda, qidiruv va viloyat bo'yicha filtr bilan
/// ko'rsatadigan admin bo'limi.
///
/// Ma'lumot Laravel API'dan olinadi: talabalar (role=talaba), xonalar
/// va har bir talabaning joriy xona biriktirishi.
class UmumiyRoyxatSahifasi extends StatefulWidget {
  const UmumiyRoyxatSahifasi({super.key});

  @override
  State<UmumiyRoyxatSahifasi> createState() => _UmumiyRoyxatSahifasiState();
}

class _UmumiyRoyxatSahifasiState extends State<UmumiyRoyxatSahifasi> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRegion = 'Barchasi';
  String _selectedHostel = 'Barchasi'; // Barchasi | boys | girls

  // Ma'lumot Laravel API'dan bir marta yuklanadi va saqlanadi.
  //
  // MUHIM: Future initState'da bir marta yaratiladi. Agar u build()
  // ichida yaratilsa, har bir setState (qidiruvga yozilgan har bir
  // harf) yangi so'rov yuborardi va ro'yxat "yuklanmoqda" holatiga
  // qaytib, klaviatura fokusi yo'qolardi.
  late Future<_UmumiyMalumot> _malumot;

  @override
  void initState() {
    super.initState();
    _malumot = _yukla();
  }

  /// Talabalar, xonalar va xona biriktirishlarini birga yuklaydi.
  Future<_UmumiyMalumot> _yukla() async {
    // 1. Barcha talabalar (sahifama-sahifa).
    final talabalar = <Map<String, dynamic>>[];
    int sahifa = 1;
    int oxirgi = 1;
    do {
      final javob = await _api.get(
        'students?role=talaba&per_page=100&detailed=1&page=$sahifa',
      );
      final royxat = javob['data'];
      if (royxat is List) {
        for (final e in royxat) {
          if (e is Map) talabalar.add(Map<String, dynamic>.from(e));
        }
      }
      final meta = javob['meta'];
      oxirgi = meta is Map
          ? ((meta['last_page'] as num?)?.toInt() ?? sahifa)
          : sahifa;
      sahifa++;
    } while (sahifa <= oxirgi && sahifa <= 100);

    // 2. Xonalar.
    final xonalar = <Map<String, dynamic>>[];
    try {
      for (final x in await _api.getRooms()) {
        if (x is Map) xonalar.add(Map<String, dynamic>.from(x));
      }
    } catch (_) {
      // Xonalar yuklanmasa ro'yxat baribir ko'rinadi вЂ”
      // faqat xona ustuni "Biriktirilmagan" bo'ladi.
    }

    // 3. Xona biriktirishlari: studentId -> xona.
    final yorliq = <String, String>{};
    final xonaIdlari = <String, String>{};

    for (final t in talabalar) {
      final b = t['active_room_assignment'] ?? t['activeRoomAssignment'];
      if (b is! Map) continue;
      final sid = t['id']?.toString();
      if (sid == null) continue;
      final xona = b['room'];
      if (xona is Map) {
        final raqam = xona['room_number'] ?? xona['roomNumber'] ?? '-';
        final qavat = xona['floor'] ?? '-';
        final h = (t['hostel'] ?? 'boys').toString().toLowerCase();
        yorliq[sid] =
            "$raqam-xona ($qavat-qavat${h == 'girls' ? ', Q' : ', O'})";
        final rid = xona['id'] ?? b['room_id'];
        if (rid != null) xonaIdlari[sid] = rid.toString();
      }
    }

    return _UmumiyMalumot(
      talabalar: talabalar,
      xonalar: xonalar,
      xonaYorligi: yorliq,
      xonaIdlari: xonaIdlari,
    );
  }

  Future<void> _qaytaYukla() async {
    setState(() {
      _malumot = _yukla();
    });
    await _malumot;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _roomLabel(Map<String, dynamic> data, Map<String, String> roomMap) {
    final id = data['id']?.toString();
    if (id == null) return "Biriktirilmagan";
    return roomMap[id] ?? "Biriktirilmagan";
  }

  /// Ism: Laravel `full_name`, eski Firestore `fullName`.
  String _ism(Map<String, dynamic> d) =>
      (d['full_name'] ?? d['fullName'] ?? '-').toString();

  /// Telefon: Laravel `phone`, eski Firestore `phoneNumber`.
  String _telefon(Map<String, dynamic> d) =>
      (d['phone'] ?? d['phoneNumber'] ?? '-').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: FutureBuilder<_UmumiyMalumot>(
          future: _malumot,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Ma'lumotlarni yuklashda xatolik:\n${snapshot.error}",
                        style: const TextStyle(color: _C.muted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _qaytaYukla,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Qayta urinish'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _C.purple),
              );
            }

            final malumot = snapshot.data;
            final roomMap = malumot?.xonaYorligi ?? const <String, String>{};
            final allData =
                malumot?.talabalar ?? const <Map<String, dynamic>>[];

            // в”Ђв”Ђ Filtrlash: yotoqxona turi, viloyat, qidiruv в”Ђв”Ђ
            final filtered = allData.where((d) {
              final hostel = (d['hostel'] ?? 'boys').toString().toLowerCase();
              if (_selectedHostel != 'Barchasi' && hostel != _selectedHostel) {
                return false;
              }
              final region = (d['region'] ?? '').toString();
              if (_selectedRegion != 'Barchasi' && region != _selectedRegion) {
                return false;
              }
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                final fullName = _ism(d).toLowerCase();
                final phone = _telefon(d).toLowerCase();
                final jshshir = (d['jshshir'] ?? '').toString().toLowerCase();
                if (!fullName.contains(q) &&
                    !phone.contains(q) &&
                    !jshshir.contains(q)) {
                  return false;
                }
              }
              return true;
            }).toList()
              ..sort((a, b) => _ism(a).compareTo(_ism(b)));

            final totalBoys = allData
                .where((d) =>
                    (d['hostel'] ?? 'boys').toString().toLowerCase() == 'boys')
                .length;
            final totalGirls = allData
                .where((d) =>
                    (d['hostel'] ?? 'boys').toString().toLowerCase() == 'girls')
                .length;

            return Column(
              children: [
                _buildHeader(allData.length, totalBoys, totalGirls),
                _buildFilters(),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      // Ekran qanchalik katta bo'lishidan qat'i nazar,
                      // bir xil kartochka dizayni ishlatiladi. Keng
                      // ekranda kartochkalar bir nechta ustunga
                      // moslashib joylashadi (responsive grid).
                      : _buildCardList(filtered, roomMap),
                ),
              ],
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

          // Tor ekranda statistik chiplar sarlavha bilan bitta qatorga
          // sig'may, o'ng chetdan kesilib qolardi вЂ” endi ular sarlavha
          // ostiga tushadi.
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
          // Qidiruv maydoni qat'iy 280px edi вЂ” juda tor ekranda bu
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

  // Har bir talaba вЂ” o'z ichida barcha ma'lumot (FIO, telefon, JSHSHIR,
  // fakultet/kurs, viloyat, yotoqxona, xona holati) joylashgan alohida
  // kartochka. Gorizontal skroll shart emas.
  Widget _buildCardList(
      List<Map<String, dynamic>> rows, Map<String, String> roomMap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keng ekranda kartochkalar bitta ustunga cho'zilib ketmasligi
        // uchun, mavjud kenglikka qarab necha ustun sig'ishini
        // hisoblaymiz (har biri kamida ~360px).
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
              final fullName = _ism(d);
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
                        ],
                      ),
                      const Divider(height: 20, color: _C.faint),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _infoChip(Icons.call_rounded, _telefon(d)),
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

  // Xona tanlash oynasi вЂ” talabaning o'z yotoqxonasidagi (boys/girls)
  // barcha xonalarini ko'rsatadi va tanlangan xonaga darhol biriktiradi.
  Future<void> _showRoomPickerDialog(
    BuildContext context, {
    required String fullName,
    required String studentDocId,
    required String hostel,
  }) async {
    // Xonalar Laravel API'dan olinadi. Bino (hostel) ma'lumoti
    // xonaning o'zida yoki bog'langan hostel obyektida bo'lishi
    // mumkin вЂ” ikkalasini ham tekshiramiz.
    final barchaXonalar = <Map<String, dynamic>>[];
    try {
      for (final x in await _api.getRooms()) {
        if (x is Map) barchaXonalar.add(Map<String, dynamic>.from(x));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Xonalarni yuklashda xatolik: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final rooms = barchaXonalar.where((data) {
      var xom = '';
      final h = data['hostel'];
      if (h is Map) {
        // Bog'langan obyekt вЂ” nomidan aniqlaymiz
        final nom = (h['name'] ?? '').toString().toLowerCase();
        xom = nom.contains('qiz') ? 'girls' : 'boys';
      } else {
        xom = (h ?? '').toString().trim().toLowerCase();
      }
      final roomHostel = xom.isEmpty ? 'boys' : xom;
      return roomHostel == hostel;
    }).toList()
      ..sort((a, b) {
        final an = int.tryParse(
                (a['room_number'] ?? a['roomNumber'] ?? '0').toString()) ??
            0;
        final bn = int.tryParse(
                (b['room_number'] ?? b['roomNumber'] ?? '0').toString()) ??
            0;
        return an.compareTo(bn);
      });

    // Talaba hozir qaysi xonada ekanini bilamiz вЂ” o'sha xona
    // "band" deb belgilanmasin.
    final hozirgiXonaId = (await _malumot).xonaIdlari[studentDocId];

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
                            "$fullName вЂ” qaysi xonaga biriktirilsin?",
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
                      // Xonalarni 2 guruhga ajratamiz: bo'sh (joy bor
                      // yoki talaba hozir shu yerda) va band (to'lgan).
                      //
                      // Laravel'da xonada studentIds massivi yo'q вЂ”
                      // bandlik current_occupants ustunida saqlanadi.
                      final available = <Map<String, dynamic>>[];
                      final full = <Map<String, dynamic>>[];
                      for (final data in rooms) {
                        final capacity =
                            int.tryParse((data['capacity'] ?? 0).toString()) ??
                                0;
                        final occupants = int.tryParse(
                                (data['current_occupants'] ??
                                        data['currentOccupants'] ??
                                        0)
                                    .toString()) ??
                            0;
                        final alreadyHere = hozirgiXonaId != null &&
                            hozirgiXonaId == (data['id'] ?? '').toString();
                        final isFull = !alreadyHere &&
                            capacity > 0 &&
                            occupants >= capacity;
                        (isFull ? full : available).add(data);
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
                                  hozirgiXonaId: hozirgiXonaId,
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
                                  hozirgiXonaId: hozirgiXonaId,
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

  // "Bo'sh xonalar" / "Band xonalar" bo'lim sarlavhasi.
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

  // Bitta xona kartochkasi.
  Widget _roomTile({
    required BuildContext context,
    required BuildContext sheetContext,
    required Map<String, dynamic> roomDoc,
    required String studentDocId,
    required String hostel,
    String? hozirgiXonaId,
  }) {
    final data = roomDoc;
    final roomNumber =
        (data['room_number'] ?? data['roomNumber'] ?? '-').toString();
    final floor = (data['floor'] ?? '-').toString();
    final capacity = int.tryParse((data['capacity'] ?? 0).toString()) ?? 0;
    final occupants = int.tryParse(
            (data['current_occupants'] ?? data['currentOccupants'] ?? 0)
                .toString()) ??
        0;
    final alreadyHere =
        hozirgiXonaId != null && hozirgiXonaId == (data['id'] ?? '').toString();
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
                        "$floor-qavat В· $occupants/$capacity joy",
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

  // Talabani tanlangan xonaga biriktiradi. Avval boshqa xonada bo'lsa,
  // o'sha yerdan chiqarib olinadi. Bularning hammasi Laravel tomonida
  // bitta tranzaksiyada bajariladi.
  Future<void> _assignStudentToRoom({
    required BuildContext context,
    required String studentDocId,
    required String hostel,
    required Map<String, dynamic> roomDoc,
  }) async {
    try {
      final roomId = (roomDoc['id'] ?? '').toString();
      final roomNumber =
          (roomDoc['room_number'] ?? roomDoc['roomNumber'] ?? '').toString();

      if (roomId.isEmpty) {
        throw Exception('Xona ID topilmadi.');
      }

      // Bitta so'rov: eski biriktirishni yopish, yangisini ochish va
      // xona bandligini yangilash. Sig'im tekshiruvi ham server tomonda.
      await _api.assignStudentToRoom(
        studentId: studentDocId,
        roomId: roomId,
      );

      // Ro'yxatni yangilaymiz вЂ” yangi xona darhol ko'rinsin.
      if (mounted) await _qaytaYukla();

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

/// Umumiy ro'yxat ekrani uchun bir marta yuklanadigan ma'lumot to'plami.
///
/// Ilgari ikkita alohida Firestore oqimi (xonalar va foydalanuvchilar)
/// ishlatilardi. Laravel'da ular alohida so'rovlar, shuning uchun
/// natijani bitta obyektga yig'ib, bitta FutureBuilder bilan
/// ko'rsatamiz.
class _UmumiyMalumot {
  /// Barcha talabalar (to'liq ma'lumot bilan).
  final List<Map<String, dynamic>> talabalar;

  /// Barcha xonalar.
  final List<Map<String, dynamic>> xonalar;

  /// studentId -> "101-xona (1-qavat, O)" ko'rinishidagi yorliq.
  final Map<String, String> xonaYorligi;

  /// studentId -> xonaning UUID'si.
  final Map<String, String> xonaIdlari;

  const _UmumiyMalumot({
    required this.talabalar,
    required this.xonalar,
    required this.xonaYorligi,
    required this.xonaIdlari,
  });
}
