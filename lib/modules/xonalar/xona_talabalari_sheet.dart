import 'package:flutter/material.dart';

import '../services/api_service.dart';

// ─── Ranglar (xonalar_list.dart bilan bir xil til) ───
class _C {
  static const bg = Color(0xFFF3F1FB);
  static const card = Colors.white;
  static const purple = Color(0xFF6C5CE7);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFFD79A8);
  static const coral = Color(0xFFE17055);
  static const ink = Color(0xFF2D2A4A);
  static const muted = Color(0xFF8B86A8);
  static const faint = Color(0xFFE9E5FA);
}

/// Xonaga biriktirilgan talabalar ro'yxati.
///
/// Ko'rsatadi:
///   - xonadagi talabalar (ism, kurs, fakultet)
///   - har biri yonida "chiqarish" tugmasi
///   - xonada joy bo'lsa "Talaba qo'shish" tugmasi
///
/// Sig'im tekshiruvi ikki joyda: bu yerda tugma yashiriladi, backend
/// esa `RoomAssignmentController` da qayta tekshiradi. Ikki mudir bir
/// vaqtda oxirgi joyni band qilsa, ikkinchisi server xatosini oladi.
class XonaTalabalariSheet extends StatefulWidget {
  final String roomId;
  final String roomNumber;
  final int capacity;

  /// Xona qaysi binoda: 'boys' yoki 'girls'.
  /// Talaba tanlashda faqat shu binodagilar ko'rsatiladi.
  final String hostel;

  /// Biriktirish va chiqarish huquqi (mudir / admin / superAdmin).
  final bool canEdit;

  const XonaTalabalariSheet({
    super.key,
    required this.roomId,
    required this.roomNumber,
    required this.capacity,
    required this.hostel,
    this.canEdit = true,
  });

  @override
  State<XonaTalabalariSheet> createState() => _XonaTalabalariSheetState();
}

class _XonaTalabalariSheetState extends State<XonaTalabalariSheet> {
  final _api = ApiService();

  bool _yuklanmoqda = true;
  String? _xato;

  /// Xonadagi talabalar.
  List<Map<String, dynamic>> _talabalar = [];

  /// studentId -> biriktirish (room_students) yozuvining ID'si.
  /// Chiqarish uchun kerak.
  final Map<String, String> _biriktirishIdlari = {};

  @override
  void initState() {
    super.initState();
    _yukla();
  }

  Future<void> _yukla() async {
    if (!mounted) return;
    setState(() {
      _yuklanmoqda = true;
      _xato = null;
    });

    try {
      // 1. Xona va undagi talabalar.
      final javob = await _api.get('rooms/${widget.roomId}');
      final xona = javob['data'];

      final talabalar = <Map<String, dynamic>>[];
      if (xona is Map) {
        final royxat = xona['active_students'];
        if (royxat is List) {
          for (final e in royxat) {
            if (e is Map) talabalar.add(Map<String, dynamic>.from(e));
          }
        }
      }

      // 2. Biriktirish ID'lari — chiqarish tugmasi uchun.
      _biriktirishIdlari.clear();
      try {
        final biriktirishlar = await _api.getRoomAssignments();
        for (final b in biriktirishlar) {
          if (b is! Map) continue;
          final d = Map<String, dynamic>.from(b);
          final roomId = (d['room_id'] ?? '').toString();
          if (roomId != widget.roomId) continue;
          final sid = (d['student_id'] ?? '').toString();
          final aid = (d['id'] ?? '').toString();
          if (sid.isNotEmpty && aid.isNotEmpty) {
            _biriktirishIdlari[sid] = aid;
          }
        }
      } catch (_) {
        // Biriktirish ID'lari yuklanmasa ro'yxat baribir ko'rinadi,
        // faqat "chiqarish" tugmasi ishlamaydi.
      }

      if (!mounted) return;
      setState(() {
        _talabalar = talabalar;
        _yuklanmoqda = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _xato = e.toString();
        _yuklanmoqda = false;
      });
    }
  }

  int get _bandJoylar => _talabalar.length;
  int get _boshJoylar => (widget.capacity - _bandJoylar).clamp(0, 999);
  bool get _joyBor => _boshJoylar > 0;

  // ===================================================================
  // TALABA QO'SHISH
  // ===================================================================

