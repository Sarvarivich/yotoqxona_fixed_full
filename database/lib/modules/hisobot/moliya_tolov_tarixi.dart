import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Moliya bo'limi — To'lovlar / to'lov tarixi ────────────────────
// Tasdiqlangan barcha to'lovlarni (payment_checks, status == approved)
// xronologik tartibda ko'rsatadi, qidiruv va jami summa bilan.

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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tolov_cheklari')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _C.violet),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Xatolik: ${snap.error}',
                        style: TextStyle(color: _C.muted)),
                  );
                }
                var docs = snap.data?.docs ?? [];
                docs = [...docs]..sort((a, b) {
                    final da = a.data() as Map<String, dynamic>;
                    final db = b.data() as Map<String, dynamic>;
                    final ta = da['uploadedAt'];
                    final tb = db['uploadedAt'];
                    if (ta is Timestamp && tb is Timestamp) {
                      return tb.compareTo(ta); // descending
                    }
                    if (ta is Timestamp) return -1;
                    if (tb is Timestamp) return 1;
                    return 0;
                  });
                if (_query.isNotEmpty) {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final name =
                        (d['studentName'] ?? '').toString().toLowerCase();
                    return name.contains(_query);
                  }).toList();
                }

                final total = docs.fold<double>(
                  0,
                  (sum, doc) =>
                      sum +
                      ((doc.data() as Map<String, dynamic>)['amount'] as num? ??
                          0),
                );

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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                              child: Text('${docs.length} ta',
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
                      child: docs.isEmpty
                          ? Center(
                              child: Text(
                                "To'lov tarixi topilmadi",
                                style: TextStyle(color: _C.muted, fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: docs.length,
                              itemBuilder: (context, i) {
                                final d =
                                    docs[i].data() as Map<String, dynamic>;
                                return _HistoryCard(data: d);
                              },
                            ),
                    ),
                  ],
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
  final Map<String, dynamic> data;
  const _HistoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final studentName = (data['studentName'] ?? "Noma'lum talaba") as String;
    final amount = (data['amount'] as num? ?? 0).toDouble();

    String dateStr = '—';
    final pd = data['paymentDate'];
    if (pd != null) {
      try {
        final dt = (pd as Timestamp).toDate();
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
      } catch (_) {}
    }

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
                Text(studentName,
                    style: const TextStyle(
                        color: _C.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text("To'lov sanasi: $dateStr",
                    style: TextStyle(color: _C.muted, fontSize: 11)),
              ],
            ),
          ),
          Text("${amount.toStringAsFixed(0)} so'm",
              style: const TextStyle(
                  color: _C.mint, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
