import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';
import '../models/user_model.dart';

// ─── Creative LIGHT palette (ilova bo'ylab bir xil) ───
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

// Mudir yoki admin murojaatga javob yozadigan ekran.
class MurojaatJavob extends StatefulWidget {
  final ComplaintModel complaint;
  final UserModel? currentUser;
  const MurojaatJavob({super.key, required this.complaint, this.currentUser});

  @override
  State<MurojaatJavob> createState() => _MurojaatJavobState();
}

class _MurojaatJavobState extends State<MurojaatJavob> {
  final _formKey = GlobalKey<FormState>();
  final _responseController = TextEditingController();
  ComplaintStatus _selectedStatus = ComplaintStatus.reviewing;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _responseController.text = widget.complaint.response ?? '';
    // Agar murojaat hali "kutilmoqda" holatida bo'lsa, javob yozilganda
    // avtomatik "ko'rib chiqilmoqda" yoki "hal qilindi" tanlansin.
    _selectedStatus = widget.complaint.status == ComplaintStatus.pending
        ? ComplaintStatus.reviewing
        : widget.complaint.status;
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Color _statusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return _LC.orange;
      case ComplaintStatus.reviewing:
        return _LC.purple;
      case ComplaintStatus.resolved:
        return _LC.teal;
      case ComplaintStatus.closed:
        return _LC.muted;
    }
  }

  Future<void> _submitResponse() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.complaint.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Xatolik: bu murojaatning ID raqami topilmadi. Ro'yxatga qaytib, qaytadan urinib ko'ring."),
          backgroundColor: _LC.coral,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final respondedByName = widget.currentUser?.fullName ?? '';
    final respondedByRole = widget.currentUser?.role == UserRole.mudir
        ? 'Yotoqxona mudiri'
        : ((widget.currentUser?.role == UserRole.superAdmin ||
                widget.currentUser?.role == UserRole.admin)
            ? 'Administrator'
            : null);

    try {
      await FirebaseFirestore.instance
          .collection('murojaatlar')
          .doc(widget.complaint.id)
          .update({
        'response': _responseController.text.trim(),
        'status': _selectedStatus.name,
        'respondedByName': respondedByName,
        'respondedByRole': respondedByRole,
        'updatedAt': FieldValue.serverTimestamp(),
        if (_selectedStatus == ComplaintStatus.resolved)
          'resolvedAt': FieldValue.serverTimestamp(),
      });

      // Talabaga javob yuborilgani haqida bildirishnoma
      await FirebaseFirestore.instance.collection('bildirishnomalar').add({
        'type': 'complaint_response',
        'title': '💬 Murojaatingizga javob berildi',
        'body': _responseController.text.trim(),
        'complaintId': widget.complaint.id,
        'studentId': widget.complaint.studentId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'targetRole': 'talaba',
      });

      final updatedComplaint = widget.complaint.copyWith(
        response: _responseController.text.trim(),
        status: _selectedStatus,
        respondedByName: respondedByName,
        respondedByRole: respondedByRole,
        updatedAt: DateTime.now(),
        resolvedAt:
            _selectedStatus == ComplaintStatus.resolved ? DateTime.now() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Javob yuborildi"),
            backgroundColor: _LC.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, updatedComplaint);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Xatolik: $e"),
            backgroundColor: _LC.coral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _sectionLabel(String text, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: _LC.purple),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: _LC.ink,
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _LC.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _LC.faint),
        boxShadow: [
          BoxShadow(
            color: _LC.purple.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Javob berish",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_LC.purple, _LC.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Murojaat qisqacha ───
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.complaint.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _LC.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.complaint.description,
                      style: TextStyle(color: _LC.muted.withOpacity(0.95)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: _LC.teal.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 14, color: _LC.teal),
                              const SizedBox(width: 4),
                              Text(
                                widget.complaint.isAnonymous
                                    ? "${widget.complaint.studentName.isNotEmpty ? widget.complaint.studentName : "Noma'lum talaba"} (anonim so'ragan)"
                                    : (widget.complaint.studentName.isNotEmpty
                                        ? widget.complaint.studentName
                                        : "Noma'lum talaba"),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _LC.teal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: _LC.pink.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.forward_to_inbox_rounded,
                                  size: 14, color: _LC.pink),
                              const SizedBox(width: 4),
                              Text(
                                widget.complaint.targetRole.displayName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _LC.pink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Javob matni ───
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Javobingiz", icon: Icons.reply_rounded),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _responseController,
                      maxLines: 6,
                      style: const TextStyle(color: _LC.ink),
                      decoration: InputDecoration(
                        hintText: "Talabaga javobingizni yozing...",
                        hintStyle:
                            const TextStyle(color: _LC.muted, fontSize: 13),
                        filled: true,
                        fillColor: _LC.faint,
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _LC.purple, width: 1.4),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Javob matnini kiriting";
                        }
                        if (value.trim().length < 5) {
                          return "Javob kamida 5 harf bo'lishi kerak";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Holatni tanlash ───
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Murojaat holati", icon: Icons.flag_rounded),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ComplaintStatus.reviewing,
                        ComplaintStatus.resolved,
                        ComplaintStatus.closed,
                      ].map((status) {
                        final bool selected = _selectedStatus == status;
                        final color = _statusColor(status);
                        return GestureDetector(
                          onTap: () => setState(() => _selectedStatus = status),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withOpacity(0.12)
                                  : _LC.faint,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? color : Colors.transparent,
                                width: 1.4,
                              ),
                            ),
                            child: Text(
                              status.displayName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: selected ? color : _LC.ink,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ─── Yuborish tugmasi ───
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_LC.purple, _LC.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _LC.purple.withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _isSubmitting ? null : _submitResponse,
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_rounded,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    "Javobni yuborish",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
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
