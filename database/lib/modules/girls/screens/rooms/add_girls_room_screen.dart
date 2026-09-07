import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/room_model.dart';
import '../../providers/girls_room_provider.dart';
import '../../theme/girls_theme.dart';

// ─── AddGirlsRoomScreen: yangi xona qo'shish yoki mavjudini tahrirlash
// (agar `room` uzatilsa — tahrirlash rejimi).
class AddGirlsRoomScreen extends StatefulWidget {
  final RoomModel? room;
  const AddGirlsRoomScreen({super.key, this.room});

  @override
  State<AddGirlsRoomScreen> createState() => _AddGirlsRoomScreenState();
}

class _AddGirlsRoomScreenState extends State<AddGirlsRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberCtrl;
  late final TextEditingController _floorCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _amenitiesCtrl;
  late final TextEditingController _notesCtrl;

  RoomStatus _status = RoomStatus.empty;
  bool _isLoading = false;

  bool get _isEdit => widget.room != null;

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _numberCtrl = TextEditingController(text: r?.roomNumber.toString() ?? '');
    _floorCtrl = TextEditingController(text: r?.floor.toString() ?? '');
    _capacityCtrl = TextEditingController(text: r?.capacity.toString() ?? '4');
    _priceCtrl = TextEditingController(text: r?.pricePerMonth.toStringAsFixed(0) ?? '');
    _amenitiesCtrl = TextEditingController(text: r?.amenities.join(', ') ?? '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    _status = r?.status ?? RoomStatus.empty;
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _floorCtrl.dispose();
    _capacityCtrl.dispose();
    _priceCtrl.dispose();
    _amenitiesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final amenities = _amenitiesCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final provider = context.read<GirlsRoomProvider>();

      if (_isEdit) {
        final updated = widget.room!.copyWith(
          roomNumber: int.tryParse(_numberCtrl.text.trim()) ?? widget.room!.roomNumber,
          floor: int.tryParse(_floorCtrl.text.trim()) ?? widget.room!.floor,
          capacity: int.tryParse(_capacityCtrl.text.trim()) ?? widget.room!.capacity,
          pricePerMonth:
              double.tryParse(_priceCtrl.text.trim()) ?? widget.room!.pricePerMonth,
          status: _status,
          amenities: amenities,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
        await provider.update(updated);
      } else {
        final newRoom = RoomModel(
          id: '',
          roomNumber: int.tryParse(_numberCtrl.text.trim()) ?? 0,
          floor: int.tryParse(_floorCtrl.text.trim()) ?? 0,
          capacity: int.tryParse(_capacityCtrl.text.trim()) ?? 0,
          currentOccupants: 0,
          status: _status,
          hostel: 'girls',
          amenities: amenities,
          studentIds: const [],
          pricePerMonth: double.tryParse(_priceCtrl.text.trim()) ?? 0,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          createdAt: DateTime.now(),
        );
        await provider.add(newRoom);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEdit ? 'Xona yangilandi' : "Xona qo'shildi"),
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
        title: Text(_isEdit ? 'Xonani tahrirlash' : "Xona qo'shish",
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numberCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: GTheme.inputDecoration('Xona raqami',
                          icon: Icons.tag_rounded),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Kiriting' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _floorCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: GTheme.inputDecoration('Qavat',
                          icon: Icons.stairs_outlined),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Kiriting' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _capacityCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: GTheme.inputDecoration('Sig\'imi',
                          icon: Icons.people_alt_outlined),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Kiriting' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: GTheme.inputDecoration('Oylik narx',
                          icon: Icons.payments_outlined),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Kiriting' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<RoomStatus>(
                initialValue: _status,
                dropdownColor: GTheme.bgCard2,
                style: const TextStyle(color: Colors.white),
                decoration:
                    GTheme.inputDecoration('Holati', icon: Icons.info_outline_rounded),
                items: RoomStatus.values
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? RoomStatus.empty),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amenitiesCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration(
                    'Qulayliklar (vergul bilan ajrating)',
                    icon: Icons.checklist_rounded),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: GTheme.inputDecoration('Izoh (ixtiyoriy)',
                    icon: Icons.notes_rounded),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GTheme.pink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(_isEdit ? 'Yangilash' : 'Saqlash',
                          style: const TextStyle(
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
