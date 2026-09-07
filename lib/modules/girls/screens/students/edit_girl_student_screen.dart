import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/room_model.dart';
import '../../../models/user_model.dart' show kFaculties;
import '../../providers/girls_room_provider.dart';
import '../../providers/girls_student_provider.dart';
import '../../services/girl_student_model.dart';
import '../../theme/girls_theme.dart';

// ─── EditGirlStudentScreen: mavjud qiz talaba ma'lumotlarini tahrirlash.
class EditGirlStudentScreen extends StatefulWidget {
  final GirlStudentModel student;
  const EditGirlStudentScreen({super.key, required this.student});

  @override
  State<EditGirlStudentScreen> createState() => _EditGirlStudentScreenState();
}

class _EditGirlStudentScreenState extends State<EditGirlStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _courseCtrl;
  late final TextEditingController _groupCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _imageUrlCtrl;

  String? _faculty;
  String? _roomId;
  late bool _isActive;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _fullNameCtrl = TextEditingController(text: s.fullName);
    _courseCtrl = TextEditingController(text: s.course);
    _groupCtrl = TextEditingController(text: s.group);
    _phoneCtrl = TextEditingController(text: s.phone);
    _imageUrlCtrl = TextEditingController(text: s.imageUrl);
    _faculty = kFaculties.contains(s.faculty) ? s.faculty : null;
    _roomId = s.roomId.isNotEmpty ? s.roomId : null;
    _isActive = s.isActive;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _courseCtrl.dispose();
    _groupCtrl.dispose();
    _phoneCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final oldRoomId = widget.student.roomId;
      final updated = GirlStudentModel(
        id: widget.student.id,
        fullName: _fullNameCtrl.text.trim(),
        faculty: _faculty ?? widget.student.faculty,
        course: _courseCtrl.text.trim(),
        group: _groupCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        roomId: _roomId ?? '',
        imageUrl: _imageUrlCtrl.text.trim(),
        isActive: _isActive,
        createdAt: widget.student.createdAt,
      );
      await context.read<GirlsStudentProvider>().update(updated);

      final roomProvider = context.read<GirlsRoomProvider>();
      if (oldRoomId != (_roomId ?? '')) {
        if (oldRoomId.isNotEmpty) {
          await roomProvider.unassignStudent(oldRoomId, widget.student.id);
        }
        if (_roomId != null && _roomId!.isNotEmpty) {
          await roomProvider.assignStudent(_roomId!, widget.student.id);
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Ma'lumotlar yangilandi"),
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
        title: const Text('Talabani tahrirlash',
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
              const SizedBox(height: 14),
              StreamBuilder<List<RoomModel>>(
                stream: context.read<GirlsRoomProvider>().rooms,
                builder: (context, snapshot) {
                  final List<RoomModel> rooms = snapshot.data ?? <RoomModel>[];
                  final validValue = rooms.any((RoomModel r) => r.id == _roomId)
                      ? _roomId
                      : null;
                  return DropdownButtonFormField<String>(
                    initialValue: validValue,
                    dropdownColor: GTheme.bgCard2,
                    style: const TextStyle(color: Colors.white),
                    decoration: GTheme.inputDecoration('Xona (ixtiyoriy)',
                        icon: Icons.meeting_room_outlined),
                    items: rooms
                        .map<DropdownMenuItem<String>>(
                          (RoomModel r) => DropdownMenuItem<String>(
                            value: r.id,
                            child: Text(
                                '${r.roomNumber}-xona (${r.currentOccupants}/${r.capacity})'),
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) => setState(() => _roomId = v),
                  );
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _imageUrlCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration('Rasm havolasi (ixtiyoriy)',
                    icon: Icons.image_outlined),
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
                      : const Text('Yangilash',
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
