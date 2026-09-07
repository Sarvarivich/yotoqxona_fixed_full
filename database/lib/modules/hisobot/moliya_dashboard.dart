import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'qarzdorlar_royxati.dart';

// ─── Moliya bo'limi — Dashboard ─────────────────────────────────────
// Moliyachi profiliga kirganda ko'radigan umumiy ko'rinish: shu oylik
// tushum, kutilayotgan murojaatlar, qarzdorlar soni va byudjet holati.

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

class MoliyaDashboard extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<int>? onNavigate;
  const MoliyaDashboard({super.key, this.user, this.onNavigate});

  @override
  State<MoliyaDashboard> createState() => _MoliyaDashboardState();
}

class _MoliyaDashboardState extends State<MoliyaDashboard> {
  double _monthIncome = 0;
  int _pendingCount = 0;
  int _debtorsCount = 0;
  double _monthExpenses = 0;
  double _monthBudget = 0;
  bool _isLoading = true;

  StreamSubscription<QuerySnapshot>? _expensesSub;
  StreamSubscription<QuerySnapshot>? _incomeSub;
  StreamSubscription<DocumentSnapshot>? _budgetSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenLive();
  }

  @override
  void dispose() {
    _expensesSub?.cancel();
    _incomeSub?.cancel();
    _budgetSub?.cancel();
    super.dispose();
  }

  String get _monthKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Xarajat, tushum va byudjetni real-vaqtda kuzatib turadi — shunda
  /// bu raqamlar "Byudjet va xarajatlar" sahifasidagi bilan doim mos
  /// keladi, sahifani qayta ochish yoki pastga tortish shart emas.
  void _listenLive() {
    final fs = FirebaseFirestore.instance;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    _expensesSub = fs
        .collection('xarajatlar')
        .where('monthKey', isEqualTo: _monthKey)
        .snapshots()
        .listen((snap) {
      double total = 0;
      for (final doc in snap.docs) {
        total += (doc.data()['amount'] as num? ?? 0).toDouble();
      }
      if (mounted) setState(() => _monthExpenses = total);
    }, onError: (e) => debugPrint('Xarajatlarni kuzatishda xatolik: $e'));

    _incomeSub = fs
        .collection('tolov_cheklari')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen((snap) {
      double total = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        DateTime? refDate;
        try {
          if (d['paymentDate'] != null) {
            refDate = (d['paymentDate'] as Timestamp).toDate();
          } else if (d['uploadedAt'] != null) {
            refDate = (d['uploadedAt'] as Timestamp).toDate();
          }
        } catch (_) {}
        if (refDate == null ||
            refDate.isBefore(start) ||
            !refDate.isBefore(end)) {
          continue;
        }
        total += (d['amount'] as num? ?? 0).toDouble();
      }
      if (mounted) setState(() => _monthIncome = total);
    }, onError: (e) => debugPrint('Tushumni kuzatishda xatolik: $e'));

    _budgetSub = fs
        .collection('moliya_byudjetlari')
        .doc(_monthKey)
        .snapshots()
        .listen((doc) {
      final budget = (doc.data()?['monthlyBudget'] as num? ?? 0).toDouble();
      if (mounted) setState(() => _monthBudget = budget);
    }, onError: (e) => debugPrint('Byudjetni kuzatishda xatolik: $e'));
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final fs = FirebaseFirestore.instance;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);

    try {
      // Tasdiqlangan to'lovlar (shu oy)
      final checks = await fs
          .collection('tolov_cheklari')
          .where('status', isEqualTo: 'approved')
          .get();
      double income = 0;
      for (final doc in checks.docs) {
        final d = doc.data();
        DateTime? refDate;
        try {
          if (d['paymentDate'] != null) {
            refDate = (d['paymentDate'] as Timestamp).toDate();
          } else if (d['uploadedAt'] != null) {
            refDate = (d['uploadedAt'] as Timestamp).toDate();
          }
        } catch (_) {}
        if (refDate == null ||
            refDate.isBefore(start) ||
            !refDate.isBefore(end)) {
          continue;
        }
        income += (d['amount'] as num? ?? 0).toDouble();
      }

      // Kutilayotgan murojaatlar
      final pending = await fs
          .collection('tolov_cheklari')
          .where('status', isEqualTo: 'pending')
          .get();

      // Qarzdorlar
      final debtors = await fetchDebtors();

      // Xarajatlar (shu oy)
      final expenses = await fs
          .collection('xarajatlar')
          .where('monthKey', isEqualTo: _monthKey)
          .get();
      double expTotal = 0;
      for (final doc in expenses.docs) {
        expTotal += (doc.data()['amount'] as num? ?? 0).toDouble();
      }

      // Byudjet
      final budgetDoc =
          await fs.collection('moliya_byudjetlari').doc(_monthKey).get();
      final budget =
          (budgetDoc.data()?['monthlyBudget'] as num? ?? 0).toDouble();

      if (!mounted) return;
      setState(() {
        _monthIncome = income;
        _pendingCount = pending.docs.length;
        _debtorsCount = debtors.length;
        _monthExpenses = expTotal;
        _monthBudget = budget;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Moliya dashboard xatolik: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bgBase,
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: _C.violet,
        backgroundColor: _C.bgCard,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 16, 20, isWide ? 32 : 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(
                            child: CircularProgressIndicator(color: _C.violet),
                          ),
                        )
                      else ...[
                        _buildStatsGrid(constraints.maxWidth),
                        const SizedBox(height: 22),
                        _buildBudgetSummary(),
                        const SizedBox(height: 22),
                        _buildQuickActions(),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? "Xayrli tong"
        : hour < 18
            ? "Xayrli kun"
            : "Xayrli kech";
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_C.purple, _C.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$greeting,',
                  style: const TextStyle(color: _C.muted, fontSize: 12.5)),
              Text(
                widget.user?.fullName ?? 'Moliyachi',
                style: const TextStyle(
                    color: _C.white, fontSize: 18, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(double maxWidth) {
    final stats = [
      _StatData("Bu oylik tushum", "${_monthIncome.toStringAsFixed(0)} so'm",
          Icons.trending_up_rounded, _C.mint),
      _StatData("Kutilayotgan murojaatlar", "$_pendingCount ta",
          Icons.forum_rounded, _C.orange),
      _StatData("Qarzdorlar", "$_debtorsCount ta", Icons.warning_amber_rounded,
          _C.coral),
      _StatData("Bu oylik xarajat", "${_monthExpenses.toStringAsFixed(0)} so'm",
          Icons.receipt_long_rounded, _C.pink),
    ];

    final crossAxisCount = maxWidth > 900 ? 4 : (maxWidth > 560 ? 4 : 2);

    // ✅ Oldin balandlik "childAspectRatio" orqali kenglikka nisbatan
    // hisoblanardi — oyna/ekran torayganda balandlik ham qisqarib,
    // ichidagi icon+matn sig'may "BOTTOM OVERFLOWED" xatosini berardi.
    // Endi balandlik ekran kengligidan mustaqil, doimiy piksel
    // (mainAxisExtent) qilib belgilangan — kontent uchun har doim
    // yetarli joy bo'ladi.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 112,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) => _DashStatCard(
        data: stats[i],
        onTap: () {
          if (widget.onNavigate == null) return;
          switch (i) {
            case 0:
              widget.onNavigate!(2); // To'lov tarixi
              break;
            case 1:
              widget.onNavigate!(1); // Murojaatlar
              break;
            case 2:
              widget.onNavigate!(4); // Qarzdorlar
              break;
            case 3:
              widget.onNavigate!(3); // Byudjet
              break;
          }
        },
      ),
    );
  }

  Widget _buildBudgetSummary() {
    final remaining = _monthBudget - _monthExpenses;
    final over = remaining < 0 && _monthBudget > 0;
    final progress = _monthBudget > 0
        ? (1 - (remaining / _monthBudget)).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.faint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _C.violet.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.pie_chart_rounded,
                    size: 16, color: _C.violet),
              ),
              const SizedBox(width: 10),
              const Text("Byudjet holati",
                  style: TextStyle(
                      color: _C.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: () => widget.onNavigate?.call(3),
                child:
                    const Text("Batafsil", style: TextStyle(color: _C.violet)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_monthBudget <= 0)
            Text(
              "Bu oy uchun byudjet hali belgilanmagan.",
              style: TextStyle(color: _C.muted, fontSize: 12.5),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: _C.bgCard2,
                valueColor: AlwaysStoppedAnimation(over ? _C.coral : _C.mint),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              over
                  ? "Byudjetdan ${(-remaining).toStringAsFixed(0)} so'm oshib ketdi"
                  : "Byudjet: ${_monthBudget.toStringAsFixed(0)} so'm · Qolgan: ${remaining.toStringAsFixed(0)} so'm",
              style: TextStyle(
                  color: over ? _C.coral : _C.soft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.forum_rounded,
            color: _C.orange,
            label: "Murojaatlarni ko'rish",
            onTap: () => widget.onNavigate?.call(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.groups_rounded,
            color: _C.coral,
            label: "Qarzdorlar ro'yxati",
            onTap: () => widget.onNavigate?.call(4),
          ),
        ),
      ],
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  _StatData(this.title, this.value, this.icon, this.color);
}

class _DashStatCard extends StatelessWidget {
  final _StatData data;
  final VoidCallback? onTap;
  const _DashStatCard({required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.faint),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, size: 17, color: data.color),
            ),
            const Spacer(),
            Text(
              data.value,
              style: const TextStyle(
                  color: _C.white, fontSize: 15, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              data.title,
              style: const TextStyle(color: _C.muted, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: _C.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _C.soft, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
