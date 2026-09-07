import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

class Sorovnoma extends StatefulWidget {
  final String studentId;
  const Sorovnoma({super.key, required this.studentId});

  @override
  State<Sorovnoma> createState() => _SorovnomaState();
}

class _SorovnomaState extends State<Sorovnoma> {
  final _formKey = GlobalKey<FormState>();

  // Rating values (1-5)
  int _cleanliness = 3;
  int _safety = 3;
  int _staffAttitude = 3;
  int _roomComfort = 3;
  int _facilities = 3;
  int _overallSatisfaction = 3;

  String _suggestions = '';
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  final Map<String, Map<String, dynamic>> _questions = {
    'cleanliness': {
      'title': "Tozalik va gigiena",
      'icon': Icons.cleaning_services_rounded,
      'color': _LC.teal,
    },
    'safety': {
      'title': "Xavfsizlik",
      'icon': Icons.security_rounded,
      'color': _LC.mint,
    },
    'staffAttitude': {
      'title': "Xodimlar munosabati",
      'icon': Icons.people_alt_rounded,
      'color': _LC.orange,
    },
    'roomComfort': {
      'title': "Xona qulayligi",
      'icon': Icons.bed_rounded,
      'color': _LC.purple,
    },
    'facilities': {
      'title': "Qo'shimcha qulayliklar (WiFi, suv, elektr)",
      'icon': Icons.wifi_rounded,
      'color': _LC.violet,
    },
    'overallSatisfaction': {
      'title': "Umumiy qoniqish",
      'icon': Icons.star_rounded,
      'color': _LC.pink,
    },
  };

  Future<void> _submitSurvey() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        await FirebaseFirestore.instance.collection('sorovnomalar').add({
          'studentId': widget.studentId,
          'cleanliness': _cleanliness,
          'safety': _safety,
          'staffAttitude': _staffAttitude,
          'roomComfort': _roomComfort,
          'facilities': _facilities,
          'overallSatisfaction': _overallSatisfaction,
          'suggestions': _suggestions,
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("So'rovnoma yuborildi! Rahmat."),
            backgroundColor: _LC.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } catch (e) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Xatolik: $e"),
            backgroundColor: _LC.coral,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return Scaffold(
        backgroundColor: _LC.bg,
        appBar: AppBar(
          elevation: 0,
          title: const Text(
            "So'rovnoma",
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _LC.teal.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: _LC.teal,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Rahmat!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _LC.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Sizning fikringiz biz uchun muhim",
                  style: TextStyle(color: _LC.muted, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Yotoqxonani yaxshilashda yordam berganingiz uchun tashakkur",
                  style: TextStyle(color: _LC.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Yotoqxona so'rovnomasi",
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
            children: [
              // ─── Header karta ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_LC.purple, _LC.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _LC.purple.withOpacity(0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.rate_review_rounded,
                          size: 34, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Fikr-mulohaza qoldiring",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Sizning fikringiz xizmat sifatini yaxshilashga yordam beradi",
                      style: TextStyle(color: Colors.white70, fontSize: 13.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ─── Savollar ───
              _buildRatingQuestion(
                key: 'cleanliness',
                value: _cleanliness,
                onChanged: (val) => setState(() => _cleanliness = val),
              ),
              _buildRatingQuestion(
                key: 'safety',
                value: _safety,
                onChanged: (val) => setState(() => _safety = val),
              ),
              _buildRatingQuestion(
                key: 'staffAttitude',
                value: _staffAttitude,
                onChanged: (val) => setState(() => _staffAttitude = val),
              ),
              _buildRatingQuestion(
                key: 'roomComfort',
                value: _roomComfort,
                onChanged: (val) => setState(() => _roomComfort = val),
              ),
              _buildRatingQuestion(
                key: 'facilities',
                value: _facilities,
                onChanged: (val) => setState(() => _facilities = val),
              ),
              _buildRatingQuestion(
                key: 'overallSatisfaction',
                value: _overallSatisfaction,
                onChanged: (val) => setState(() => _overallSatisfaction = val),
              ),

              const SizedBox(height: 4),

              // ─── Takliflar karta ───
              Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded,
                            color: _LC.purple, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "Taklif va mulohazalar",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _LC.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      maxLines: 5,
                      style: const TextStyle(color: _LC.ink),
                      decoration: InputDecoration(
                        hintText:
                            "Yotoqxonani yaxshilash bo'yicha takliflaringiz...",
                        hintStyle:
                            const TextStyle(color: _LC.muted, fontSize: 13),
                        filled: true,
                        fillColor: _LC.faint,
                        contentPadding: const EdgeInsets.all(14),
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
                      onChanged: (val) => _suggestions = val,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

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
                      onTap: _isSubmitting ? null : _submitSurvey,
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
                                    "Yuborish",
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

              const SizedBox(height: 16),

              // ─── Info matn ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _LC.teal.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _LC.teal.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 20, color: _LC.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Sizning javoblaringiz anonim tarzda saqlanadi va faqat statistika uchun ishlatiladi",
                        style: TextStyle(
                          fontSize: 12,
                          color: _LC.teal.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingQuestion({
    required String key,
    required int value,
    required Function(int) onChanged,
  }) {
    Map<String, dynamic> question = _questions[key]!;
    final Color color = question['color'] as Color;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  question['icon'] as IconData,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question['title'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _LC.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rating Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
              int rating = index + 1;
              return GestureDetector(
                onTap: () => onChanged(rating),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      Icon(
                        rating <= value
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: rating <= value ? _LC.orange : _LC.faint,
                        size: 32,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$rating",
                        style: TextStyle(
                          fontSize: 12,
                          color: rating <= value ? _LC.orange : _LC.muted,
                          fontWeight: rating == value
                              ? FontWeight.w800
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Rating Labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Yomon", style: TextStyle(fontSize: 10.5, color: _LC.muted)),
              Text("Qoniqarsiz",
                  style: TextStyle(fontSize: 10.5, color: _LC.muted)),
              Text("O'rtacha",
                  style: TextStyle(fontSize: 10.5, color: _LC.muted)),
              Text("Yaxshi",
                  style: TextStyle(fontSize: 10.5, color: _LC.muted)),
              Text("A'lo", style: TextStyle(fontSize: 10.5, color: _LC.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
