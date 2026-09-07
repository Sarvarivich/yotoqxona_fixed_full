import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart' show kFaculties;
import '../../providers/girls_student_provider.dart';
import '../../services/girl_student_model.dart';
import '../../theme/girls_theme.dart';

// ─── AddGirlStudentScreen: yangi qiz talaba qo'shish formasi.
class AddGirlStudentScreen extends StatefulWidget {
  const AddGirlStudentScreen({super.key});

  @override
  State<AddGirlStudentScreen> createState() => _AddGirlStudentScreenState();
}

class _AddGirlStudentScreenState extends State<AddGirlStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _faculty;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _courseCtrl.dispose();
    _groupCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final student = GirlStudentModel(
        id: '',
        fullName: _fullNameCtrl.text.trim(),
        faculty: _faculty ?? kFaculties.first,
        course: _courseCtrl.text.trim(),
        group: _groupCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        // Xonaga biriktirish endi bu formadan olib tashlandi — talaba
        // qo'shilgandan so'ng, "Xonalar" bo'limidan biriktiriladi.
        roomId: '',
        imageUrl: '',
        isActive: _isActive,
        createdAt: DateTime.now(),
      );
      await context.read<GirlsStudentProvider>().add(student);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Talaba muvaffaqiyatli qo'shildi"),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GTheme.bgBase,
      appBar: AppBar(
        backgroundColor: GTheme.bgBase,
        elevation: 0,
        title: const Text("Talaba qo'shish",
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TextFormField(
                controller: _fullNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration("To'liq ismi (F.I.Sh)",
                    icon: Icons.badge_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ism kiriting' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _faculty,
                dropdownColor: GTheme.bgCard2,
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration('Fakultet',
                    icon: Icons.school_outlined),
                items: kFaculties
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _faculty = v),
                validator: (v) => v == null ? 'Fakultetni tanlang' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _courseCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: GTheme.inputDecoration('Kurs',
                          icon: Icons.numbers_rounded),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Kursni kiriting'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _groupCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: GTheme.inputDecoration('Guruh (ixtiyoriy)',
                          icon: Icons.groups_2_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: GTheme.inputDecoration('Telefon raqami',
                    icon: Icons.phone_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Telefon kiriting' : null,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeThumbColor: GTheme.pink,
                title: const Text('Faol talaba',
                    style: TextStyle(color: Colors.white)),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GTheme.pink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
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
