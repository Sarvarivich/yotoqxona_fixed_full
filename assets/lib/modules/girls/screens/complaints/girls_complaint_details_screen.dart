import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/complaint_model.dart';
import '../../../models/user_model.dart';
import '../../providers/girls_complaint_provider.dart';
import '../../theme/girls_theme.dart';

// ─── GirlsComplaintDetailsScreen: murojaat tafsilotlari va unga
// javob yozish (admin/mudira tomonidan).
class GirlsComplaintDetailsScreen extends StatefulWidget {
  final ComplaintModel complaint;
  final UserModel? currentUser;
  const GirlsComplaintDetailsScreen({
    super.key,
    required this.complaint,
    this.currentUser,
  });

  @override
  State<GirlsComplaintDetailsScreen> createState() =>
      _GirlsComplaintDetailsScreenState();
}

class _GirlsComplaintDetailsScreenState
    extends State<GirlsComplaintDetailsScreen> {
  final _responseCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResponse() async {
    if (_responseCtrl.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      await context.read<GirlsComplaintProvider>().respond(
            id: widget.complaint.id,
            response: _responseCtrl.text.trim(),
            respondedByName: widget.currentUser?.fullName ?? 'Administratsiya',
            respondedByRole: widget.currentUser?.role.name ?? 'admin',
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Javob yuborildi'), backgroundColor: Colors.green),
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
    final c = widget.complaint;
    return Scaffold(
      backgroundColor: GTheme.bgBase,
      appBar: AppBar(
        backgroundColor: GTheme.bgBase,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Murojaat tafsiloti',
            style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              decoration: GTheme.cardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Tag(text: c.category, color: GTheme.teal),
                      _Tag(text: c.priority.displayName, color: GTheme.orange),
                      _Tag(text: c.status.displayName, color: GTheme.violet),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(c.description,
                      style: TextStyle(
                          color: GTheme.white.withOpacity(0.8), height: 1.5)),
                  const Divider(color: GTheme.faint, height: 32),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          color: GTheme.pink, size: 18),
                      const SizedBox(width: 8),
                      Text(c.isAnonymous ? 'Anonim talaba' : c.studentName,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      const Spacer(),
                      Text(GTheme.formatDateTime(c.createdAt),
                          style: TextStyle(
                              color: GTheme.white.withOpacity(0.4),
                              fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (c.response != null && c.response!.isNotEmpty) ...[
              Container(
                decoration:
                    GTheme.cardDecoration(color: GTheme.pink.withOpacity(0.08)),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.reply_rounded,
                            color: GTheme.pink, size: 18),
                        const SizedBox(width: 8),
                        Text(c.respondedByName ?? 'Administratsiya',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(c.response!,
                        style:
                            const TextStyle(color: Colors.white, height: 1.5)),
                  ],
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 10, left: 4),
                child: Text('Javob yozish',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              TextField(
                controller: _responseCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration('Javobingizni yozing...'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendResponse,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                  label: const Text('Javobni yuborish',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GTheme.pink,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