  Future<void> _talabaQoshish() async {
    // Xonasiz talabalarni yuklaymiz — faqat shu binodagilarni.
    List<Map<String, dynamic>> nomzodlar;
    try {
      nomzodlar = await _xonasizTalabalar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Talabalarni yuklashda xatolik: $e"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;

    if (nomzodlar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Xonaga biriktirilmagan talaba topilmadi"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final tanlangan = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TalabaTanlashSheet(
        nomzodlar: nomzodlar,
        roomNumber: widget.roomNumber,
        boshJoylar: _boshJoylar,
      ),
    );

    if (tanlangan == null || !mounted) return;

    final sid = (tanlangan['id'] ?? '').toString();
    final ism = (tanlangan['full_name'] ?? tanlangan['fullName'] ?? '')
        .toString();
    if (sid.isEmpty) return;

    try {
      await _api.assignStudentToRoom(studentId: sid, roomId: widget.roomId);
      if (!mounted) return;

      await _yukla();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$ism ${widget.roomNumber}-xonaga biriktirildi"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Biriktirib bo'lmadi: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Xonaga biriktirilmagan talabalar (shu binodagilar).
  Future<List<Map<String, dynamic>>> _xonasizTalabalar() async {
    final natija = <Map<String, dynamic>>[];
    int sahifa = 1;
    int oxirgi = 1;

    do {
      final javob = await _api.get(
        'students?role=talaba&hostel=${widget.hostel}'
        '&per_page=100&page=$sahifa',
      );

      final royxat = javob['data'];
      if (royxat is List) {
        for (final e in royxat) {
          if (e is! Map) continue;
          final d = Map<String, dynamic>.from(e);

          // Xonasi borlarni o'tkazib yuboramiz.
          final b = d['active_room_assignment'] ?? d['activeRoomAssignment'];
          if (b is Map && (b['room_id'] ?? b['room']) != null) continue;

          natija.add(d);
        }
      }

      final meta = javob['meta'];
      oxirgi = meta is Map
          ? ((meta['last_page'] as num?)?.toInt() ?? sahifa)
          : sahifa;
      sahifa++;
    } while (sahifa <= oxirgi && sahifa <= 100);

    natija.sort((a, b) => (a['full_name'] ?? '')
        .toString()
        .compareTo((b['full_name'] ?? '').toString()));

    return natija;
  }

  // ===================================================================
  // TALABANI CHIQARISH
  // ===================================================================

  Future<void> _talabaniChiqarish(Map<String, dynamic> talaba) async {
    final sid = (talaba['id'] ?? '').toString();
    final ism = (talaba['full_name'] ?? talaba['fullName'] ?? '').toString();
    final aid = _biriktirishIdlari[sid];

    if (aid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Biriktirish yozuvi topilmadi"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final tasdiq = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Xonadan chiqarish"),
        content: Text(
          "$ism ${widget.roomNumber}-xonadan chiqarilsinmi?\n\n"
          "Talaba tizimda qoladi, faqat xona biriktirishi bekor qilinadi.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Bekor qilish"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _C.coral),
            child: const Text("Chiqarish"),
          ),
        ],
      ),
    );

    if (tasdiq != true || !mounted) return;

    try {
      await _api.unassignRoomStudent(aid);
      if (!mounted) return;

      await _yukla();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$ism xonadan chiqarildi"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Chiqarib bo'lmadi: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===================================================================
  // KO'RINISH
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
              _sarlavha(),
              const Divider(height: 1, color: _C.faint),
              Expanded(child: _tana(scrollController)),
              if (widget.canEdit) _pastkiTugma(),
            ],
          ),
        );
      },
    );
  }

  Widget _sarlavha() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _C.purple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              widget.roomNumber,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _C.purple,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${widget.roomNumber}-xona talabalari",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _yuklanmoqda
                      ? "Yuklanmoqda..."
                      : "$_bandJoylar/${widget.capacity} joy band"
                          "${_joyBor ? ' · $_boshJoylar bo\'sh' : ' · to\'lgan'}",
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _joyBor ? _C.muted : _C.coral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Yangilash',
            onPressed: _yuklanmoqda ? null : _yukla,
            icon: const Icon(Icons.refresh_rounded, color: _C.muted),
          ),
        ],
      ),
    );
  }

  Widget _tana(ScrollController scrollController) {
    if (_yuklanmoqda) {
      return const Center(
        child: CircularProgressIndicator(color: _C.purple),
      );
    }

    if (_xato != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                "Yuklashda xatolik:\n$_xato",
                textAlign: TextAlign.center,
                style: const TextStyle(color: _C.muted),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _yukla,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Qayta urinish"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_talabalar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 54, color: _C.muted),
            const SizedBox(height: 12),
            const Text(
              "Bu xonada hali talaba yo'q",
              style: TextStyle(
                color: _C.muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      itemCount: _talabalar.length,
      itemBuilder: (context, i) => _talabaKartasi(_talabalar[i], i + 1),
    );
  }

  Widget _talabaKartasi(Map<String, dynamic> t, int tartib) {
    final ism = (t['full_name'] ?? t['fullName'] ?? '—').toString();
    final kurs = t['course'];
    final fakultet = (t['faculty'] ?? '').toString();
    final telefon = (t['phone'] ?? t['phoneNumber'] ?? '').toString();
    final harf = ism.isNotEmpty ? ism[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.faint),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _C.teal.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              harf,
              style: const TextStyle(
                color: _C.teal,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$tartib. $ism",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _C.ink,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (fakultet.isNotEmpty) fakultet,
                    if (kurs != null) "$kurs-kurs",
                    if (telefon.isNotEmpty) telefon,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: _C.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (widget.canEdit)
            IconButton(
              tooltip: 'Xonadan chiqarish',
              onPressed: () => _talabaniChiqarish(t),
              icon: const Icon(
                Icons.person_remove_rounded,
                color: _C.coral,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pastkiTugma() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            // Xona to'lgan bo'lsa tugma o'chiriladi. Backend ham
            // qayta tekshiradi — ikki mudir bir vaqtda bosganda
            // ikkinchisi server xatosini oladi.
            onPressed: (_yuklanmoqda || !_joyBor) ? null : _talabaQoshish,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(
              _joyBor
                  ? "Talaba qo'shish ($_boshJoylar bo'sh joy)"
                  : "Xona to'lgan",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _joyBor ? _C.purple : _C.muted,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _C.muted.withOpacity(0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// TALABA TANLASH OYNASI
// =====================================================================

class _TalabaTanlashSheet extends StatefulWidget {
  final List<Map<String, dynamic>> nomzodlar;
  final String roomNumber;
  final int boshJoylar;

  const _TalabaTanlashSheet({
    required this.nomzodlar,
    required this.roomNumber,
    required this.boshJoylar,
  });

  @override
  State<_TalabaTanlashSheet> createState() => _TalabaTanlashSheetState();
}

class _TalabaTanlashSheetState extends State<_TalabaTanlashSheet> {
  final _qidiruvController = TextEditingController();
  String _qidiruv = '';

  @override
  void dispose() {
    _qidiruvController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _royxat {
    if (_qidiruv.trim().isEmpty) return widget.nomzodlar;
    final q = _qidiruv.trim().toLowerCase();
    return widget.nomzodlar.where((t) {
      final ism = (t['full_name'] ?? '').toString().toLowerCase();
      final email = (t['email'] ?? '').toString().toLowerCase();
      final guruh = (t['group_name'] ?? '').toString().toLowerCase();
      return ism.contains(q) || email.contains(q) || guruh.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final royxat = _royxat;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded,
                        color: _C.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${widget.roomNumber}-xonaga kim biriktirilsin?",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _C.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${widget.nomzodlar.length} ta xonasiz talaba · "
                            "${widget.boshJoylar} bo'sh joy",
                            style: const TextStyle(
                              fontSize: 12,
                              color: _C.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: TextField(
                  controller: _qidiruvController,
                  onChanged: (v) => setState(() => _qidiruv = v),
                  decoration: InputDecoration(
                    hintText: 'Ism, email yoki guruh bo\'yicha qidirish...',
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: _C.muted),
                    filled: true,
                    fillColor: _C.card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.faint),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _C.faint),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: royxat.isEmpty
                    ? const Center(
                        child: Text(
                          "Natija topilmadi",
                          style: TextStyle(
                            color: _C.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                        itemCount: royxat.length,
                        itemBuilder: (context, i) {
                          final t = royxat[i];
                          final ism =
                              (t['full_name'] ?? '—').toString();
                          final kurs = t['course'];
                          final fakultet = (t['faculty'] ?? '').toString();
                          final guruh = (t['group_name'] ?? '').toString();
                          final harf =
                              ism.isNotEmpty ? ism[0].toUpperCase() : '?';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Material(
                              color: _C.card,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.pop(context, t),
                                child: Padding(
                                  padding: const EdgeInsets.all(13),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: _C.purple.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          harf,
                                          style: const TextStyle(
                                            color: _C.purple,
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
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: _C.ink,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              [
                                                if (fakultet.isNotEmpty)
                                                  fakultet,
                                                if (kurs != null) "$kurs-kurs",
                                                if (guruh.isNotEmpty) guruh,
                                              ].join(' · '),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: _C.muted,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: _C.muted,
                                      ),
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
