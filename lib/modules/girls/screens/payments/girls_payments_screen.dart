import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/tolov_cheklari_screen.dart';
import '../../../models/user_model.dart';
import '../../providers/girls_payment_provider.dart';
import '../../services/girls_payment_model.dart';
import 'add_girls_payment_screen.dart';

// ─── Creative LIGHT "moliya" palette — qizlar bo'limi to'lovlari uchun
// mayin lavanda fon + gullab-yashnayotgan gradient hero va "chek"
// uslubidagi kartalar.
class _LC {
  static const bg = Color(0xFFF6F1FB);
  static const card = Colors.white;
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFA29BFE);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFFD79A8);
  static const rose = Color(0xFFE84393);
  static const orange = Color(0xFFFDCB6E);
  static const coral = Color(0xFFE17055);
  static const red = Color(0xFFE74C3C);
  static const ink = Color(0xFF2D2A4A);
  static const muted = Color(0xFF8B86A8);
  static const faint = Color(0xFFEDE8FA);
}

// ─── GirlsPaymentsScreen: Qizlar yotoqxonasi to'lovlari — yig'ilish
// foizi doiraviy indikatori bo'lgan moliyaviy hero va "chek" uslubidagi
// to'lov kartalari bilan.
class GirlsPaymentsScreen extends StatefulWidget {
  final UserModel? currentUser;
  const GirlsPaymentsScreen({super.key, this.currentUser});

  @override
  State<GirlsPaymentsScreen> createState() => _GirlsPaymentsScreenState();
}

