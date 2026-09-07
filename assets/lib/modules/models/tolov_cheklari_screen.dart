import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/file.opener.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Future<void> _showApproveDialog(String docId, String studentId,
      String studentName, Map<String, dynamic> checkData) async {
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
            Text('$studentName ning cheki tasdiqlanadi.'),
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Orqaga'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _LC.teal),
            icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
            label:
                const Text('Tasdiqlash', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _approve(docId, studentId, studentName, checkData);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _approve(String docId, String studentId, String studentName,
      Map<String, dynamic> checkData) async {
    final note = _noteCtrl.text.trim().isNotEmpty
        ? _noteCtrl.text.trim()
        : "To'lov tasdiqlandi";
    final now = FieldValue.serverTimestamp();
    final batch = FirebaseFirestore.instance.batch();

    final checkRef =
        FirebaseFirestore.instance.collection('tolov_cheklari').doc(docId);
    batch.update(checkRef, {
      'status': 'approved',
      'reviewedAt': now,
      'reviewedBy': _reviewerName,
      'reviewNote': note,
    });

    // To'lov tasdiqlansa, ariza jarayonining 5-bosqichi yakunlandi.
    batch.update(
      FirebaseFirestore.instance.collection('foydalanuvchilar').doc(studentId),
      {
        'applicationStep': 5,
        'applicationStatus': 'completed',
        'paymentApprovedAt': now,
      },
    );

    // 💰 MUHIM: chekni tasdiqlash faqat 'tolov_cheklari' hujjatining
    // holatini o'zgartirar edi — bu summa "Daromad hisoboti"da HECH
    // QACHON ko'rinmasdi, chunki o'sha hisobot butunlay boshqa
    // to'plamlardan ('tolovlar' — o'g'il bolalar, 'girls_payments' —
    // qiz bolalar) o'qiydi. Endi tasdiqlash paytida shu to'plamlarga ham
    // mos yozuv qo'shiladi, shunda summasi darhol "Daromad hisoboti"
    // grafigi va kartalarida (jonli) ko'rinadi.
    final amount = (checkData['amount'] as num?)?.toDouble() ?? 0.0;
    final hostel = (checkData['hostel'] as String?) ?? 'boys';
    final rawPaymentDate = checkData['paymentDate'];
    DateTime paymentDate = DateTime.now();
    if (rawPaymentDate is Timestamp) paymentDate = rawPaymentDate.toDate();

    if (hostel == 'girls') {
      final month =
          "${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}";
      final girlsPaymentRef =
          FirebaseFirestore.instance.collection('girls_payments').doc();
      batch.set(girlsPaymentRef, {
        'studentId': studentId,
        'studentName': studentName,
        'roomId': checkData['roomId'],
        'amount': amount,
        'month': month,
        'status': 'paid',
        'method': 'otkazma',
        'note': note,
        'receiptUrl': checkData['fileUrl'] ?? checkData['publicUrl'],
        'receiptPath': checkData['storagePath'],
        'createdBy': _reviewerName,
        'createdAt': now,
        'paidAt': now,
        // 📎 Qaysi 'tolov_cheklari' hujjatidan yaratilganini bilish uchun.
        'sourceCheckId': docId,
      });
    } else {
      final tolovRef = FirebaseFirestore.instance.collection('tolovlar').doc();
      batch.set(tolovRef, {
        'studentId': studentId,
        'studentName': studentName,
        'hostel': hostel,
        'amount': amount,
        'date': Timestamp.fromDate(paymentDate),
        'method': 'otkazma',
        'note': note,
        'reviewedBy': _reviewerName,
        'receiptUrl': checkData['fileUrl'] ?? checkData['publicUrl'],
        'createdAt': now,
        // 📎 Qaysi 'tolov_cheklari' hujjatidan yaratilganini bilish uchun.
        'sourceCheckId': docId,
      });
    }

    await batch.commit();

    await _notifyStudent(
      studentId: studentId,
      title: 'To\'lov cheki tasdiqlandi ✓',
      body: 'Siz yuborgan to\'lov cheki admin tomonidan tasdiqlandi.',
      checkId: docId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$studentName cheki tasdiqlandi'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _showRejectDialog(
      String docId, String studentId, String studentName) async {
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
            Text('$studentName ning cheki bekor qilinadi.'),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Sabab (ixtiyoriy)',
                hintText: 'Masalan: chek rasmiy emas, summa xato...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Orqaga'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
            label: const Text('Bekor qilish',
                style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              final rejectBatch = FirebaseFirestore.instance.batch();
              rejectBatch.update(
                FirebaseFirestore.instance
                    .collection('tolov_cheklari')
                    .doc(docId),
                {
                  'status': 'rejected',
                  'reviewedAt': FieldValue.serverTimestamp(),
                  'reviewedBy': _reviewerName,
                  'reviewNote': _noteCtrl.text.trim(),
                },
              );
              rejectBatch.update(
                FirebaseFirestore.instance
                    .collection('foydalanuvchilar')
                    .doc(studentId),
                {
                  'applicationStep': 3,
                  'applicationStatus': 'assigned',
                },
              );
              await rejectBatch.commit();
              await _notifyStudent(
                studentId: studentId,
                title: 'To\'lov cheki rad etildi ✗',
                body: _noteCtrl.text.trim().isNotEmpty
                    ? 'Chekingiz rad etildi. Sabab: ${_noteCtrl.text.trim()}'
                    : 'Siz yuborgan to\'lov cheki rad etildi. Iltimos, qayta yuboring.',
                checkId: docId,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('$studentName cheki rad etildi'),
                      backgroundColor: Colors.red),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _notifyStudent({
    required String studentId,
    required String title,
    required String body,
    required String checkId,
  }) async {
    await FirebaseFirestore.instance.collection('bildirishnomalar').add({
      'userId': studentId,
      'title': title,
      'body': body,
      'type': 'payment_check_result',
      'checkId': checkId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ✅ Fayl endi Firebase Storage'da emas, Firestore hujjatida base64
  // matn sifatida saqlanadi. Platformaga qarab (web yoki mobil/desktop)
  // to'g'ri usulda ochiladi/yuklab olinadi (file_opener.dart orqali).
  Future<void> _downloadCheck(String fileBase64, String fileName) async {
    try {
      final bytes = base64Decode(fileBase64);
      final error = await openOrDownloadFile(bytes, fileName);
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Faylni ochishda xatolik: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tolov_cheklari')
          .where('status', isEqualTo: status)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // ✅ Avval xatolikni tekshiramiz — aks holda Firestore so'rovi
        // (masalan, kerakli composite index yo'qligi sababli) xatolik
        // bersa, ekran "cheklar yo'q" deb ko'rsatib, chekni yashirib
        // qo'yardi. Endi xatolik aniq ko'rsatiladi.
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 56, color: _LC.coral),
                  const SizedBox(height: 12),
                  Text(
                    "Cheklarni yuklashda xatolik: ${snap.error}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _LC.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Agar xabarda 'index' so'zi bo'lsa, Firebase konsolida "
                    "havolani ochib composite index yarating.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _LC.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }
        final allDocs = snap.data?.docs ?? [];

        // 🚻 Tanlangan yotoqxona bo'yicha filtrlaymiz. "hostel" maydoni
        // yo'q/bo'sh eski cheklar (bu maydon qo'shilishidan oldin
        // yuborilgan) boshqa bo'limlardagi kabi "boys" ga tegishli deb
        // hisoblanadi.
        final docs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final hostel = (d['hostel'] ?? '').toString().trim().toLowerCase();
          final normalized = hostel.isEmpty ? 'boys' : hostel;
          return normalized == _selectedHostel;
        }).toList();

        // 🔎 Talaba ismi YOKI sana (yuklangan sana / to'lov sanasi,
        // dd.mm.yyyy ko'rinishida) bo'yicha mahalliy filtrlash
        final filteredDocs = _searchQuery.isEmpty
            ? docs
            : docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final studentName =
                    (d['studentName'] ?? '').toString().toLowerCase();
                if (studentName.contains(_searchQuery)) return true;

                String fmt(dynamic ts) {
                  if (ts == null) return '';
                  try {
                    final dt = (ts as dynamic).toDate() as DateTime;
                    final dd = dt.day.toString().padLeft(2, '0');
                    final mm = dt.month.toString().padLeft(2, '0');
                    return '$dd.$mm.${dt.year}';
                  } catch (_) {
                    return '';
                  }
                }

                final uploadedStr = fmt(d['uploadedAt']);
                final paymentStr = fmt(d['paymentDate']);
                return uploadedStr.contains(_searchQuery) ||
                    paymentStr.contains(_searchQuery);
              }).toList();

        if (filteredDocs.isEmpty) {
          final noResultsForSearch = _searchQuery.isNotEmpty;
          final hostelLabel =
              _selectedHostel == "boys" ? "O'g'il bolalar" : "Qiz bolalar";
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  noResultsForSearch
                      ? Icons.search_off_rounded
                      : status == 'pending'
                          ? Icons.hourglass_empty
                          : status == 'approved'
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  noResultsForSearch
                      ? "\"$_searchQuery\" bo'yicha chek topilmadi"
                      : status == 'pending'
                          ? "$hostelLabel: kutilayotgan cheklar yo'q"
                          : status == 'approved'
                              ? "$hostelLabel: tasdiqlangan cheklar yo'q"
                              : "$hostelLabel: rad etilgan cheklar yo'q",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, i) {
            final doc = filteredDocs[i];
            final d = doc.data() as Map<String, dynamic>;
            return _buildCheckCard(doc.id, d, status);
          },
        );
      },
    );
  }

  Widget _buildCheckCard(String docId, Map<String, dynamic> d, String status) {
    final studentName = (d['studentName'] ?? 'Noma\'lum talaba') as String;
    final fileName = (d['fileName'] ?? 'fayl') as String;
    final fileType = (d['fileType'] ?? 'pdf') as String;
    final fileUrl = (d['fileUrl'] ?? '') as String;
    final isPdf = fileType.toLowerCase() == 'pdf';
    final isImage =
        ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(fileType.toLowerCase());

    final ts = d['uploadedAt'];
    String dateStr = '—';
    if (ts != null) {
      try {
        final dt = (ts as dynamic).toDate() as DateTime;
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    final statusColor = status == 'approved'
        ? _LC.teal
        : status == 'rejected'
            ? _LC.coral
            : _LC.orange;

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
            offset: const Offset(0, 6),
          ),
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
                    gradient: const LinearGradient(
                      colors: [_LC.purple, _LC.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
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
                      Text(dateStr,
                          style:
                              const TextStyle(fontSize: 12, color: _LC.muted)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
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
            // 💰 To'lov sanasi va summasi — talaba kiritgan ma'lumotlar
            if (d['paymentDate'] != null || d['amount'] != null) ...[
              Row(
                children: [
                  if (d['paymentDate'] != null)
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.event_rounded,
                        label: "To'lov sanasi",
                        value: () {
                          try {
                            final dt = (d['paymentDate'] as dynamic).toDate()
                                as DateTime;
                            return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
                          } catch (_) {
                            return '—';
                          }
                        }(),
                      ),
                    ),
                  if (d['paymentDate'] != null && d['amount'] != null)
                    const SizedBox(width: 10),
                  if (d['amount'] != null)
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.payments_rounded,
                        label: "To'lov summasi",
                        value: "${d['amount']} so'm",
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (isImage && fileUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  fileUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 100,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _LC.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _LC.faint),
              ),
              child: Row(
                children: [
                  Icon(
                    isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    color: isPdf ? _LC.coral : _LC.purple,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fileName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _LC.ink),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (fileUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _LC.purple,
                    side: BorderSide(color: _LC.purple.withOpacity(0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.file_download_rounded, size: 18),
                  label: const Text(
                    'Chekni yuklab olish',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse(fileUrl);

                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ),
            ],
            if (status == 'approved' || status == 'rejected') ...[
              const SizedBox(height: 10),
              _ReviewInfoBox(
                status: status,
                reviewedBy: (d['reviewedBy'] as String?) ?? '',
                reviewedAt: d['reviewedAt'],
                reviewNote: (d['reviewNote'] as String?) ?? '',
                color: statusColor,
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _LC.coral,
                        side: BorderSide(color: _LC.coral.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Rad etish'),
                      onPressed: () => _showRejectDialog(
                          docId, d['studentId'] as String, studentName),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _LC.teal,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('Tasdiqlash',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                      onPressed: () => _showApproveDialog(
                          docId, d['studentId'] as String, studentName, d),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Kutilmoqda tab uchun real-time badge
class _PendingBadge extends StatelessWidget {
  const _PendingBadge();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tolov_cheklari')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _LC.coral,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
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
    try {
      final dt = (reviewedAt as dynamic).toDate() as DateTime;
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return '—';
    }
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
