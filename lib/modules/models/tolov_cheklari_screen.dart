import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'user_model.dart';

// ─── Creative LIGHT palette ───
class _LC {
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

class TolovCheklariScreen extends StatefulWidget {
  /// Tab sifatida ishlatilganda (push qilinmagan bo'lsa ham) orqaga
  /// qaytish tugmasi bosilganda chaqiriladigan callback.
  final VoidCallback? onBack;

  /// Hozir tizimga kirgan foydalanuvchi (moliyachi/mudir/admin) —
  /// chekni kim tasdiqlagani yoki rad etganini yozib qo'yish uchun.
  final UserModel? currentUser;

  /// Ekran ochilganda qaysi yotoqxona tabi tanlangan bo'lishini
  /// majburan belgilash uchun (masalan GirlsAdminScreen ichidan
  /// ochilganda, currentUser.hostel to'ldirilmagan bo'lsa ham, doim
  /// "Qiz bolalar" bilan ochilishi kerak). Berilmasa, avvalgidek
  /// currentUser.hostel (yoki "boys") ishlatiladi. Foydalanuvchi
  /// baribir ekrandagi tugmalar orqali qo'lda almashtira oladi.
  final String? initialHostel;

  const TolovCheklariScreen({
    super.key,
    this.onBack,
    this.currentUser,
    this.initialHostel,
  });

  @override
  State<TolovCheklariScreen> createState() => _TolovCheklariScreenState();
}

class _TolovCheklariScreenState extends State<TolovCheklariScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _noteCtrl = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late String _selectedHostel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // ✅ Boshqa bo'limlardagi kabi, moliyachi/mudir/admin o'z yotoqxonasi
    // tanlangan holda ekranni ochadi, so'ngra "O'g'il bolalar" / "Qiz
    // bolalar" tugmalari orqali ikkalasi orasida almashtirishi mumkin.
    final forced = (widget.initialHostel ?? '').trim();
    final userHostel = (widget.currentUser?.hostel ?? '').trim();
    final resolved = forced.isNotEmpty ? forced : userHostel;
    _selectedHostel = (resolved.isEmpty ? 'boys' : resolved).toLowerCase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String get _reviewerName {
    final name = widget.currentUser?.fullName ?? '';
    return name.trim().isNotEmpty ? name.trim() : 'Noma\'lum xodim';
  }

  final ApiService _api = ApiService();
  bool _loading = false;

  dynamic _dataValue(Map<String, dynamic> d, String key) => d[key];

  String _str(dynamic value) => value?.toString() ?? '';

