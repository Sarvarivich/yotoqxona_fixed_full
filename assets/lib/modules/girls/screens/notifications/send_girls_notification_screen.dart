import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/room_model.dart';
import '../../../models/user_model.dart';
import '../../providers/girls_notification_provider.dart';
import '../../providers/girls_room_provider.dart';
import '../../providers/girls_student_provider.dart';
import '../../services/girl_student_model.dart';
import '../../services/girls_notification_model.dart';
import '../../theme/girls_theme.dart';

// ─── SendGirlsNotificationScreen: yangi bildirishnoma yuborish formasi.
class SendGirlsNotificationScreen extends StatefulWidget {
  final UserModel? currentUser;
  const SendGirlsNotificationScreen({super.key, this.currentUser});

  @override
  State<SendGirlsNotificationScreen> createState() =>
      _SendGirlsNotificationScreenState();
}

class _SendGirlsNotificationScreenState
    extends State<SendGirlsNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  GirlsNotificationTarget _target = GirlsNotificationTarget.all;
  String? _targetId;
  String? _targetLabel;
  bool _isSending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_target != GirlsNotificationTarget.all && _targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Qabul qiluvchini tanlang'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSending = true);
    try {
      final notification = GirlsNotificationModel(
        id: '',
        title: _titleCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        target: _target,
        targetId: _target == GirlsNotificationTarget.all ? null : _targetId,
        targetLabel:
            _target == GirlsNotificationTarget.all ? null : _targetLabel,
        createdBy: widget.currentUser?.fullName ?? 'Administratsiya',
        createdAt: DateTime.now(),
      );
      await context.read<GirlsNotificationProvider>().send(notification);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bildirishnoma yuborildi'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GTheme.bgBase,
      appBar: AppBar(
        backgroundColor: GTheme.bgBase,
        elevation: 0,
        title: const Text('Bildirishnoma yuborish',
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
                controller: _titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration('Sarlavha',
                    icon: Icons.title_rounded),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Sarlavha kiriting'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _messageCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: GTheme.inputDecoration('Xabar matni',
                    icon: Icons.message_outlined),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Xabar matnini kiriting'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<GirlsNotificationTarget>(
                initialValue: _target,
                dropdownColor: GTheme.bgCard2,
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration('Kimga yuborilsin',
                    icon: Icons.group_outlined),
                items: GirlsNotificationTarget.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t.displayName)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _target = v ?? GirlsNotificationTarget.all;
                  _targetId = null;
                  _targetLabel = null;
                }),
              ),
              const SizedBox(height: 14),
              if (_target == GirlsNotificationTarget.room)
                StreamBuilder<List<RoomModel>>(
                  stream: context.read<GirlsRoomProvider>().rooms,
                  builder: (context, snapshot) {
                    final List<RoomModel> rooms =
                        snapshot.data ?? <RoomModel>[];
                    return DropdownButtonFormField<String>(
                      initialValue: _targetId,
                      dropdownColor: GTheme.bgCard2,
                      style: const TextStyle(color: Colors.white),
                      decoration: GTheme.inputDecoration('Xonani tanlang',
                          icon: Icons.meeting_room_outlined),
                      items: rooms
                          .map<DropdownMenuItem<String>>(
                            (RoomModel r) => DropdownMenuItem<String>(
                              value: r.id,
                              child: Text('${r.roomNumber}-xona'),
                            ),
                          )
                          .toList(),
                      onChanged: (String? v) {
                        if (v == null) return;
                        final RoomModel room =
                            rooms.firstWhere((RoomModel r) => r.id == v);
                        setState(() {
                          _targetId = v;
                          _targetLabel = '${room.roomNumber}-xona';
                        });
                      },
                    );
                  },
                ),
              if (_target == GirlsNotificationTarget.student)
                StreamBuilder<List<GirlStudentModel>>(
                  stream: context.read<GirlsStudentProvider>().students,
                  builder: (context, snapshot) {
                    final List<GirlStudentModel> students =
                        snapshot.data ?? <GirlStudentModel>[];
                    return DropdownButtonFormField<String>(
                      initialValue: _targetId,
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
                        final GirlStudentModel student = students
                            .firstWhere((GirlStudentModel s) => s.id == v);
                        setState(() {
                          _targetId = v;
                          _targetLabel = student.fullName;
                        });
                      },
                    );
                  },
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: const Text('Yuborish',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GTheme.pink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
