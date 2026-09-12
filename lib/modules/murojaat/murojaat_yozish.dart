import 'package:flutter/material.dart';
import '../models/complaint_model.dart';
import '../services/api_service.dart';

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

class MurojaatYozish extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String hostel;
  const MurojaatYozish({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.hostel,
  });

  @override
  State<MurojaatYozish> createState() => _MurojaatYozishState();
}

class _MurojaatYozishState extends State<MurojaatYozish> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Umumiy';
  bool _isAnonymous = false;
  bool _isLoading = false;
  // Murojaat kimga yuborilishi: mudir yoki admin
  ComplaintTarget _selectedTarget = ComplaintTarget.mudir;

  final List<String> _categories = [
    'Texnik',
    'Ijtimoiy',
    'Moliyaviy',
    'Umumiy',
  ];

  final Map<String, IconData> _categoryIcons = {
    'Texnik': Icons.build_rounded,
    'Ijtimoiy': Icons.people_alt_rounded,
    'Moliyaviy': Icons.attach_money_rounded,
    'Umumiy': Icons.info_rounded,
  };

  Color _categoryColor(String category) {
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

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return; // ketma-ket bosilishning oldini olish

    setState(() => _isLoading = true);

    // DIQQAT: Laravel'da anonim murojaat HAQIQATAN anonim -
    // student_id NULL qoldiriladi va admin ham kimdan kelganini
    // ko'ra olmaydi. Firestore'da esa ID saqlanardi.

    try {
      // Murojaat Laravel'ga yuboriladi. Backend student_id va
      // hostel_id ni o'zi to'ldiradi: student_id tokendan olinadi,
      // hostel esa talabaning joriy xonasidan aniqlanadi.
      //
      // ESLATMA: anonim yuborilganda backend student_id ni NULL
      // qoldiradi, ya'ni murojaat haqiqatan anonim bo'ladi va admin
      // ham kimdan kelganini ko'ra olmaydi.
      await ApiService().post('complaints', body: {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'priority': 'medium',
        'target_role': _selectedTarget.value,
        'is_anonymous': _isAnonymous,
      });

      if (!mounted) return;

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Murojaat yuborildi"),
          backgroundColor: _LC.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Murojaat yuborilmadi: ${e.toString().replaceFirst('Exception: ', '')}",
          ),
          backgroundColor: _LC.coral,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── Bo'lim sarlavhasi ───
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

  // ─── Bir xil karta konteyneri (dizayn tizimiga mos) ───
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
          "Yangi murojaat",
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
              // ─── Murojaat turi ───
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Murojaat turi",
                        icon: Icons.category_rounded),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categories.map((category) {
                        final bool selected = _selectedCategory == category;
                        final color = _categoryColor(category);
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = category),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _categoryIcons[category],
                                  size: 17,
                                  color: selected ? color : _LC.muted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? color : _LC.ink,
                                  ),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.check_circle_rounded,
                                      size: 15, color: color),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Qabul qiluvchini tanlash: Mudir yoki Admin ───
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Murojaat kimga yuborilsin?",
                        icon: Icons.forward_to_inbox_rounded),
                    const SizedBox(height: 12),
                    Row(
                      children: ComplaintTarget.values.map((target) {
                        final bool selected = _selectedTarget == target;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: target == ComplaintTarget.values.first
                                  ? 10
                                  : 0,
                            ),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedTarget = target),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? const LinearGradient(
                                          colors: [_LC.purple, _LC.violet],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: selected ? null : _LC.faint,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: _LC.purple.withOpacity(0.30),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      target == ComplaintTarget.mudir
                                          ? Icons.apartment_rounded
                                          : Icons.admin_panel_settings_rounded,
                                      color:
                                          selected ? Colors.white : _LC.muted,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      target.displayName,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            selected ? Colors.white : _LC.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Sarlavha ───
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Sarlavha", icon: Icons.title_rounded),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(color: _LC.ink),
                      decoration: InputDecoration(
                        hintText: "Murojaat mavzusini qisqacha yozing",
                        hintStyle:
                            const TextStyle(color: _LC.muted, fontSize: 13),
                        prefixIcon: const Icon(Icons.short_text_rounded,
                            color: _LC.purple),
                        filled: true,
                        fillColor: _LC.faint,
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
                        if (value == null || value.isEmpty) {
                          return "Sarlavha kiriting";
                        }
                        if (value.length < 5) {
                          return "Sarlavha kamida 5 harf";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Batafsil ma'lumot ───
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel("Batafsil ma'lumot",
                        icon: Icons.description_rounded),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descController,
                      maxLines: 6,
                      style: const TextStyle(color: _LC.ink),
                      decoration: InputDecoration(
                        hintText: "Muammoingizni batafsil tasvirlab bering...",
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
                        if (value == null || value.isEmpty) {
                          return "Ma'lumot kiriting";
                        }
                        if (value.length < 10) {
                          return "Ma'lumot kamida 10 harf";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Anonim yuborish ───
              _sectionCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_isAnonymous ? _LC.muted : _LC.purple)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isAnonymous
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: _isAnonymous ? _LC.muted : _LC.purple,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Anonim yuborish",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: _LC.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Boshqalarga ismingiz ko'rsatilmaydi (superadmin ko'radi)",
                            style: TextStyle(
                                fontSize: 11.5,
                                color: _LC.muted.withOpacity(0.95)),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAnonymous,
                      onChanged: (value) =>
                          setState(() => _isAnonymous = value),
                      activeThumbColor: _LC.purple,
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
                      onTap: _isLoading ? null : _submitComplaint,
                      child: Center(
                        child: _isLoading
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

              // ─── Info ───
              Container(
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
                        "Murojaatingiz ko'rib chiqilib, tez orada javob beriladi",
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
}
