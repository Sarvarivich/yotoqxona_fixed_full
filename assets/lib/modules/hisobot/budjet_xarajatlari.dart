import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

// ─── Moliya bo'limi — Byudjet va xarajatlar hisoboti ───────────────
// Moliyachi shu yerda oylik byudjetni belgilaydi, xarajatlarni kiritadi
// va tasdiqlangan to'lovlardan kelib chiqib daromad/xarajat/qoldiq
// balansini kuzatadi.

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

const List<String> kExpenseCategories = [
  "Kommunal xizmatlar",
  "Ta'mirlash",
  "Inventar / jihozlar",
  "Xodimlar maoshi",
  "Tozalik va gigiyena",
  "Boshqa",
];

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

class ByudjetXarajatlar extends StatefulWidget {
  final UserModel? user;
  const ByudjetXarajatlar({super.key, this.user});

  @override
  State<ByudjetXarajatlar> createState() => _ByudjetXarajatlarState();
}

class _ByudjetXarajatlarState extends State<ByudjetXarajatlar> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: 'Oyni tanlang',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _C.violet,
            onPrimary: Colors.white,
            surface: _C.bgCard,
            onSurface: _C.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _editBudgetDialog(double currentBudget) async {
    final ctrl = TextEditingController(
        text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Oylik byudjet", style: TextStyle(color: _C.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: _C.white),
          decoration: InputDecoration(
            hintText: "Byudjet summasi (so'm)",
            hintStyle: TextStyle(color: _C.muted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _C.faint),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.violet),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.purple),
            onPressed: () async {
              final val = double.tryParse(ctrl.text.trim());
              if (val == null) return;
              await FirebaseFirestore.instance
                  .collection('moliya_byudjetlari')
                  .doc(_monthKey(_selectedMonth))
                  .set({
                'monthKey': _monthKey(_selectedMonth),
                'monthlyBudget': val,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Saqlash", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpenseDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = kExpenseCategories.first;
    DateTime date = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: _C.bgCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title:
              const Text("Xarajat qo'shish", style: TextStyle(color: _C.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: _C.white),
                  decoration: InputDecoration(
                    labelText: "Xarajat nomi",
                    labelStyle: TextStyle(color: _C.muted),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _C.faint),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: _C.white),
                  decoration: InputDecoration(
                    labelText: "Summa (so'm)",
                    labelStyle: TextStyle(color: _C.muted),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _C.faint),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  dropdownColor: _C.bgCard,
                  style: const TextStyle(color: _C.white),
                  decoration: InputDecoration(
                    labelText: "Toifa",
                    labelStyle: TextStyle(color: _C.muted),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _C.faint),
                    ),
                  ),
                  items: kExpenseCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDlgState(() => category = v!),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(DateTime.now().year - 3),
                      lastDate: DateTime(DateTime.now().year + 1),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: _C.violet,
                            onPrimary: Colors.white,
                            surface: _C.bgCard,
                            onSurface: _C.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setDlgState(() => date = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _C.faint),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_rounded,
                            color: _C.muted, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                          style: const TextStyle(color: _C.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Bekor qilish"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _C.purple),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (titleCtrl.text.trim().isEmpty || amount == null) return;
                await FirebaseFirestore.instance.collection('xarajatlar').add({
                  'title': titleCtrl.text.trim(),
                  'category': category,
                  'amount': amount,
                  'date': Timestamp.fromDate(date),
                  'monthKey': _monthKey(date),
                  'createdBy': widget.user?.id,
                  'createdByName': widget.user?.fullName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child:
                  const Text("Qo'shish", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExpense(String id) async {
    await FirebaseFirestore.instance.collection('xarajatlar').doc(id).delete();
  }

  Future<double> _incomeForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    double total = 0;
    final snap = await FirebaseFirestore.instance
        .collection('tolov_cheklari')
        .where('status', isEqualTo: 'approved')
        .get();
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
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final monthKey = _monthKey(_selectedMonth);

    return Container(
      color: _C.bgBase,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GestureDetector(
              onTap: _pickMonth,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _C.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.faint),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: _C.violet, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      _monthLabel(_selectedMonth),
                      style: const TextStyle(
                          color: _C.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Icon(Icons.expand_more_rounded, color: _C.muted),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('moliya_byudjetlari')
                  .doc(monthKey)
                  .snapshots(),
              builder: (context, budgetSnap) {
                if (budgetSnap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "Byudjetni yuklashda xatolik:\n${budgetSnap.error}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _C.coral, fontSize: 12),
                        ),
                      ),
                    ),
                  );
                }
                final budgetData =
                    budgetSnap.data?.data() as Map<String, dynamic>?;
                final budget =
                    (budgetData?['monthlyBudget'] as num? ?? 0).toDouble();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('xarajatlar')
                      .where('monthKey', isEqualTo: monthKey)
                      .snapshots(),
                  builder: (context, expSnap) {
                    if (expSnap.hasError) {
                      // Odatda bu yerga Firestore composite index
                      // yo'qligi sababli tushiladi (monthKey + date
                      // bo'yicha so'rov index talab qiladi).
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 48, color: _C.coral),
                              const SizedBox(height: 10),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  "Xarajatlarni yuklashda xatolik:\n${expSnap.error}",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: _C.coral, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (expSnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: _C.violet),
                        ),
                      );
                    }
                    final expenseDocs = expSnap.data?.docs ?? [];
                    final sortedExpenseDocs = [...expenseDocs]..sort((a, b) {
                        final da = (a.data() as Map<String, dynamic>)['date'];
                        final db = (b.data() as Map<String, dynamic>)['date'];
                        final ta =
                            da is Timestamp ? da.toDate() : DateTime(1970);
                        final tb =
                            db is Timestamp ? db.toDate() : DateTime(1970);
                        return tb.compareTo(ta); // descending
                      });
                    final totalExpenses = expenseDocs.fold<double>(
                      0,
                      (sum, doc) =>
                          sum +
                          ((doc.data() as Map<String, dynamic>)['amount']
                                  as num? ??
                              0),
                    );

                    return FutureBuilder<double>(
                      future: _incomeForMonth(_selectedMonth),
                      builder: (context, incomeSnap) {
                        final income = incomeSnap.data ?? 0;
                        final remaining = budget - totalExpenses;

                        return RefreshIndicator(
                          color: _C.violet,
                          backgroundColor: _C.bgCard,
                          onRefresh: () async => setState(() {}),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildBudgetCard(budget, remaining),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatMini(
                                        icon: Icons.trending_up_rounded,
                                        color: _C.mint,
                                        label: "Tushum",
                                        value: income.toStringAsFixed(0),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _StatMini(
                                        icon: Icons.trending_down_rounded,
                                        color: _C.coral,
                                        label: "Xarajat",
                                        value:
                                            totalExpenses.toStringAsFixed(0),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Xarajatlar ro'yxati",
                                      style: TextStyle(
                                          color: _C.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    TextButton.icon(
                                      onPressed: _addExpenseDialog,
                                      icon: const Icon(Icons.add_rounded,
                                          size: 18, color: _C.violet),
                                      label: const Text("Qo'shish",
                                          style: TextStyle(color: _C.violet)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (sortedExpenseDocs.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 40),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.receipt_outlined,
                                              size: 48, color: _C.muted),
                                          const SizedBox(height: 10),
                                          Text("Bu oyda xarajat kiritilmagan",
                                              style: TextStyle(
                                                  color: _C.muted,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ...sortedExpenseDocs.map((doc) {
                                    final d =
                                        doc.data() as Map<String, dynamic>;
                                    return _ExpenseCard(
                                      title: d['title'] ?? '',
                                      category: d['category'] ?? '',
                                      amount:
                                          (d['amount'] as num? ?? 0).toDouble(),
                                      date: d['date'] != null
                                          ? (d['date'] as Timestamp).toDate()
                                          : null,
                                      onDelete: () => _deleteExpense(doc.id),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        );
                      },
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

  Widget _buildBudgetCard(double budget, double remaining) {
    final progress = budget > 0 ? (remaining / budget).clamp(-1.0, 1.0) : 0.0;
    final over = remaining < 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.purple, Color(0xFF4A3FA0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Oylik byudjet",
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () => _editBudgetDialog(budget),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text("Tahrirlash",
                          style: TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            budget > 0 ? "${budget.toStringAsFixed(0)} so'm" : "Belgilanmagan",
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: budget > 0 ? (1 - progress).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(over ? _C.coral : _C.mint),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            over
                ? "Byudjetdan ${(-remaining).toStringAsFixed(0)} so'm oshib ketdi"
                : "Qolgan: ${remaining.toStringAsFixed(0)} so'm",
            style: TextStyle(
                color: over ? _C.coral : Colors.white.withOpacity(0.85),
                fontSize: 12.5,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      "Yanvar",
      "Fevral",
      "Mart",
      "Aprel",
      "May",
      "Iyun",
      "Iyul",
      "Avgust",
      "Sentabr",
      "Oktabr",
      "Noyabr",
      "Dekabr"
    ];
    return "${months[d.month - 1]} ${d.year}";
  }
}

class _StatMini extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatMini({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.faint),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: _C.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis),
                Text(label, style: TextStyle(color: _C.muted, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final String title;
  final String category;
  final double amount;
  final DateTime? date;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = date != null
        ? '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}'
        : '—';
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
              color: _C.coral.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: _C.coral, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _C.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('$category · $dateStr',
                    style: TextStyle(color: _C.muted, fontSize: 11)),
              ],
            ),
          ),
          Text("-${amount.toStringAsFixed(0)}",
              style: const TextStyle(
                  color: _C.coral, fontSize: 13, fontWeight: FontWeight.w800)),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: _C.muted, size: 19),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
