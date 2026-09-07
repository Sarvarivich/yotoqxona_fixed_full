import 'package:flutter/material.dart';
import 'package:yotoqxona/modules/services/api_service.dart';

// ─── Moliyachi: to'lov cheklarini ko'rib chiqish (Laravel API) ───
// GET /payments (moliyachi bo'lsa hammasini ko'radi) -> PATCH /payments/{id}
// orqali tasdiqlash (approved) yoki bekor qilish (rejected).
class PaymentReviewApiScreen extends StatefulWidget {
  const PaymentReviewApiScreen({super.key});

  @override
  State<PaymentReviewApiScreen> createState() =>
      _PaymentReviewApiScreenState();
}

class _PaymentReviewApiScreenState extends State<PaymentReviewApiScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _loading = true;
  String? _error;
  List<dynamic> _payments = [];
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payments = await _api.getPayments();
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Xatolik: $e";
        _loading = false;
      });
    }
  }

  List<dynamic> _byStatus(String status) {
    return _payments.where((p) => p['status']?.toString() == status).toList();
  }

  Future<void> _review(String paymentId, String status) async {
    setState(() => _processingIds.add(paymentId));

    try {
      await _api.updatePayment(paymentId, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'approved'
              ? "To'lov tasdiqlandi ✅"
              : "To'lov bekor qilindi ❌"),
          backgroundColor:
              status == 'approved' ? Colors.green : Colors.red,
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
        SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(paymentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("To'lov cheklarini tekshirish"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Kutilmoqda (${_byStatus('pending').length})"),
            Tab(text: "Tasdiqlangan (${_byStatus('approved').length})"),
            Tab(text: "Bekor qilingan (${_byStatus('rejected').length})"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
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
                    _buildList(_byStatus('pending'), showActions: true),
                    _buildList(_byStatus('approved'), showActions: false),
                    _buildList(_byStatus('rejected'), showActions: false),
                  ],
                ),
    );
  }

  Widget _buildList(List<dynamic> payments, {required bool showActions}) {
    if (payments.isEmpty) {
      return const Center(child: Text("Bu bo'limda to'lovlar yo'q"));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final p = payments[index];
          final id = p['id'].toString();
          final isProcessing = _processingIds.contains(id);
          final amount = p['amount']?.toString() ?? '0';
          final studentName = p['student_name']?.toString() ?? '-';
          final studentEmail = p['student_email']?.toString() ?? '';
          final roomNumber = p['room_number']?.toString();
          final receiptUrl = p['receipt_url']?.toString();
          final note = p['note']?.toString();
          final createdAt = p['created_at']?.toString();

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(studentName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text(studentEmail,
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text("$amount so'm",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                              fontSize: 15)),
                    ],
                  ),
                  if (roomNumber != null) ...[
                    const SizedBox(height: 4),
                    Text("$roomNumber-xona",
                        style: const TextStyle(color: Colors.black54)),
                  ],
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text("Izoh: $note",
                        style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.black54)),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(createdAt.split('T').first,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black38)),
                  ],
                  if (receiptUrl != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showReceiptDialog(receiptUrl),
                      child: Row(
                        children: const [
                          Icon(Icons.receipt_long,
                              size: 18, color: Colors.indigo),
                          SizedBox(width: 4),
                          Text("Chekni ko'rish",
                              style: TextStyle(
                                  color: Colors.indigo,
                                  decoration: TextDecoration.underline)),
                        ],
                      ),
                    ),
                  ],
                  if (showActions) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () => _review(id, 'rejected'),
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text("Bekor qilish",
                                style: TextStyle(color: Colors.red)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isProcessing
                                ? null
                                : () => _review(id, 'approved'),
                            icon: isProcessing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check),
                            label: const Text("Tasdiqlash"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReceiptDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (context, error, stack) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 48),
                  const SizedBox(height: 8),
                  const Text("Rasmni yuklab bo'lmadi"),
                  const SizedBox(height: 4),
                  Text(url,
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
