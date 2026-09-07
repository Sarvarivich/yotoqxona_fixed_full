import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../modules/models/user_model.dart';
import '../modules/services/api_service.dart';

// ─── To'lov cheklarini ko'rib chiqish (Laravel backend) ──────────────
// ✅ Bu ekran TolovCheklariScreen (Firestore'ga bog'langan, 1119 qator)
// o'rnini bosadi — moliyachi/admin/superadmin/mudir talaba yuborgan
// to'lov cheklarini shu yerdan tasdiqlaydi yoki rad etadi.
//
// Backend: GET /api/payments (hammasi), PUT /api/payments/{id}
// ({status: approved|rejected, review_note}).
//
// Diqqat: bu ekran Laravel'ning "payments" jadvali bilan ishlaydi
// (Firestore'dagi "tolov_cheklari" bilan EMAS) — chunki talaba endi
// to'lovni to'g'ridan-to'g'ri Laravel API'ga yuboradi
// (talaba_tolovlar_screen.dart, ApiService().uploadPayment).

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

class PaymentReviewScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final UserModel? currentUser;

  const PaymentReviewScreen({
    super.key,
    this.onBack,
    this.currentUser,
  });

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _noteCtrl = TextEditingController();

  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService().get('payments');
      final data = result['data'];
      setState(() {
        _payments = (data is List)
            ? data
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            : <Map<String, dynamic>>[];
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'To\'lovlarni yuklashda xatolik: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _byStatus(String status) {
    return _payments.where((p) {
      final s = (p['status'] ?? 'pending').toString();
      return s == status;
    }).toList();
  }

  Future<void> _showApproveDialog(Map<String, dynamic> payment) async {
    _noteCtrl.clear();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('To\'lovni tasdiqlash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${payment['student_name'] ?? 'Noma\'lum talaba'} '
              'to\'lovini tasdiqlaysizmi?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Izoh (ixtiyoriy)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.mint),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _reviewPayment(payment, 'approved');
            },
            child: const Text('Tasdiqlash'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRejectDialog(Map<String, dynamic> payment) async {
    _noteCtrl.clear();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('To\'lovni rad etish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${payment['student_name'] ?? 'Noma\'lum talaba'} '
              'to\'lovini rad etasizmi?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Rad etish sababi',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.coral),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _reviewPayment(payment, 'rejected');
            },
            child: const Text('Rad etish'),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewPayment(
    Map<String, dynamic> payment,
    String status,
  ) async {
    final id = payment['id']?.toString();
    if (id == null) return;

    try {
      await ApiService().put(
        'payments/$id',
        body: {
          'status': status,
          'review_note': _noteCtrl.text.trim().isNotEmpty
              ? _noteCtrl.text.trim()
              : (status == 'approved'
                  ? "To'lov tasdiqlandi"
                  : "To'lov rad etildi"),
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? "To'lov tasdiqlandi"
                : "To'lov rad etildi",
          ),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text("To'lov cheklari"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Kutilmoqda (${_byStatus('pending').length})'),
            Tab(text: 'Tasdiqlangan (${_byStatus('approved').length})'),
            Tab(text: 'Rad etilgan (${_byStatus('rejected').length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _C.purple))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text("Qayta urinish"),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList('pending'),
                    _buildList('approved'),
                    _buildList('rejected'),
                  ],
                ),
    );
  }

  Widget _buildList(String status) {
    final items = _byStatus(status);
    if (items.isEmpty) {
      return Center(
        child: Text(
          status == 'pending'
              ? "Kutilayotgan chek yo'q"
              : status == 'approved'
                  ? "Tasdiqlangan chek yo'q"
                  : "Rad etilgan chek yo'q",
          style: const TextStyle(color: _C.muted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) => _PaymentCard(
          payment: items[i],
          status: status,
          onApprove: () => _showApproveDialog(items[i]),
          onReject: () => _showRejectDialog(items[i]),
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final String status;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PaymentCard({
    required this.payment,
    required this.status,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final studentName =
        (payment['student_name'] ?? 'Noma\'lum talaba').toString();
    final roomNumber = (payment['room_number'] ?? '—').toString();
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final period = (payment['period'] ?? '—').toString();
    final method = (payment['method'] ?? '—').toString();
    final note = payment['note']?.toString();
    final receiptUrl = payment['receipt_url']?.toString();
    final reviewNote = payment['review_note']?.toString();

    final statusColor = status == 'approved'
        ? _C.mint
        : status == 'rejected'
            ? _C.coral
            : _C.orange;
    final statusLabel = status == 'approved'
        ? 'Tasdiqlandi'
        : status == 'rejected'
            ? 'Rad etildi'
            : 'Kutilmoqda';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.faint),
        boxShadow: [
          BoxShadow(
            color: _C.purple.withOpacity(0.06),
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
              CircleAvatar(
                backgroundColor: _C.violet.withOpacity(0.15),
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: _C.purple, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('Xona № $roomNumber · $period',
                        style: const TextStyle(color: _C.muted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 16, color: _C.muted),
              const SizedBox(width: 6),
              Text("${amount.toStringAsFixed(0)} so'm",
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 16),
              Icon(Icons.credit_card_outlined, size: 16, color: _C.muted),
              const SizedBox(width: 6),
              Text(method, style: const TextStyle(color: _C.muted)),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Izoh: $note',
                style: const TextStyle(color: _C.muted, fontSize: 12.5)),
          ],
          if (reviewNote != null && reviewNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Ko\'rib chiquvchi izohi: $reviewNote',
                style: const TextStyle(color: _C.muted, fontSize: 12.5)),
          ],
          if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final uri = Uri.tryParse(receiptUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 16, color: _C.purple),
                  const SizedBox(width: 6),
                  const Text(
                    'Chekni ko\'rish',
                    style: TextStyle(
                      color: _C.purple,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18, color: _C.coral),
                    label: const Text('Rad etish',
                        style: TextStyle(color: _C.coral)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _C.coral),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Tasdiqlash'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.mint,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
