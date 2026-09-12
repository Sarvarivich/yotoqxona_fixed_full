import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─── Creative dark palette (dashboard.dart bilan bir xil til) ───
class _C {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
  static const bgCard2 = Color(0xFF16132B);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFa29bfe);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFfd79a8);
  static const orange = Color(0xFFfdcb6e);
  static const coral = Color(0xFFe17055);
  static const white = Color(0xFFFFFFFF);
  static const soft = Color(0xB3FFFFFF);
  static const muted = Color(0x66FFFFFF);
  static const faint = Color(0x0FFFFFFF);
}

// 🧾 Bitta tasdiqlangan to'lovni ifodalaydi — qaysi kolleksiyadan (o'g'il
// bolalar 'tolovlar' yoki qiz bolalar 'girls_payments') kelganidan qat'i
// nazar, bir xil shaklda ishlatish uchun normalizatsiya qilingan.
class _PaymentRecord {
  final Map<String, dynamic> data;
  final String hostel; // 'boys' | 'girls'
  final DateTime date;
  _PaymentRecord(
      {required this.data, required this.hostel, required this.date});

  double get amount {
    final amt = data['amount'];
    if (amt is num) return amt.toDouble();
    if (amt is String) return double.tryParse(amt) ?? 0.0;
    return 0.0;
  }

  /// Bog'langan obyektdan matn o'qish uchun yordamchi.
  /// Laravel `student: { full_name: ... }` qaytaradi, eski Firestore
  /// esa `studentName` deb tekis yozardi.
  static String _ichidan(dynamic obj, String kalit) {
    if (obj is! Map) return '';
    return (obj[kalit] ?? '').toString().trim();
  }

  String get studentName {
    final ism = _ichidan(data['student'], 'full_name');
    if (ism.isNotEmpty) return ism;
    final eski =
        (data['studentName'] ?? data['student_name'] ?? '').toString().trim();
    return eski.isNotEmpty ? eski : "Noma'lum talaba";
  }

  String get reviewedBy {
    final ism = _ichidan(data['reviewer'], 'full_name');
    if (ism.isNotEmpty) return ism;
    // Laravel'da reviewed_by UUID bo'lgani uchun uni ko'rsatmaymiz.
    return (data['reviewedBy'] ?? data['createdBy'] ?? '').toString().trim();
  }

  String get note => (data['note'] ?? '').toString().trim();

  String get receiptUrl =>
      (data['receipt_url'] ?? data['receiptUrl'] ?? data['receipt_path'] ?? '')
          .toString()
          .trim();
  String get hostelLabel =>
      hostel == 'girls' ? 'Qiz bolalar' : "O'g'il bolalar";
}

DateTime _dateOfRaw(dynamic raw) {
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw) ?? DateTime(2000);
  return DateTime(2000);
}

/// 💰 Faqat SuperAdmin uchun: "Jami daromad" raqami ORQASIDA turgan
/// har bir alohida tasdiqlangan to'lovni (chekni) ko'rsatadi.
///
/// 🌍 O'g'il bolalar ('tolovlar' to'plami) va qiz bolalar ('girls_payments'
/// to'plami) to'lovlari BIRGALIKDA, real vaqtda (jonli) yig'iladi va bitta
/// umumiy — sana bo'yicha tartiblangan — ro'yxatda ko'rsatiladi. Har bir
/// yozuv qaysi yotoqxonaga tegishli ekani (O'g'il/Qiz) alohida belgi bilan
/// ko'rinadi.
///
/// Dashboarddagi "Jami daromad" kartasi va "Daromad hisoboti" bo'limi shu
/// ekranga olib boradi. Ro'yxatdagi har bir yozuvni bosganda, o'sha
/// yozuvning to'liq cheki (rasm bilan) ochiladi va u yerda "Oldingi" /
/// "Keyingi" tugmalari orqali ro'yxatdagi BOSHQA (ham o'g'il, ham qiz
/// bolalar) tasdiqlangan cheklariga ham sirg'alib o'tish mumkin.
class DaromadTafsilotlari extends StatefulWidget {
  const DaromadTafsilotlari({super.key});

