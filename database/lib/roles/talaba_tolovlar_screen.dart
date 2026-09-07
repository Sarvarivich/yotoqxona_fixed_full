import 'dart:io';
import '../modules/services/supabase_storage_service.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../modules/models/user_model.dart';

// ─── ✅ Firebase Storage endi ishlatilmaydi (loyiha Spark/bepul tarifda,
// Storage esa Blaze tarifini talab qiladi). Shu sabab chek fayli
// to'g'ridan-to'g'ri Firestore hujjatiga base64 matn sifatida
// saqlanadi. Firestore hujjat chegarasi 1MB bo'lgani uchun
// fayl hajmi cheklab qo'yilgan (pastga qarang: _maxFileSizeBytes).
const int _maxFileSizeBytes = 3 * 1024 * 1024; // 3 MB

// ✅ Talaba uchun To'lovlar bo'limi.
// "Tez harakatlar" dagi "To'lov qilish" tugmasi shu sahifaga olib boradi.
// Talaba bu yerda to'lov chekini yuklaydi va o'z cheklarining holatini kuzatadi.

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

class TalabaTolovlarScreen extends StatefulWidget {
  final UserModel? user;
  const TalabaTolovlarScreen({super.key, required this.user});

  @override
  State<TalabaTolovlarScreen> createState() => _TalabaTolovlarScreenState();
}

