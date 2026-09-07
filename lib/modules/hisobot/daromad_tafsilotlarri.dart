import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  String get studentName =>
      (data['studentName'] ?? "Noma'lum talaba") as String;
  String get reviewedBy =>
      (data['reviewedBy'] ?? data['createdBy'] ?? '') as String? ?? '';
  String get note => (data['note'] ?? '') as String? ?? '';
  String get receiptUrl => (data['receiptUrl'] ?? '') as String? ?? '';
  String get hostelLabel =>
      hostel == 'girls' ? 'Qiz bolalar' : "O'g'il bolalar";
}

DateTime _dateOfRaw(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
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
class DaromadTafsilotlari extends StatelessWidget {
  const DaromadTafsilotlari({super.key});

  Stream<QuerySnapshot> get _boysStream => FirebaseFirestore.instance
      .collection('tolovlar')
      .where('hostel', isEqualTo: 'boys')
      .snapshots();

  Stream<QuerySnapshot> get _girlsStream => FirebaseFirestore.instance
      .collection('girls_payments')
      .where('status', isEqualTo: 'paid')
      .snapshots();

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
      // ⚡ Ikkita jonli oqim (o'g'il bolalar + qiz bolalar) BIR VAQTDA
      // tinglanadi — ikkalasidan biri o'zgarsa ham, ro'yxat darhol
      // qayta hisoblanadi.
      body: StreamBuilder<QuerySnapshot>(
        stream: _boysStream,
        builder: (context, boysSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: _girlsStream,
            builder: (context, girlsSnap) {
              if (boysSnap.hasError || girlsSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      "Yuklashda xatolik: ${boysSnap.error ?? girlsSnap.error}",
                      style: const TextStyle(color: _C.muted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!boysSnap.hasData || !girlsSnap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: _C.violet));
              }

              final records = <_PaymentRecord>[
                for (final doc in boysSnap.data!.docs)
                  _PaymentRecord(
                    data: doc.data() as Map<String, dynamic>,
                    hostel: 'boys',
                    date: _dateOfRaw((doc.data() as Map)['date']),
                  ),
                for (final doc in girlsSnap.data!.docs)
                  _PaymentRecord(
                    data: doc.data() as Map<String, dynamic>,
                    hostel: 'girls',
                    date: _dateOfRaw((doc.data() as Map)['paidAt'] ??
                        (doc.data() as Map)['createdAt']),
                  ),
              ];

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