  @override
  State<DaromadTafsilotlari> createState() => _DaromadTafsilotlariState();
}

class _DaromadTafsilotlariState extends State<DaromadTafsilotlari> {
  // MUHIM: Future initState'da bir marta yaratiladi. build() ichida
  // yaratilsa, har bir qayta chizishda yangi so'rov ketardi.
  late Future<List<_PaymentRecord>> _yozuvlar;

  @override
  void initState() {
    super.initState();
    _yozuvlar = _yukla();
  }

  /// Tasdiqlangan to'lovlarni yuklaydi.
  ///
  /// Ilgari ikkita Firestore oqimi bor edi: 'tolovlar' (o'g'il
  /// bolalar) va 'girls_payments' (qizlar). Laravel'da qizlar uchun
  /// alohida jadval yo'q - hamma to'lov `payments` da, bino esa
  /// xonaning hostel_type maydonida ko'rsatiladi.
  Future<List<_PaymentRecord>> _yukla() async {
    final javob = await ApiService().get('payments');

    final xom = javob['data'];
    if (xom is! List) return <_PaymentRecord>[];

    final natija = <_PaymentRecord>[];

    for (final e in xom) {
      if (e is! Map) continue;
      final d = Map<String, dynamic>.from(e);

      // Faqat tasdiqlangan to'lovlar daromadga kiradi.
      final holat = (d['status'] ?? '').toString().toLowerCase();
      if (holat != 'approved' && holat != 'paid') continue;

      // Bino: xonaning turi, bo'lmasa talabaning binosi.
      var bino = 'boys';
      final xona = d['room'];
      if (xona is Map &&
          (xona['hostel_type'] ?? '').toString().toLowerCase() == 'girls') {
        bino = 'girls';
      } else {
        final talaba = d['student'];
        if (talaba is Map &&
            (talaba['hostel'] ?? '').toString().toLowerCase() == 'girls') {
          bino = 'girls';
        }
      }

      natija.add(_PaymentRecord(
        data: d,
        hostel: bino,
        date: _dateOfRaw(d['paid_at'] ?? d['created_at']),
      ));
    }

    return natija;
  }