class _GirlsPaymentsScreenState extends State<GirlsPaymentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  GirlsPaymentStatus? _filter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(GirlsPaymentStatus s) {
    switch (s) {
      case GirlsPaymentStatus.paid:
        return _LC.teal;
      case GirlsPaymentStatus.pending:
        return _LC.orange;
      case GirlsPaymentStatus.overdue:
        return _LC.red;
    }
  }

  IconData _statusIcon(GirlsPaymentStatus s) {
    switch (s) {
      case GirlsPaymentStatus.paid:
        return Icons.check_circle_rounded;
      case GirlsPaymentStatus.pending:
        return Icons.hourglass_bottom_rounded;
      case GirlsPaymentStatus.overdue:
        return Icons.error_rounded;
    }
  }

  IconData _methodIcon(GirlsPaymentMethod m) {
    switch (m) {
      case GirlsPaymentMethod.naqd:
        return Icons.payments_rounded;
      case GirlsPaymentMethod.karta:
        return Icons.credit_card_rounded;
      case GirlsPaymentMethod.otkazma:
        return Icons.account_balance_rounded;
    }
  }

  bool _matchesSearch(GirlsPaymentModel p) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.trim().toLowerCase();
    return p.studentName.toLowerCase().contains(q) ||
        p.month.toLowerCase().contains(q);
  }

  String _formatMoney(num value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GirlsPaymentProvider>();

    return Scaffold(
      backgroundColor: _LC.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _LC.rose,
        elevation: 4,
        icon: const Icon(Icons.add_card_rounded, color: Colors.white),
        label: const Text("To'lov qo'shish",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AddGirlsPaymentScreen(currentUser: widget.currentUser),
          ),
        ),
      ),
      body: StreamBuilder<List<GirlsPaymentModel>>(
        stream: provider.payments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _LC.purple));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Xatolik yuz berdi: ${snapshot.error}"));
          }

          final all = snapshot.data ?? [];
          var items = all;
          if (_filter != null) {
            items = items.where((p) => p.status == _filter).toList();
          }
          items = items.where(_matchesSearch).toList();

          final totalAmount = all.fold<double>(0, (sum, p) => sum + p.amount);
          final paidAmount = all
              .where((p) => p.status == GirlsPaymentStatus.paid)
              .fold<double>(0, (sum, p) => sum + p.amount);
          final pendingCount =
              all.where((p) => p.status == GirlsPaymentStatus.pending).length;
          final overdueCount =
              all.where((p) => p.status == GirlsPaymentStatus.overdue).length;
          final collectionRate =
              totalAmount > 0 ? paidAmount / totalAmount : 0.0;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _FinanceHero(
                  totalAmount: totalAmount,
                  paidAmount: paidAmount,
                  collectionRate: collectionRate,
                  formatMoney: _formatMoney,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.hourglass_bottom_rounded,
                              color: _LC.orange,
                              label: 'Kutilmoqda',
                              value: '$pendingCount ta',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.error_outline_rounded,
                              color: _LC.red,
                              label: "Muddati o'tgan",
                              value: '$overdueCount ta',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: _LC.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _LC.faint),
                        ),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: _LC.bg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _searchQuery = value),
                                decoration: InputDecoration(
                                  hintText: "Talaba ismi yoki oy bo'yicha...",
                                  hintStyle: const TextStyle(
                                      color: _LC.muted, fontSize: 13.5),
                                  prefixIcon: const Icon(Icons.search_rounded,
                                      color: _LC.purple),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close_rounded,
                                              color: _LC.muted, size: 20),
                                          onPressed: () {
                                            _searchController.clear();
                                            setState(() => _searchQuery = '');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _FilterChip(
                                    label: 'Barchasi',
                                    selected: _filter == null,
                                    onTap: () => setState(() => _filter = null),
                                  ),
                                  for (final s in GirlsPaymentStatus.values)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: _FilterChip(
                                        label: s.displayName,
                                        selected: _filter == s,
                                        onTap: () =>
                                            setState(() => _filter = s),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ✅ Talaba yuklab moliyaga yuborgan to'lov cheklari — bu
              // yozuvlar 'girls_payments' emas, umumiy 'tolov_cheklari'
              // to'plamiga tushadi (talaba_tolovlar_screen.dart orqali).
              // Shu sababli bu ro'yxatda ilgari umuman ko'rinmas edi —
              // endi shu sahifaning o'zida, tepada ko'rsatiladi.
              SliverToBoxAdapter(
                child: _StudentChecksSection(currentUser: widget.currentUser),
              ),
              if (all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: "Hozircha to'lovlar yo'q",
                    subtitle:
                        "Birinchi to'lovni qo'shish uchun pastdagi\ntugmadan foydalaning.",
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.search_off_rounded,
                    title: "Hech narsa topilmadi",
                    subtitle: "Qidiruvga mos to'lov topilmadi.",
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final p = items[index];
                        return _PaymentCard(
                          payment: p,
                          color: _statusColor(p.status),
                          statusIcon: _statusIcon(p.status),
                          methodIcon: _methodIcon(p.method),
                          initials: _initials(p.studentName),
                          formatMoney: _formatMoney,
                          onMarkPaid: p.status == GirlsPaymentStatus.paid
                              ? null
                              : () => provider.markAsPaid(p.id),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── StudentChecksSection: talaba o'zi yuklab moliyaga yuborgan
// to'lov cheklari ('tolov_cheklari' to'plami, hostel == 'girls').
// Bu yerda oxirgi cheklar jonli (real-time) ko'rsatiladi va "Barchasini
// ko'rish" tugmasi to'liq tasdiqlash/rad etish ekranini ochadi.
//
// ⚠️ MUHIM: bu yerda ataylab Firestore darajasidagi orderBy
// ISHLATILMAYDI. Sabab: where('hostel', isEqualTo: ...) +
// orderBy('uploadedAt') kombinatsiyasi composite index talab qiladi,
// va aynan shu index 'tolov_cheklari' to'plami uchun mavjud emas edi —
// bu esa "cloud_firestore/failed-precondition" xatoligiga sabab
// bo'lgan. Saralash endi Dart tomonida amalga oshiriladi, shuning
// uchun hech qanday qo'shimcha index kerak emas.
class _StudentChecksSection extends StatelessWidget {
  final UserModel? currentUser;
  const _StudentChecksSection({required this.currentUser});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return _LC.teal;
      case 'rejected':
        return _LC.red;
      default:
        return _LC.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_bottom_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Tasdiqlangan';
      case 'rejected':
        return 'Rad etilgan';
      default:
        return 'Kutilmoqda';
    }
  }

  String _formatMoney(num value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  DateTime? _uploadedAtOf(Map<String, dynamic> data) {
    final ts = data['uploadedAt'] ?? data['paymentDate'];
    if (ts == null) return null;
    try {
      return (ts as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // orderBy ataylab olib tashlandi — composite index shart emas.
      stream: FirebaseFirestore.instance
          .collection('tolov_cheklari')
          .where('hostel', isEqualTo: 'girls')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _LC.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _LC.red.withOpacity(0.25)),
              ),
              child: Text(
                "Talaba cheklarini yuklashda xatolik: ${snapshot.error}",
                style: const TextStyle(color: _LC.red, fontSize: 12),
              ),
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];
        if (allDocs.isEmpty) return const SizedBox.shrink();

        // Kliyent tomonida uploadedAt bo'yicha kamayish tartibida
        // saralab, faqat oxirgi 5 tasini olamiz.
        final sortedDocs = [...allDocs]..sort((a, b) {
            final da = _uploadedAtOf(a.data() as Map<String, dynamic>);
            final db = _uploadedAtOf(b.data() as Map<String, dynamic>);
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da);
          });
        final docs = sortedDocs.take(5).toList();

        final pendingCount = docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return (d['status'] ?? 'pending') == 'pending';
        }).length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _LC.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _LC.faint),
              boxShadow: [
                BoxShadow(
                    color: _LC.purple.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _LC.rose.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: _LC.rose, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Talaba yuborgan cheklar",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _LC.ink),
                      ),
                    ),
                    if (pendingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _LC.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$pendingCount yangi',
                          style: const TextStyle(
                              color: _LC.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final doc in docs)
                  _StudentCheckRow(
                    data: doc.data() as Map<String, dynamic>,
                    statusColor: _statusColor(
                        (doc.data() as Map)['status'] ?? 'pending'),
                    statusIcon:
                        _statusIcon((doc.data() as Map)['status'] ?? 'pending'),
                    statusLabel: _statusLabel(
                        (doc.data() as Map)['status'] ?? 'pending'),
                    formatMoney: _formatMoney,
                  ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _LC.purple,
                      side: BorderSide(color: _LC.purple.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TolovCheklariScreen(
                          currentUser: currentUser,
                          initialHostel: 'girls',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(
                      "Barcha cheklarni ko'rish va tasdiqlash",
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StudentCheckRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color statusColor;
  final IconData statusIcon;
  final String statusLabel;
  final String Function(num) formatMoney;

  const _StudentCheckRow({
    required this.data,
    required this.statusColor,
    required this.statusIcon,
    required this.statusLabel,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    final studentName = (data['studentName'] ?? "Noma'lum talaba").toString();
    final amount = (data['amount'] as num?) ?? 0;
    String dateStr = '';
    final ts = data['paymentDate'] ?? data['uploadedAt'];
    if (ts != null) {
      try {
        final dt = (ts as dynamic).toDate() as DateTime;
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _LC.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(studentName,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _LC.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (dateStr.isNotEmpty)
                  Text(dateStr,
                      style: const TextStyle(fontSize: 10.5, color: _LC.muted)),
              ],
            ),
          ),
          Text("${formatMoney(amount)} so'm",
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _LC.purple)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.13),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Moliyaviy hero: umumiy tushum, to'langan summa va yig'ilish
// foizini ko'rsatuvchi doiraviy indikator bilan gradient panel.
class _FinanceHero extends StatelessWidget {
  final double totalAmount;
  final double paidAmount;
  final double collectionRate;
  final String Function(num) formatMoney;
  const _FinanceHero({
    required this.totalAmount,
    required this.paidAmount,
    required this.collectionRate,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (collectionRate.clamp(0, 1) * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 66),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_LC.rose, _LC.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -25,
            right: -10,
            child: Icon(Icons.savings_rounded,
                size: 120, color: Colors.white.withOpacity(0.08)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Qizlar to'lovlari",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text("${formatMoney(totalAmount)} so'm",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    Text('jami tushum',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11.5)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.white.withOpacity(0.85), size: 14),
                        const SizedBox(width: 5),
                        Text("${formatMoney(paidAmount)} so'm to'landi",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        value: collectionRate.clamp(0, 1),
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$pct%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        Text("yig'ildi",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 9.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _LC.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LC.faint),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10.5,
                        color: _LC.muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _LC.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── To'lov kartasi — "chek" uslubida: talaba avatari, summasi va
// tishli (perforatsiya) chizig'i bilan.
class _PaymentCard extends StatelessWidget {
  final GirlsPaymentModel payment;
  final Color color;
  final IconData statusIcon;
  final IconData methodIcon;
  final String initials;
  final String Function(num) formatMoney;
  final VoidCallback? onMarkPaid;
  const _PaymentCard({
    required this.payment,
    required this.color,
    required this.statusIcon,
    required this.methodIcon,
    required this.initials,
    required this.formatMoney,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _LC.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _LC.faint),
        boxShadow: [
          BoxShadow(
              color: _LC.purple.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_LC.pink, _LC.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payment.studentName,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: _LC.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded,
                              size: 12, color: _LC.muted),
                          const SizedBox(width: 3),
                          Text(payment.month,
                              style: const TextStyle(
                                  fontSize: 11.5, color: _LC.muted)),
                          const SizedBox(width: 8),
                          Icon(methodIcon, size: 12, color: _LC.muted),
                          const SizedBox(width: 3),
                          Text(payment.method.displayName,
                              style: const TextStyle(
                                  fontSize: 11.5, color: _LC.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: color),
                      const SizedBox(width: 4),
                      Text(payment.status.displayName,
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CustomPaint(
              painter: _DashedLinePainter(color: _LC.faint),
              size: const Size(double.infinity, 1),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text("${formatMoney(payment.amount)} so'm",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _LC.purple)),
                const Spacer(),
                if (onMarkPaid != null)
                  ElevatedButton.icon(
                    onPressed: onMarkPaid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _LC.teal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 16, color: Colors.white),
                    label: const Text("To'landi",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration:
                  BoxDecoration(color: _LC.faint, shape: BoxShape.circle),
              child: Icon(icon, size: 46, color: _LC.violet),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: _LC.ink, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _LC.muted, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_LC.rose, _LC.purple])
              : null,
          color: selected ? null : _LC.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : _LC.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
