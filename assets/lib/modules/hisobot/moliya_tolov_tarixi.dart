import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Moliya bo'limi — To'lovlar / to'lov tarixi ────────────────────
// Tasdiqlangan barcha to'lovlarni xronologik tartibda ko'rsatadi,
// qidiruv va jami summa bilan.
//
// 🌍 Ikki manbadan BIRGALIKDA (jonli) o'qiladi, shunda o'g'il bolalar
// va qiz bolalar to'lovlari bitta ro'yxatda ko'rinadi:
//   a) 'tolov_cheklari' (status == 'approved') — talaba o'zi chek
//      yuborib, moliyachi tasdiqlagan to'lovlar (ikkala hostel uchun
//      ham, chunki bu yerga 'hostel' maydoni bilan yoziladi).
//   b) 'girls_payments' (status == 'paid') — qiz bolalar uchun
//      admin/mudira tomonidan QO'LDA kiritilgan to'lovlar (odatda
//      Firebase Auth hisobi yo'q, o'zi chek yubora olmaydigan
//      'girls_students' talabalari uchun). Bu yozuvlarning bir qismi
//      chekni tasdiqlash paytida avtomatik yaratiladi va 'sourceCheckId'
//      maydoniga ega bo'ladi — ular allaqachon (a) manbada bor, shu
//      sabab takrorlanmasligi uchun bu yerda o'tkazib yuboriladi.
class _C {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFa29bfe);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFfd79a8);
  static const orange = Color(0xFFfdcb6e);
  static const white = Color(0xFFFFFFFF);
  static const muted = Color(0x66FFFFFF);
  static const faint = Color(0x0FFFFFFF);
}

/// Ikkala manbadan ('tolov_cheklari' va 'girls_payments') kelgan
/// to'lovlarni bitta shaklga keltiradi.
class _PaymentRow {
  final String studentName;
  final double amount;
  final DateTime? date;
  final String hostel; // 'boys' | 'girls'

  _PaymentRow({
    required this.studentName,
    required this.amount,
    required this.date,
    required this.hostel,
  });

  factory _PaymentRow.fromCheck(Map<String, dynamic> d) {
    DateTime? date;
    final pd = d['paymentDate'] ?? d['uploadedAt'];
    if (pd is Timestamp) date = pd.toDate();
    final rawHostel = (d['hostel'] as String?)?.trim().toLowerCase();
    return _PaymentRow(
      studentName: (d['studentName'] as String?) ?? "Noma'lum talaba",
      amount: (d['amount'] as num? ?? 0).toDouble(),
      date: date,
      hostel: (rawHostel == null || rawHostel.isEmpty) ? 'boys' : rawHostel,
    );
  }

  factory _PaymentRow.fromGirlsPayment(Map<String, dynamic> d) {
    DateTime? date;
    final pd = d['paidAt'] ?? d['createdAt'];
    if (pd is Timestamp) date = pd.toDate();
    return _PaymentRow(
      studentName: (d['studentName'] as String?) ?? "Noma'lum talaba",
      amount: (d['amount'] as num? ?? 0).toDouble(),
      date: date,
      hostel: 'girls',
    );
  }
}

class MoliyaTolovTarixi extends StatefulWidget {
  const MoliyaTolovTarixi({super.key});

  @override
  State<MoliyaTolovTarixi> createState() => _MoliyaTolovTarixiState();
}

class _MoliyaTolovTarixiState extends State<MoliyaTolovTarixi> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _checksStream =>
      FirebaseFirestore.instance
          .collection('tolov_cheklari')
          .where('status', isEqualTo: 'approved')
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _girlsPaymentsStream =>
      FirebaseFirestore.instance
          .collection('girls_payments')
          .where('status', isEqualTo: 'paid')
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bgBase,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: _C.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.faint),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: _C.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: "Talaba ismi bo'yicha qidirish...",
                  hintStyle: TextStyle(color: _C.muted, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: _C.muted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _checksStream,
              builder: (context, checksSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _girlsPaymentsStream,
                  builder: (context, girlsSnap) {
                    if (checksSnap.connectionState == ConnectionState.waiting ||
                        girlsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _C.violet),
                      );
                    }
                    if (checksSnap.hasError || girlsSnap.hasError) {
                      return Center(
                        child: Text(
                            'Xatolik: ${checksSnap.error ?? girlsSnap.error}',
                            style: TextStyle(color: _C.muted)),
                      );
                    }

                    final rows = <_PaymentRow>[
                      for (final doc in checksSnap.data?.docs ?? [])
                        _PaymentRow.fromCheck(doc.data()),
                      for (final doc in girlsSnap.data?.docs ?? [])
                        // ⚠️ 'sourceCheckId' bor yozuvlar chekni tasdiqlash
                        // paytida avtomatik yaratilgan — ular yuqorida
                        // 'tolov_cheklari'dan allaqachon hisoblangan, shu
                        // sabab bu yerda qo'shilsa ikki marta sanaladi.
                        if ((doc.data()['sourceCheckId'] as String?) == null)
                          _PaymentRow.fromGirlsPayment(doc.data()),
                    ];

                    rows.sort((a, b) {
                      if (a.date == null && b.date == null) return 0;
                      if (a.date == null) return 1;
                      if (b.date == null) return -1;
                      return b.date!.compareTo(a.date!);
                    });

                    final filtered = _query.isEmpty
                        ? rows
                        : rows
                            .where((r) =>
                                r.studentName.toLowerCase().contains(_query))
                            .toList();

                    final total =
                        filtered.fold<double>(0, (sum, r) => sum + r.amount);

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_C.teal, _C.mint],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.savings_rounded,
                                      color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text("Jami tasdiqlangan to'lovlar",
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${filtered.length} ta',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Text(
                                    "To'lov tarixi topilmadi",
                                    style: TextStyle(
                                        color: _C.muted, fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, i) {
                                    return _HistoryCard(data: filtered[i]);
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final _PaymentRow data;
  const _HistoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    String dateStr = '—';
    if (data.date != null) {
      final dt = data.date!;
      dateStr =
          '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    }
    final isGirls = data.hostel == 'girls';
    final hostelColor = isGirls ? _C.pink : _C.teal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.faint),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.mint.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: _C.mint, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(data.studentName,
                          style: const TextStyle(
                              color: _C.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hostelColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isGirls ? 'Qiz' : "O'g'il",
                        style: TextStyle(
                            color: hostelColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text("To'lov sanasi: $dateStr",
                    style: TextStyle(color: _C.muted, fontSize: 11)),
              ],
            ),
          ),
          Text("${data.amount.toStringAsFixed(0)} so'm",
              style: const TextStyle(
                  color: _C.mint, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