  String _formatDate(dynamic value, {bool withTime = false}) {
    if (value == null) return '—';
    DateTime? dt;
    if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      dt = DateTime.tryParse(value);
    } else if (value is Map && value['date'] != null) {
      dt = DateTime.tryParse(value['date'].toString());
    }
    if (dt == null) return _str(value).isEmpty ? '—' : _str(value);
    final base =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    if (!withTime) return base;
    return '$base ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _hostelKind(Map<String, dynamic> d) {
    final name = _str(d['hostel_name']).trim().toLowerCase();
    final raw = _str(d['hostel']).trim().toLowerCase();
    final combined = '$name $raw';
    if (combined.contains('girl') ||
        combined.contains('qiz') ||
        combined.contains('жен') ||
        combined.contains('ayol')) {
      return 'girls';
    }
    return 'boys';
  }

  Future<List<Map<String, dynamic>>> _loadPayments() async {
    final result = await _api.get('payments');
    if (result['success'] != true) {
      throw Exception(
          result['message']?.toString() ?? 'To\'lovlarni yuklab bo\'lmadi.');
    }
    final raw = result['data'];
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> _showApproveDialog(
      String id, String studentName, Map<String, dynamic> payment) async {
    _noteCtrl.clear();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: _LC.teal),
            SizedBox(width: 8),
            Text('Tasdiqlash'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$studentName ning to\'lovi tasdiqlanadi.'),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Izoh (ixtiyoriy)',
                hintText: "Masalan: To'lov tasdiqlandi",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Orqaga')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _LC.teal),
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
            label:
                const Text('Tasdiqlash', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _updatePayment(
                  id, 'approved', _noteCtrl.text.trim(), studentName);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showRejectDialog(String id, String studentName) async {
    _noteCtrl.clear();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Bekor qilish'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$studentName ning to\'lovi rad etiladi.'),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Sabab',
                hintText: 'Masalan: chek rasmiy emas, summa xato...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Orqaga')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
            label:
                const Text('Rad etish', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final reason = _noteCtrl.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Rad etish sababini yozing'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx);
              await _updatePayment(id, 'rejected', reason, studentName);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _updatePayment(
      String id, String status, String note, String studentName) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        'status': status,
        'review_note': note.isNotEmpty ? note : null,
      };
      if (status == 'approved') {
        body['paid_at'] = DateTime.now().toIso8601String();
      }
      final result = await _api.patch('payments/$id', body: body);
      if (result['success'] != true) {
        throw Exception(
            result['message']);
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'approved'
              ? '$studentName to\'lovi tasdiqlandi'
              : '$studentName to\'lovi rad etildi'),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        title: const Text("To'lov cheklari",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_LC.purple, _LC.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        // ✅ Orqaga qaytish tugmasi har doim ko'rinadi (tab sifatida ham,
        // push qilingan sahifa sifatida ham ishlatilganda)
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Orqaga',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              widget.onBack?.call();
            }
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Kutilmoqda'),
                  SizedBox(width: 4),
                  _PendingBadge(),
                ],
              ),
            ),
            Tab(text: 'Tasdiqlangan'),
            Tab(text: 'Rad etilgan'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 🚻 Yotoqxona turini tanlash — boshqa bo'limlardagi kabi,
          // to'lov cheklari ham "O'g'il bolalar" va "Qiz bolalar" uchun
          // alohida-alohida ko'rsatiladi.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: SizedBox(
              height: 46,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedHostel == "boys"
                            ? _LC.purple
                            : Colors.white,
                        foregroundColor: _selectedHostel == "boys"
                            ? Colors.white
                            : _LC.purple,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: _selectedHostel == "boys"
                                  ? Colors.transparent
                                  : _LC.faint),
                        ),
                      ),
                      onPressed: () {
                        setState(() => _selectedHostel = "boys");
                      },
                      child: const Text("O'g'il bolalar"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedHostel == "girls"
                            ? _LC.purple
                            : Colors.white,
                        foregroundColor: _selectedHostel == "girls"
                            ? Colors.white
                            : _LC.purple,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: _selectedHostel == "girls"
                                  ? Colors.transparent
                                  : _LC.faint),
                        ),
                      ),
                      onPressed: () {
                        setState(() => _selectedHostel = "girls");
                      },
                      child: const Text("Qiz bolalar"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 🔎 Talaba ismi yoki sana bo'yicha qidiruv (admin va yotoqxona mudiri uchun)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Container(
              decoration: BoxDecoration(
                color: _LC.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _LC.faint),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText:
                      "Ism yoki sana (masalan 17.07.2026) bo'yicha qidirish...",
                  hintStyle: const TextStyle(color: _LC.muted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _LC.purple, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: _LC.muted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList('pending'),
                _buildList('approved'),
                _buildList('rejected'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(String status) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadPayments(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 56, color: _LC.coral),
                  const SizedBox(height: 12),
                  Text('To\'lovlarni yuklashda xatolik: ${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _LC.muted, fontSize: 12.5)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Qayta yuklash'),
                  ),
                ],
              ),
            ),
          );
        }

        final all = snap.data ?? <Map<String, dynamic>>[];
        final docs = all.where((d) {
          return _str(d['status']).toLowerCase() == status &&
              _hostelKind(d) == _selectedHostel;
        }).where((d) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery;
          final name = _str(d['student_name']).toLowerCase();
          final email = _str(d['student_email']).toLowerCase();
          final period = _str(d['period']).toLowerCase();
          final room = _str(d['room_number']).toLowerCase();
          final paymentDate = _formatDate(d['payment_date']).toLowerCase();
          final created =
              _formatDate(d['created_at'], withTime: true).toLowerCase();
          return name.contains(q) ||
              email.contains(q) ||
              period.contains(q) ||
              room.contains(q) ||
              paymentDate.contains(q) ||
              created.contains(q);
        }).toList();

        docs.sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));

        if (docs.isEmpty) {
          final hostelLabel =
              _selectedHostel == 'boys' ? "O'g'il bolalar" : 'Qiz bolalar';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    _searchQuery.isNotEmpty
                        ? Icons.search_off_rounded
                        : Icons.receipt_long_rounded,
                    size: 64,
                    color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isNotEmpty
                      ? '"$_searchQuery" bo\'yicha to\'lov topilmadi'
                      : status == 'pending'
                          ? '$hostelLabel: kutilayotgan cheklar yo\'q'
                          : status == 'approved'
                              ? '$hostelLabel: tasdiqlangan cheklar yo\'q'
                              : '$hostelLabel: rad etilgan cheklar yo\'q',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              return _buildCheckCard(_str(d['id']), d, status);
            },
          ),
        );
      },
    );
  }

  DateTime _sortDate(Map<String, dynamic> d) {
    final a = DateTime.tryParse(_str(d['created_at']));
    final b = DateTime.tryParse(_str(d['payment_date']));
    return a ?? b ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildCheckCard(String id, Map<String, dynamic> d, String status) {
    // Laravel bog'langan obyektni qaytaradi: student: { full_name: ... }
    // Eski Firestore esa student_name / studentName maydonini yozardi.
    final studentObj = d['student'];
    final studentFromObj = studentObj is Map
        ? _str(studentObj['full_name'] ?? studentObj['fullName'])
        : '';

    final studentName = studentFromObj.isNotEmpty
        ? studentFromObj
        : _str(d['student_name']).isNotEmpty
        ? _str(d['student_name'])
        : 'Noma\'lum talaba';
    final fileName = _str(d['receipt_path']).isNotEmpty
        ? _str(d['receipt_path']).split('/').last
        : 'To\'lov cheki';
    final fileUrl = _str(d['receipt_url']);
    final lowerName = fileName.toLowerCase();
    final isPdf = lowerName.endsWith('.pdf');
    final isImage =
        ['.jpg', '.jpeg', '.png', '.webp', '.gif'].any(lowerName.endsWith);
    final statusColor = status == 'approved'
        ? _LC.teal
        : status == 'rejected'
            ? _LC.coral
            : _LC.orange;
    final amount = d['amount'];
    final amountText = amount == null ? '—' : '$amount so\'m';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _LC.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _LC.faint),
        boxShadow: [
          BoxShadow(
              color: _LC.purple.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [_LC.purple, _LC.violet]),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                      studentName.isNotEmpty
                          ? studentName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(studentName,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: _LC.ink)),
                        Text(_formatDate(d['created_at'], withTime: true),
                            style: const TextStyle(
                                fontSize: 12, color: _LC.muted)),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    status == 'approved'
                        ? 'Tasdiqlandi'
                        : status == 'rejected'
                            ? 'Rad etildi'
                            : 'Kutilmoqda',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _InfoChip(
                      icon: Icons.event_rounded,
                      label: 'To\'lov sanasi',
                      value: _formatDate(d['payment_date']))),
              const SizedBox(width: 10),
              Expanded(
                  child: _InfoChip(
                      icon: Icons.payments_rounded,
                      label: 'To\'lov summasi',
                      value: amountText)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _InfoChip(
                      icon: Icons.meeting_room_rounded,
                      label: 'Xona',
                      value: _str(d['room_number']).isEmpty
                          ? '—'
                          : _str(d['room_number']))),
              const SizedBox(width: 10),
              Expanded(
                  child: _InfoChip(
                      icon: Icons.calendar_month_rounded,
                      label: 'Davr',
                      value:
                          _str(d['period']).isEmpty ? '—' : _str(d['period']))),
            ]),
            if (_str(d['note']).isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Izoh: ${_str(d['note'])}',
                  style: const TextStyle(fontSize: 12.5, color: _LC.muted)),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _LC.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _LC.faint)),
              child: Row(children: [
                Icon(
                    isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.receipt_long_rounded,
                    color: isPdf ? _LC.coral : _LC.purple,
                    size: 26),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(fileName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _LC.ink),
                        overflow: TextOverflow.ellipsis)),
              ]),
            ),
            if (fileUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(fileUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                          height: 100,
                          child: Center(child: Icon(Icons.broken_image)))),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _LC.purple,
                      side: BorderSide(color: _LC.purple.withOpacity(0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Chekni ochish',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    final ok = await launchUrl(Uri.parse(fileUrl),
                        mode: LaunchMode.externalApplication);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Chekni ochib bo\'lmadi')));
                    }
                  },
                ),
              ),
            ],
            if (status == 'approved' || status == 'rejected') ...[
              const SizedBox(height: 10),
              _ReviewInfoBox(
                  status: status,
                  reviewedBy: _str(d['reviewed_by']),
                  reviewedAt: d['updated_at'],
                  reviewNote: _str(d['review_note']),
                  color: statusColor),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _LC.coral,
                      side: BorderSide(color: _LC.coral.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Rad etish'),
                  onPressed: _loading
                      ? null
                      : () => _showRejectDialog(id, studentName),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _LC.teal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      size: 18, color: Colors.white),
                  label: const Text('Tasdiqlash',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  onPressed: _loading
                      ? null
                      : () => _showApproveDialog(id, studentName, d),
                )),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// Kutilmoqda tab uchun API orqali olinadigan badge.
