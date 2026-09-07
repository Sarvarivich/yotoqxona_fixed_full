import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';
import '../models/user_model.dart';
import 'murojaat_javob.dart';

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

class MurojaatTafsilotlari extends StatefulWidget {
  final ComplaintModel complaint;
  final bool isAdmin;
  // Hozirgi login qilingan foydalanuvchi (javob yozganda "kim javob berdi"
  // ma'lumotini belgilash uchun)
  final UserModel? currentUser;
  const MurojaatTafsilotlari({
    super.key,
    required this.complaint,
    required this.isAdmin,
    this.currentUser,
  });

  @override
  State<MurojaatTafsilotlari> createState() => _MurojaatTafsilotlariState();
}

class _MurojaatTafsilotlariState extends State<MurojaatTafsilotlari> {
  late ComplaintModel _complaint;
  UserModel? _studentInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _complaint = widget.complaint;
    _loadStudentInfo();
  }

  Future<void> _loadStudentInfo() async {
    // studentId endi har doim haqiqiy talaba ID sini saqlaydi (anonim
    // so'ralgan bo'lsa ham) — shuning uchun admin talaba ma'lumotini
    // har doim ko'ra oladi.
    if (_complaint.studentId.isNotEmpty) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .doc(_complaint.studentId)
          .get();
      if (doc.exists) {
        _studentInfo = UserModel.fromJson(doc.data() as Map<String, dynamic>);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateStatus(ComplaintStatus newStatus) async {
    await FirebaseFirestore.instance
        .collection('murojaatlar')
        .doc(_complaint.id)
        .update({
      'status': newStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (newStatus == ComplaintStatus.resolved)
        'resolvedAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _complaint = _complaint.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Holat yangilandi"),
          backgroundColor: _LC.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _sectionCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _LC.bg,
        appBar: AppBar(
          elevation: 0,
          title: Text(
            _complaint.title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800),
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
        body: const Center(child: CircularProgressIndicator(color: _LC.purple)),
      );
    }

    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          _complaint.title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
        actions: [
          if (widget.isAdmin && _complaint.status != ComplaintStatus.resolved)
            PopupMenuButton<ComplaintStatus>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: _updateStatus,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: ComplaintStatus.pending,
                  child: Text("Kutilmoqda"),
                ),
                PopupMenuItem(
                  value: ComplaintStatus.reviewing,
                  child: Text("Ko'rib chiqilmoqda"),
                ),
                PopupMenuItem(
                  value: ComplaintStatus.resolved,
                  child: Text("Hal qilindi"),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Holat kartasi (gradient) ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getStatusGradient(_complaint.status),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor(_complaint.status).withOpacity(0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(_complaint.status),
                      color: _getStatusColor(_complaint.status),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Holat",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          _getStatusText(_complaint.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ─── Murojaat ma'lumotlari ───
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel("Murojaat ma'lumotlari",
                      icon: Icons.description_rounded),
                  const SizedBox(height: 14),
                  if (widget.isAdmin) ...[
                    _infoRow(
                      Icons.person_outline_rounded,
                      "Kimdan",
                      _complaint.isAnonymous
                          ? "${_complaint.studentName.isNotEmpty ? _complaint.studentName : "Noma'lum"} (anonim so'ragan)"
                          : (_complaint.studentName.isNotEmpty
                              ? _complaint.studentName
                              : "Noma'lum"),
                      _LC.teal,
                    ),
                    _infoRow(
                      Icons.forward_to_inbox_rounded,
                      "Kimga",
                      _complaint.targetRole.displayName,
                      _LC.pink,
                    ),
                  ],
                  _infoRow(
                    Icons.category_rounded,
                    "Kategoriya",
                    _complaint.category,
                    _getCategoryColor(_complaint.category),
                  ),
                  _infoRow(
                    Icons.access_time_rounded,
                    "Yuborilgan vaqt",
                    _formatDateTime(_complaint.createdAt),
                    _LC.muted,
                  ),
                  if (_complaint.updatedAt != null)
                    _infoRow(
                      Icons.update_rounded,
                      "Yangilangan vaqt",
                      _formatDateTime(_complaint.updatedAt!),
                      _LC.muted,
                    ),
                  const SizedBox(height: 4),
                  const Divider(color: _LC.faint, height: 24),
                  Text(
                    _complaint.description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _LC.ink,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Talaba ma'lumotlari (faqat admin) ───
            if (widget.isAdmin && _studentInfo != null) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Talaba ma'lumotlari",
                        icon: Icons.badge_rounded),
                    const SizedBox(height: 14),
                    _infoRow(
                      Icons.person_rounded,
                      "FIO",
                      _studentInfo!.fullName,
                      _LC.purple,
                    ),
                    _infoRow(
                      Icons.email_rounded,
                      "Email",
                      _studentInfo!.email,
                      _LC.purple,
                    ),
                    _infoRow(
                      Icons.phone_rounded,
                      "Telefon",
                      _studentInfo!.phoneNumber,
                      _LC.purple,
                    ),
                    if (_studentInfo!.studentId != null)
                      _infoRow(
                        Icons.school_rounded,
                        "Talaba ID",
                        _studentInfo!.studentId!,
                        _LC.purple,
                      ),
                  ],
                ),
              ),
            ],

            // ─── Javob ───
            if (_complaint.response != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _LC.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _LC.teal.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.reply_rounded, color: _LC.teal),
                        const SizedBox(width: 8),
                        const Text(
                          "Javob",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _LC.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _complaint.response!,
                      style: const TextStyle(color: _LC.ink, height: 1.5),
                    ),
                    const SizedBox(height: 10),
                    if (_complaint.respondedByName != null &&
                        _complaint.respondedByName!.isNotEmpty)
                      Text(
                        "Javob berdi: ${_complaint.respondedByName}"
                        "${_complaint.respondedByRole != null ? " (${_complaint.respondedByRole})" : ""}",
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _LC.teal,
                        ),
                      ),
                    if (_complaint.updatedAt != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatDateTime(_complaint.updatedAt!),
                          style: TextStyle(
                            fontSize: 11,
                            color: _LC.teal.withOpacity(0.75),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ─── Javob berish tugmasi ───
            if (widget.isAdmin && _complaint.status != ComplaintStatus.resolved)
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
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MurojaatJavob(
                              complaint: _complaint,
                              currentUser: widget.currentUser,
                            ),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            _complaint = result;
                          });
                        }
                      },
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.reply_rounded,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Javob berish",
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
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: _LC.muted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _LC.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return "${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Color _getStatusColor(ComplaintStatus status) {
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

  List<Color> _getStatusGradient(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return [_LC.orange, const Color(0xFFE2A93B)];
      case ComplaintStatus.reviewing:
        return [_LC.purple, _LC.violet];
      case ComplaintStatus.resolved:
        return [_LC.teal, const Color(0xFF00A39E)];
      case ComplaintStatus.closed:
        return [_LC.muted, const Color(0xFF6E6A8C)];
    }
  }

  IconData _getStatusIcon(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return Icons.pending_rounded;
      case ComplaintStatus.reviewing:
        return Icons.visibility_rounded;
      case ComplaintStatus.resolved:
        return Icons.check_circle_rounded;
      case ComplaintStatus.closed:
        return Icons.lock_rounded;
    }
  }

  String _getStatusText(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return "Kutilmoqda";
      case ComplaintStatus.reviewing:
        return "Ko'rib chiqilmoqda";
      case ComplaintStatus.resolved:
        return "Hal qilindi";
      case ComplaintStatus.closed:
        return "Yopilgan";
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Texnik':
        return _LC.coral;
      case 'Ijtimoiy':
        return _LC.orange;
      case 'Moliyaviy':
        return _LC.violet;
      default:
        return _LC.purple;
    }
  }
}
