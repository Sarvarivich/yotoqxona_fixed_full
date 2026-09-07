import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../../services/supabase_storage_service.dart';
import '../../providers/girls_payment_provider.dart';
import '../../providers/girls_student_provider.dart';
import '../../services/girl_student_model.dart';
import '../../services/girls_payment_model.dart';
import '../../theme/girls_theme.dart';

// ─── AddGirlsPaymentScreen: yangi to'lov qo'shish, ixtiyoriy ravishda
// to'lov cheki (rasm/pdf) biriktirish bilan.
class AddGirlsPaymentScreen extends StatefulWidget {
  final UserModel? currentUser;
  const AddGirlsPaymentScreen({super.key, this.currentUser});

  @override
  State<AddGirlsPaymentScreen> createState() => _AddGirlsPaymentScreenState();
}

class _AddGirlsPaymentScreenState extends State<AddGirlsPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _monthCtrl = TextEditingController(text: _defaultMonth());
  final _noteCtrl = TextEditingController();

  String? _studentId;
  String? _studentName;
  GirlsPaymentMethod _method = GirlsPaymentMethod.naqd;
  GirlsPaymentStatus _status = GirlsPaymentStatus.pending;

  Uint8List? _receiptBytes;
  String? _receiptFileName;
  bool _isSaving = false;

  static String _defaultMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _monthCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _receiptBytes = file.bytes;
      _receiptFileName = file.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Talabani tanlang'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      String? receiptUrl;
      String? receiptPath;

      if (_receiptBytes != null && _receiptFileName != null) {
        final uploaded =
            await SupabaseStorageService.instance.uploadPaymentCheck(
          bytes: _receiptBytes!,
          studentId: _studentId!,
          fileName: _receiptFileName!,
        );
        receiptUrl = uploaded['publicUrl'];
        receiptPath = uploaded['path'];
      }

      final payment = GirlsPaymentModel(
        id: '',
        studentId: _studentId!,
        studentName: _studentName ?? '',
        amount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
        month: _monthCtrl.text.trim(),
        status: _status,
        method: _method,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        receiptUrl: receiptUrl,
        receiptPath: receiptPath,
        createdBy: widget.currentUser?.fullName ?? 'Administratsiya',
        createdAt: DateTime.now(),
        paidAt: _status == GirlsPaymentStatus.paid ? DateTime.now() : null,
      );
      await context.read<GirlsPaymentProvider>().add(payment);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("To'lov qo'shildi"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GTheme.bgBase,
      appBar: AppBar(
        backgroundColor: GTheme.bgBase,
        elevation: 0,
        title: const Text("To'lov qo'shish",
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              StreamBuilder<List<GirlStudentModel>>(
                stream: context.read<GirlsStudentProvider>().students,
                builder: (context, snapshot) {
                  final List<GirlStudentModel> students =
                      snapshot.data ?? <GirlStudentModel>[];
                  return DropdownButtonFormField<String>(
                    initialValue: _studentId,
                    dropdownColor: GTheme.bgCard2,
                    style: const TextStyle(color: Colors.white),
                    decoration: GTheme.inputDecoration('Talabani tanlang',
                        icon: Icons.person_outline_rounded),
                    items: students
                        .map<DropdownMenuItem<String>>(
                          (GirlStudentModel s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) {
                      if (v == null) return;
                      final GirlStudentModel s = students
                          .firstWhere((GirlStudentModel e) => e.id == v);
                      setState(() {
                        _studentId = v;
                        _studentName = s.fullName;
                      });
                    },
                    validator: (v) => v == null ? 'Talabani tanlang' : null,
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: GTheme.inputDecoration('Summa (so\'m)',
                          icon: Icons.payments_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Summani kiriting'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _monthCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: GTheme.inputDecoration('Oy (YYYY-MM)',
                          icon: Icons.calendar_month_outlined),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Oyni kiriting'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<GirlsPaymentMethod>(
                initialValue: _method,
                dropdownColor: GTheme.bgCard2,
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration("To'lov usuli",
                    icon: Icons.credit_card_outlined),
                items: GirlsPaymentMethod.values
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m.displayName)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _method = v ?? GirlsPaymentMethod.naqd),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<GirlsPaymentStatus>(
                initialValue: _status,
                dropdownColor: GTheme.bgCard2,
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration('Holati',
                    icon: Icons.info_outline_rounded),
                items: GirlsPaymentStatus.values
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s.displayName)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _status = v ?? GirlsPaymentStatus.pending),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: GTheme.inputDecoration('Izoh (ixtiyoriy)',
                    icon: Icons.notes_rounded),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickReceipt,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: GTheme.cardDecoration(),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          color: GTheme.pink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _receiptFileName ??
                              "To'lov chekini biriktirish (ixtiyoriy)",
                          style: TextStyle(
                              color: GTheme.white.withOpacity(0.7),
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.upload_file_rounded,
                          color: GTheme.violet, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GTheme.pink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Saqlash',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