class _PendingBadge extends StatelessWidget {
  const _PendingBadge();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: ApiService().get('payments'),
      builder: (context, snap) {
        if (!snap.hasData || snap.data is! Map) return const SizedBox.shrink();
        final raw = snap.data['data'];
        if (raw is! List) return const SizedBox.shrink();
        final count = raw
            .where((e) => e is Map && e['status']?.toString() == 'pending')
            .length;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: _LC.coral, borderRadius: BorderRadius.circular(10)),
          child: Text('$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}

// Chekni kim, qachon va qanday izoh bilan tasdiqlagani/rad etganini
// ko'rsatuvchi blok. Barcha moliyachilar/mudir/admin qaysi xodim
// qaysi chekni ko'rib chiqqanini shu yerdan ko'radi.
class _ReviewInfoBox extends StatelessWidget {
  final String status; // 'approved' | 'rejected'
  final String reviewedBy;
  final dynamic reviewedAt;
  final String reviewNote;
  final Color color;

  const _ReviewInfoBox({
    required this.status,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.reviewNote,
    required this.color,
  });

  String get _dateStr {
    if (reviewedAt == null) return '—';
    final dt = DateTime.tryParse(reviewedAt.toString());
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewRow(
            emoji: isApproved ? '✅' : '❌',
            label: 'Holati',
            value: isApproved ? 'Tasdiqlangan' : 'Rad etilgan',
            color: color,
          ),
          const SizedBox(height: 8),
          _ReviewRow(
            emoji: '👤',
            label: isApproved ? 'Tasdiqlagan' : 'Rad etgan',
            value: reviewedBy.isNotEmpty ? reviewedBy : 'Noma\'lum xodim',
            color: color,
          ),
          const SizedBox(height: 8),
          _ReviewRow(
            emoji: '📅',
            label: 'Sana',
            value: _dateStr,
            color: color,
          ),
          if (reviewNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ReviewRow(
              emoji: '💬',
              label: 'Izoh',
              value: reviewNote,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;

  const _ReviewRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _LC.muted),
          ),
        ),
        Expanded(
          child: Text(
            '$emoji $value',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}

// Talaba kiritgan to'lov sanasi / summasi kabi ma'lumotlarni ko'rsatish uchun chip
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _LC.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _LC.faint),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _LC.purple),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9.5, color: _LC.muted),
                ),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _LC.ink),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