class _TalabaTolovlarScreenState extends State<TalabaTolovlarScreen> {
  bool _isUploading = false;
  DateTime? _selectedDate;
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickPaymentDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _C.violet,
              onPrimary: Colors.white,
              surface: _C.bgCard,
              onSurface: _C.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickPaymentCheck() async {
    try {
      // ✅ withData: true — fayl baytlarini bevosita shu yerda olamiz.
      // Bu Android'dagi ba'zi fayl menejerlari (Google Drive va h.k.)
      // haqiqiy fayl yo'lini (path) emas, faqat "content URI" qaytarganda
      // ham ishlashini kafolatlaydi — chunki bytes har doim mavjud bo'ladi.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
        withData: true,
      );

      if (result == null) {
        // Foydalanuvchi picker'ni bekor qildi — bu normal holat, xato emas.
        return;
      }

      final picked = result.files.single;
      Uint8List? bytes = picked.bytes;

      // ⚠️ Web'da `path` xususiyati mavjud emas — unga tegib ko'rishning
      // o'zi xatolik chiqaradi. Shu sabab uni faqat web BO'LMAGANDA
      // ishlatamiz.
      String? path;
      if (!kIsWeb) {
        path = picked.path;
        if (bytes == null && path != null) {
          bytes = await File(path).readAsBytes();
        }
      }

      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text("Fayl o'qilmadi. Iltimos, boshqa fayl tanlab ko'ring."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedFileBytes = bytes;
        _selectedFilePath = path;
        _selectedFileName = picked.name;
      });
    } catch (e) {
      // ✅ Xatolikni endi yutib yubormaymiz — foydalanuvchi nima
      // bo'lganini ko'rishi kerak (masalan ruxsat berilmagan bo'lsa).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Fayl tanlashda xatolik: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendSelectedCheckToFinance() async {
    final user = widget.user;
    if (user == null) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Iltimos, to'lov sanasini tanlang"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || double.tryParse(amountText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Iltimos, to'lov summasini to'g'ri kiriting"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final double amount = double.parse(amountText);

    if (_selectedFileBytes == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Iltimos, chek faylini yuklang"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final bytes = _selectedFileBytes!;

      // ✅ Storage o'rniga faylni base64 shaklida Firestore'ga saqlaymiz —
      // shuning uchun hajmi cheklangan bo'lishi kerak.
      if (bytes.length > _maxFileSizeBytes) {
        throw Exception(
          "Fayl juda katta (${(bytes.length / 1024).round()} KB). "
          "Iltimos, ${(_maxFileSizeBytes / 1024).round()} KB dan kichik "
          "fayl (masalan siqilgan rasm) yuklang.",
        );
      }

      // ✅ Faylni Supabase Storage'ga yuklaymiz va havolasini olamiz.
      final upload = await SupabaseStorageService.instance.uploadPaymentCheck(
        bytes: bytes,
        fileName: _selectedFileName!,
        studentId: user.id,
      );

      final fileUrl = upload["publicUrl"]!;
      final filePath = upload["path"]!;
      final fileType = _selectedFileName!.split('.').last.toLowerCase();

      // ✅ Chek haqidagi ma'lumotni Firestore'ga yozamiz — aynan shu yozuv
      // yo'qligi sababli chek talaba/moliya/admin/super admin sahifalarida
      // hech qayerda ko'rinmayotgan edi.
      // ℹ️ Moliya ekrani (tolov_cheklari_screen.dart) rasmni/faylni
      // 'publicUrl' va 'fileType' maydonlaridan o'qiydi — shu nomlar bilan
      // mos yozamiz, aks holda chek ro'yxatda ko'rinsa ham fayl ochilmaydi.
      final checkDoc =
          await FirebaseFirestore.instance.collection('tolov_cheklari').add({
        'studentId': user.id,
        'studentName': user.fullName,
        // ⚠️ "hostel" maydoni bo'lmagani sababli, "To'lov cheklari"
        // bo'limida o'g'il/qiz bolalar bo'yicha alohida-alohida
        // ko'rsatib bo'lmas edi. Endi talabaning o'z yotoqxonasi
        // shu yerda saqlanadi.
        'hostel': user.hostel ?? 'boys',
        'amount': amount,
        'fileName': _selectedFileName!,
        'fileUrl': fileUrl,
        'publicUrl': fileUrl,
        'fileType': fileType,
        'storagePath': filePath,
        'paymentDate': Timestamp.fromDate(_selectedDate!),
        'status': 'pending',
        'sentToFinance': true,
        'uploadedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _notifyFinanceOfNewCheck(
        studentName: user.fullName,
        checkId: checkDoc.id,
      );

      if (mounted) {
        setState(() {
          _selectedDate = null;
          _selectedFilePath = null;
          _selectedFileBytes = null;
          _selectedFileName = null;
          _amountController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Chek moliya bo'limiga yuborildi"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ✅ Talaba "Moliya bo'limiga yuborish" tugmasini bosganda chaqiriladi.
  // ✅ Talaba chekni moliya bo'limiga yuborganda ("pending" holatiga
  // o'tganda), tizimdagi barcha "moliyachi" rolidagi xodimlarga
  // real-time bildirishnoma yuboriladi — ular allaqachon
  // "bildirishnomalar" ekranida (Firestore stream orqali) buni ko'radi.
  Future<void> _notifyFinanceOfNewCheck({
    required String studentName,
    required String checkId,
  }) async {
    try {
      final financeStaff = await FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .where('role', isEqualTo: 'moliyachi')
          .get();
      if (financeStaff.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final staff in financeStaff.docs) {
        final ref =
            FirebaseFirestore.instance.collection('bildirishnomalar').doc();
        batch.set(ref, {
          'userId': staff.id,
          'title': "Yangi to'lov cheki keldi 🧾",
          'body': "$studentName tomonidan yangi to'lov cheki yuborildi.",
          'type': 'new_payment_check',
          'checkId': checkId,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {
      // Bildirishnoma yuborilmasa ham chekning o'zi saqlanib qoladi —
      // shu sabab xatolikni talabaga ko'rsatmaymiz.
    }
  }

  // Chekning statusini "draft"dan "pending"ga o'zgartiradi — shu payt
  // chek moliya (va mudir/admin) rolidagi "Murojaatlar" bo'limida
  // ko'rina boshlaydi.
  Future<void> _sendToFinance(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('tolov_cheklari')
          .doc(docId)
          .update({
        'status': 'pending',
        'sentToFinance': true,
        'sentAt': FieldValue.serverTimestamp(),
      });
      await _notifyFinanceOfNewCheck(
        studentName: widget.user?.fullName ?? "Talaba",
        checkId: docId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Chek moliya bo'limiga yuborildi"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.user?.id;

    return Scaffold(
      backgroundColor: _C.bgBase,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const Text(
                    "To'lovlar",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _C.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // 📅 To'lov sanasi
                  GestureDetector(
                    onTap: _isUploading ? null : _pickPaymentDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _C.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _C.faint),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _C.violet.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.event_rounded,
                                color: _C.violet, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "To'lov sanasi",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _C.white.withOpacity(0.45),
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedDate == null
                                      ? "Sanani tanlang"
                                      : "${_selectedDate!.day.toString().padLeft(2, '0')}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.year}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedDate == null
                                        ? _C.muted
                                        : _C.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: _C.muted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 💵 To'lov summasi
                  TextField(
                    controller: _amountController,
                    enabled: !_isUploading,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: _C.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "To'lov summasi (so'm)",
                      labelStyle: TextStyle(color: _C.white.withOpacity(0.45)),
                      filled: true,
                      fillColor: _C.bgCard,
                      prefixIcon:
                          const Icon(Icons.payments_rounded, color: _C.violet),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _C.faint),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _C.violet),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _isUploading ? null : _pickPaymentCheck,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_C.teal, _C.mint],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _C.teal.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isUploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Chekni yuklash",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            if (_selectedFileName != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _C.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.faint),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _C.mint.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.attach_file_rounded,
                            color: _C.mint, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFileName!,
                          style: const TextStyle(
                            color: _C.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: "Faylni almashtirish",
                        onPressed: _isUploading ? null : _pickPaymentCheck,
                        icon: const Icon(Icons.edit_rounded,
                            color: _C.violet, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isUploading ? null : _sendSelectedCheckToFinance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                    label: Text(
                      _isUploading ? "Yuborilmoqda..." : "Moliyaga yuborish",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    "Mening cheklarim",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: userId == null
                  ? Center(
                      child: Text(
                        'Foydalanuvchi topilmadi',
                        style: TextStyle(color: _C.muted),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('tolov_cheklari')
                          .where('studentId', isEqualTo: userId)
                          .orderBy('uploadedAt', descending: true)
                          .snapshots(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: _C.violet),
                          );
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                "Cheklarni yuklashda xatolik: ${snap.error}",
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: _C.muted, fontSize: 12.5),
                              ),
                            ),
                          );
                        }
                        final docs = snap.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 56, color: _C.muted),
                                const SizedBox(height: 12),
                                Text(
                                  "Hali to'lov cheki yuborilmagan",
                                  style:
                                      TextStyle(color: _C.muted, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final doc = docs[i];
                            final d = doc.data() as Map<String, dynamic>;
                            return _PaymentCheckCard(
                              data: d,
                              onSendToFinance: () => _sendToFinance(doc.id),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCheckCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onSendToFinance;
  const _PaymentCheckCard({required this.data, this.onSendToFinance});

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'pending') as String;
    final fileName = (data['fileName'] ?? 'fayl') as String;

    final statusColor = status == 'approved'
        ? _C.mint
        : status == 'rejected'
            ? _C.pink
            : status == 'draft'
                ? _C.muted
                : _C.orange;
    final statusLabel = status == 'approved'
        ? 'Tasdiqlandi'
        : status == 'rejected'
            ? 'Rad etildi'
            : status == 'draft'
                ? 'Yuborilmagan'
                : 'Kutilmoqda';
    final statusIcon = status == 'approved'
        ? Icons.check_circle_outline
        : status == 'rejected'
            ? Icons.cancel_outlined
            : status == 'draft'
                ? Icons.drafts_outlined
                : Icons.hourglass_empty_outlined;

    final ts = data['uploadedAt'];
    String dateStr = '—';
    if (ts != null) {
      try {
        final dt = (ts as dynamic).toDate() as DateTime;
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
        border: Border.all(
          color: status == 'draft' ? _C.orange.withOpacity(0.4) : _C.faint,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _C.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: _C.muted),
                    ),
                    if (data['paymentDate'] != null ||
                        data['amount'] != null) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          if (data['paymentDate'] != null)
                            Builder(builder: (_) {
                              String pd = '—';
                              try {
                                final dt = (data['paymentDate'] as dynamic)
                                    .toDate() as DateTime;
                                pd =
                                    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
                              } catch (_) {}
                              return Text(
                                "To'lov sanasi: $pd",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _C.white.withOpacity(0.6)),
                              );
                            }),
                          if (data['amount'] != null)
                            Text(
                              "Summa: ${data['amount']} so'm",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _C.white.withOpacity(0.6)),
                            ),
                        ],
                      ),
                    ],
                    if ((status == 'approved' || status == 'rejected')) ...[
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        final reviewedBy =
                            (data['reviewedBy'] as String?) ?? '';
                        final rts = data['reviewedAt'];
                        String reviewedDate = '';
                        if (rts != null) {
                          try {
                            final dt = (rts as dynamic).toDate() as DateTime;
                            reviewedDate =
                                '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
                          } catch (_) {}
                        }
                        if (reviewedBy.isEmpty && reviewedDate.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final label =
                            status == 'approved' ? 'Tasdiqlagan' : 'Rad etgan';
                        return Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            children: [
                              if (reviewedBy.isNotEmpty)
                                Text(
                                  '👤 $label: $reviewedBy',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor),
                                ),
                              if (reviewedDate.isNotEmpty)
                                Text(
                                  '📅 Sana: $reviewedDate',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _C.white.withOpacity(0.6)),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (status == 'rejected' &&
                        (data['reviewNote'] as String?)?.isNotEmpty ==
                            true) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Sabab: ${data['reviewNote']}',
                        style: const TextStyle(fontSize: 11, color: _C.pink),
                      ),
                    ],
                    if (status == 'approved' &&
                        (data['reviewNote'] as String?)?.isNotEmpty ==
                            true) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Izoh: ${data['reviewNote']}',
                        style: TextStyle(
                            fontSize: 11, color: _C.mint.withOpacity(0.9)),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          // ✅ Chek hali moliya bo'limiga yuborilmagan bo'lsa,
          // talaba shu tugma orqali yuboradi.
          if (status == 'draft' && onSendToFinance != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSendToFinance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 16),
                label: const Text(
                  "Moliya bo'limiga yuborish",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