  Future<void> _qaytaYukla() async {
    if (!mounted) return;
    setState(() {
      _yozuvlar = _yukla();
    });
    await _yozuvlar;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgBase,
      appBar: AppBar(
        backgroundColor: _C.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.white),
        title: const Text(
          "Daromad tafsilotlari — Barcha talabalar",
          style: TextStyle(
              color: _C.white, fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      body: FutureBuilder<List<_PaymentRecord>>(
        future: _yozuvlar,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Yuklashda xatolik: ${snapshot.error}",
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

          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _C.violet));
          }

          final records = List<_PaymentRecord>.from(snapshot.data!);

              // 🗓️ Har doim sana bo'yicha (eng yangisidan eng eskisiga)
              // tartiblab qo'yamiz — shunda "Oldingi/Keyingi" navigatsiyasi
              // ma'noli bo'ladi.
              records.sort((a, b) => b.date.compareTo(a.date));

              if (records.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 56, color: _C.muted),
                      SizedBox(height: 12),
                      Text(
                        "Hali tasdiqlangan chek yo'q",
                        style: TextStyle(color: _C.muted, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              final total = records.fold<double>(0, (sum, r) => sum + r.amount);
              final boysCount = records.where((r) => r.hostel == 'boys').length;
              final girlsCount =
                  records.where((r) => r.hostel == 'girls').length;

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_C.purple, _C.violet],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.payments_rounded,
                                color: Colors.white, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${records.length} ta tasdiqlangan chek",
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11.5),
                                  ),
                                  Text(
                                    "${total.toStringAsFixed(0)} so'm",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _hostelChip(
                                Icons.person_rounded, "O'g'il: $boysCount"),
                            const SizedBox(width: 8),
                            _hostelChip(
                                Icons.person_rounded, "Qiz: $girlsCount"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: records.length,
                      itemBuilder: (context, i) {
                        return _IncomeEntryCard(
                          record: records[i],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _ReceiptPager(
                                  records: records,
                                  initialIndex: i,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
        },
      ),
    );
  }

  Widget _hostelChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _IncomeEntryCard extends StatelessWidget {
  final _PaymentRecord record;
  final VoidCallback onTap;

  const _IncomeEntryCard({required this.record, required this.onTap});

  String _dateStr() {
    final dt = record.date;
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final studentName = record.studentName;
    final amountStr = '${record.amount.toStringAsFixed(0)} so\'m';
    final reviewedBy = record.reviewedBy;
    final hasReceipt = record.receiptUrl.isNotEmpty;
    final isGirls = record.hostel == 'girls';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.faint),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_C.teal, _C.mint],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        studentName.isNotEmpty
                            ? studentName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: _C.bgBase,
                            fontWeight: FontWeight.w800,
                            fontSize: 16),
                      ),
                    ),
                    // 🚻 Qaysi yotoqxonaga tegishli ekanini bildiruvchi
                    // kichik belgi (o'g'il/qiz).
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isGirls ? _C.pink : _C.violet,
                          shape: BoxShape.circle,
                          border: Border.all(color: _C.bgCard, width: 2),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                          style: const TextStyle(
                              color: _C.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        "${_dateStr()}${reviewedBy.isNotEmpty ? ' · $reviewedBy tasdiqlagan' : ''}",
                        style: const TextStyle(color: _C.muted, fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountStr,
                      style: const TextStyle(
                          color: _C.mint,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5),
                    ),
                    const SizedBox(height: 3),
                    Icon(
                      hasReceipt
                          ? Icons.receipt_long_rounded
                          : Icons.receipt_long_outlined,
                      size: 15,
                      color: hasReceipt ? _C.teal : _C.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 🔄 Bitta tasdiqlangan chekni to'liq holda ko'rsatadi va "Oldingi" /
/// "Keyingi" tugmalari (yoki chapga/o'ngga sirg'alish) orqali ro'yxatdagi
/// qo'shni tasdiqlangan cheklarga — o'g'il yoki qiz bolalar farqisiz —
/// o'tish imkonini beradi.
class _ReceiptPager extends StatefulWidget {
  final List<_PaymentRecord> records;
  final int initialIndex;

  const _ReceiptPager({required this.records, required this.initialIndex});

  @override
  State<_ReceiptPager> createState() => _ReceiptPagerState();
}

class _ReceiptPagerState extends State<_ReceiptPager> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _current + delta;
    if (next < 0 || next >= widget.records.length) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  String _dateStr(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgBase,
      appBar: AppBar(
        backgroundColor: _C.bgCard,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.white),
        title: Text(
          "Tasdiqlangan chek — ${_current + 1}/${widget.records.length}",
          style: const TextStyle(
              color: _C.white, fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.records.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) {
          final r = widget.records[i];
          final amountStr = '${r.amount.toStringAsFixed(0)} so\'m';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.receiptUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      r.receiptUrl,
                      width: double.infinity,
                      height: 320,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _C.bgCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.broken_image,
                            color: _C.muted, size: 40),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 200,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _C.bgCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: _C.muted, size: 40),
                  ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _C.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.faint),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(r.studentName,
                                style: const TextStyle(
                                    color: _C.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: (r.hostel == 'girls' ? _C.pink : _C.violet)
                                  .withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              r.hostelLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: r.hostel == 'girls'
                                      ? _C.pink
                                      : _C.violet),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _row('Summasi', amountStr, _C.mint),
                      _row('Sana', _dateStr(r.date), _C.white),
                      if (r.reviewedBy.isNotEmpty)
                        _row('Tasdiqlagan', r.reviewedBy, _C.violet),
                      if (r.note.isNotEmpty) _row('Izoh', r.note, _C.white),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.white,
                    side: const BorderSide(color: _C.faint),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _current > 0 ? () => _go(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('Oldingi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.purple,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _current < widget.records.length - 1
                      ? () => _go(1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded,
                      color: Colors.white),
                  label: const Text('Keyingi',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(color: _C.muted, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
