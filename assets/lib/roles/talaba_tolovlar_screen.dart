import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../modules/services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import '../modules/models/user_model.dart';
import '../modules/services/file.opener.dart';

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
            backgroundColor: Colors.orange),
      );
      return;
    }

    final amount =
        double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Iltimos, to'lov summasini to'g'ri kiriting"),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (_selectedFileBytes == null || _selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Iltimos, chek faylini yuklang"),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (user.roomId == null || user.roomId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Sizga xona biriktirilmagan"),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Sessiya tugagan. Qaytadan login qiling.');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/payments'),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['room_id'] = user.roomId!;
      request.fields['amount'] = amount.toString();
      request.fields['method'] = 'bank';
      request.fields['period'] =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}';
      request.fields['note'] = "Talaba tomonidan chek yuborildi";
      request.fields['payment_date'] = _selectedDate!.toIso8601String();
      request.files.add(
        http.MultipartFile.fromBytes(
          'receipt',
          _selectedFileBytes!,
          filename: _selectedFileName!,
        ),
      );

      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server ${response.statusCode}: ${response.body}');
      }

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
              backgroundColor: Colors.green),
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

  Future<void> _downloadContract() async {
    final user = widget.user;
    if (user == null || !user.hasRoom) return;

    final roomNumber = user.roomId ?? '—';
    final hostelName = user.hostelDisplayName;
    final social = user.additionalData?['hasSocialBenefit'] == true;
    final text = '''
YOTOQXONA JOYLASHISH SHARTNOMASI

Talaba: ${user.fullName}
Student ID: ${user.studentId ?? '—'}
JSHSHIR: ${user.jshshir ?? '—'}
Yotoqxona: $hostelName
Xona: $roomNumber
Fakultet: ${user.faculty ?? '—'}
Kurs: ${user.course ?? '—'}
Ijtimoiy holat: ${social ? 'Ha' : 'Yo‘q'}

Mazkur elektron hujjat yotoqxona tizimida talaba uchun ajratilgan
joy va to‘lov majburiyatlarini tasdiqlash uchun shakllantirildi.

Ariza holati: Yotoqxona ajratilgan.
''';

    final result = await openOrDownloadFile(
      Uint8List.fromList(utf8.encode(text)),
      'yotoqxona_shartnomasi_${user.fullName.replaceAll(' ', '_')}.txt',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result ?? 'Shartnoma yuklab olindi.'),
        backgroundColor: result == null ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (user == null || !user.hasRoom) {
      return const Scaffold(
        backgroundColor: _C.bgBase,
        body: Center(
          child: Text(
            "Yotoqxonaga biriktirilmaguningizcha to‘lovlar bo‘limi mavjud emas.",
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    final userId = user.id;

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
                  const Expanded(
                    child: Text(
                      "Hozirgi to'lovlar",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _C.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _downloadContract,
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Shartnoma'),
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
              child: FutureBuilder<List<dynamic>>(
                future: ApiService().getPayments(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: _C.violet));
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "Cheklarni yuklashda xatolik: ${snap.error}",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _C.muted, fontSize: 12.5),
                        ),
                      ),
                    );
                  }
                  final payments = snap.data ?? const <dynamic>[];
                  if (payments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 56, color: _C.muted),
                          const SizedBox(height: 12),
                          Text("Hali to'lov cheki yuborilmagan",
                              style: TextStyle(color: _C.muted, fontSize: 13)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    itemCount: payments.length,
                    itemBuilder: (context, i) {
                      final p = Map<String, dynamic>.from(payments[i] as Map);
                      final data = <String, dynamic>{
                        ...p,
                        'fileName':
                            p['file_name'] ?? p['fileName'] ?? 'To‘lov cheki',
                        'uploadedAt': p['created_at'] ?? p['createdAt'],
                        'paymentDate': p['payment_date'] ?? p['paymentDate'],
                        'reviewedBy': p['reviewed_by'] ?? p['reviewedBy'],
                        'reviewedAt': p['reviewed_at'] ?? p['reviewedAt'],
                        'reviewNote':
                            p['note'] ?? p['review_note'] ?? p['reviewNote'],
                        'status': p['paid_at'] != null
                            ? 'approved'
                            : (p['status'] ?? 'pending'),
                      };
                      return _PaymentCheckCard(data: data);
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _PaymentCheckCard extends StatelessWidget {
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  final Map<String, dynamic> data;
  final VoidCallback? onSendToFinance;
  // FIX: 'onSendToFinance' avval konstruktorda yo'q edi (final maydon
  // hech qachon qiymat olmasdi, shuning uchun Dart analyzer buni xato
  // deb ko'rsatib turgan edi). Endi 'this.onSendToFinance' qo'shildi —
  // ixtiyoriy (nullable) bo'lgani uchun 'required' emas.
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

    final uploadedDt = _parseDate(data['uploadedAt']);
    final dateStr = uploadedDt == null
        ? '—'
        : '${uploadedDt.day.toString().padLeft(2, '0')}.${uploadedDt.month.toString().padLeft(2, '0')}.${uploadedDt.year}';

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
                              final paymentDt = _parseDate(data['paymentDate']);
                              final pd = paymentDt == null
                                  ? '—'
                                  : '${paymentDt.day.toString().padLeft(2, '0')}.${paymentDt.month.toString().padLeft(2, '0')}.${paymentDt.year}';
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
                        final reviewedDt = _parseDate(rts);
                        final reviewedDate = reviewedDt == null
                            ? ''
                            : '${reviewedDt.day.toString().padLeft(2, '0')}.${reviewedDt.month.toString().padLeft(2, '0')}.${reviewedDt.year}';
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
