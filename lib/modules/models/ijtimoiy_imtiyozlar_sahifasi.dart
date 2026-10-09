import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/register.dart' show kBenefitTypes;
import '../models/user_model.dart';
import '../services/api_service.dart';

// ─── Creative dark palette — roles/admin_screen.dart va
// girls/theme/girls_theme.dart bilan BIR XIL rang tili ───
class _C {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
  static const bgCard2 = Color(0xFF16132B);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFa29bfe);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFfd79a8);
  static const orange = Color(0xFFfdcb6e);
  static const coral = Color(0xFFe17055);
  static const white = Color(0xFFFFFFFF);
  static const soft = Color(0xB3FFFFFF);
  static const muted = Color(0x66FFFFFF);
  static const faint = Color(0x0FFFFFFF);
}

/// ─── IjtimoiyImtiyozlarSahifasi ────────────────────────────────
/// Admin/superAdmin/mudir uchun: ro'yxatdan o'tishda "Ijtimoiy
/// imtiyozga egaman" deb belgilagan VA hujjat yuklagan barcha
/// talabalarni bitta joyda ko'rsatadi. Yuqorida "O'g'il bolalar" /
/// "Qiz bolalar" tugmalari orqali almashtiriladi — qaysi biri
/// bosilsa, o'sha yotoqxonaga tegishli talabalarning imtiyoz turi
/// va yuklagan fayli ko'rinadi. Bu sahifa admin/mudirning o'z
/// yotoqxonasi bilan CHEKLANMAYDI — ikkalasini ham ko'ra oladi,
/// shu bilan boys AdminScreen va GirlsAdminScreen'ning ikkalasiga
/// ham bir xil widget sifatida ulanadi (o'z Scaffold/AppBar'i
/// yo'q — tashqi qobiqning AppBar'i ostida oddiy body sifatida
/// ishlaydi, xuddi Dashboard/Xonalar tablari kabi).
class IjtimoiyImtiyozlarSahifasi extends StatefulWidget {
  /// Boshlang'ich holatda qaysi yotoqxona tanlangan bo'lishini
  /// majburlash uchun (masalan GirlsAdminScreen ichidan ochilganda
  /// "girls" bilan boshlanishi qulayroq). Berilmasa "boys" bilan
  /// boshlanadi. Baribir foydalanuvchi tugmalar orqali almashtira oladi.
  final String? initialHostel;

  /// Joriy foydalanuvchi (admin/superAdmin tekshiruvi uchun).
  /// Berilmasa "Ma'lumot kiritish" tugmasi ko'rsatilmaydi.
  final UserModel? currentUser;

  const IjtimoiyImtiyozlarSahifasi(
      {super.key, this.initialHostel, this.currentUser});

  @override
  State<IjtimoiyImtiyozlarSahifasi> createState() =>
      _IjtimoiyImtiyozlarSahifasiState();
}

class _IjtimoiyImtiyozlarSahifasiState
    extends State<IjtimoiyImtiyozlarSahifasi> {
  late String _selectedHostel;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static final Map<String, String> _benefitLabels = {
    for (final e in kBenefitTypes) e.key: e.value,
  };

  static const Map<String, IconData> _benefitIcons = {
    '1': Icons.family_restroom_rounded,
    '2': Icons.accessible_rounded,
    '3': Icons.home_work_rounded,
    '4': Icons.badge_rounded,
    '5': Icons.groups_2_rounded,
    '6': Icons.diversity_1_rounded,
  };

  static const Map<String, Color> _benefitColors = {
    '1': _C.coral,
    '2': _C.pink,
    '3': _C.violet,
    '4': _C.teal,
    '5': _C.orange,
    '6': _C.mint,
  };

  // Ma'lumot Laravel API'dan bir marta yuklanadi.
  //
  // MUHIM: Future initState'da bir marta yaratiladi. Agar u build()
  // ichida yaratilsa, har bir setState (qidiruvga yozilgan har bir
  // harf) yangi so'rov yuborardi va ro'yxat "yuklanmoqda" holatiga
  // qaytib, klaviatura fokusi yo'qolardi.
  late Future<List<UserModel>> _imtiyozliTalabalar;

  /// Faqat admin va superAdmin uchun "Ma'lumot kiritish" tugmasi ko'rinadi
  bool get _canAddBenefit {
    final u = widget.currentUser;
    if (u == null) return false;
    return u.role == UserRole.admin || u.role == UserRole.superAdmin;
  }

  @override
  void initState() {
    super.initState();
    final forced = (widget.initialHostel ?? '').trim().toLowerCase();
    _selectedHostel = forced.isNotEmpty ? forced : 'boys';
    _imtiyozliTalabalar = _yukla();
  }

  /// Ijtimoiy imtiyozga ega talabalarni yuklaydi.
  ///
  /// Laravel'da alohida "hasSocialBenefit" ustuni yo'q - imtiyoz
  /// ma'lumoti additional_data (JSON) ichida saqlanadi. Shuning uchun
  /// barcha talabalarni olib, mijoz tomonida filtrlaymiz.
  ///
  /// detailed=1 kerak, chunki additional_data faqat to'liq javobda
  /// keladi - oddiy ro'yxatda shaxsiy maydonlar berilmaydi.
  Future<List<UserModel>> _yukla() async {
    final api = ApiService();
    final hammasi = <UserModel>[];

    int sahifa = 1;
    int oxirgi = 1;

    do {
      final javob = await api.get(
        'students?role=talaba&per_page=100&detailed=1&page=$sahifa',
      );

      final royxat = javob['data'];
      if (royxat is List) {
        for (final e in royxat) {
          if (e is! Map) continue;
          final d = Map<String, dynamic>.from(e);

          final qoshimcha = d['additional_data'] ?? d['additionalData'];
          final imtiyoz = qoshimcha is Map ? qoshimcha : const {};

          final bor = imtiyoz['hasSocialBenefit'] == true ||
              imtiyoz['has_social_benefit'] == true;
          if (bor) hammasi.add(UserModel.fromJson(d));
        }
      }

      final meta = javob['meta'];
      oxirgi = meta is Map
          ? ((meta['last_page'] as num?)?.toInt() ?? sahifa)
          : sahifa;
      sahifa++;
    } while (sahifa <= oxirgi && sahifa <= 100);

    return hammasi;
  }

  Future<void> _qaytaYukla() async {
    setState(() {
      _imtiyozliTalabalar = _yukla();
    });
    await _imtiyozliTalabalar;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFile(String url, String label) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$label ochilmadi — havolani tekshiring"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Faylni ochishda xatolik: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Admin/superAdmin uchun: yangi ijtimoiy imtiyozli talaba kiritish dialog
  Future<void> _showAddBenefitDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddBenefitDialog(onSaved: _qaytaYukla),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: _C.bgBase,
          child: FutureBuilder<List<UserModel>>(
            future: _imtiyozliTalabalar,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "Ma'lumotlarni yuklashda xatolik: ${snapshot.error}",
                          style: const TextStyle(color: _C.soft),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _qaytaYukla,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Qayta urinish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _C.purple),
                );
              }

              final allUsers = snapshot.data!;

              final boysCount =
                  allUsers.where((u) => (u.hostel ?? 'boys') != 'girls').length;
              final girlsCount =
                  allUsers.where((u) => (u.hostel ?? 'boys') == 'girls').length;

              var visible = allUsers
                  .where((u) => (u.hostel ?? 'boys') == _selectedHostel)
                  .toList();

              if (_searchQuery.isNotEmpty) {
                visible = visible
                    .where(
                        (u) => u.fullName.toLowerCase().contains(_searchQuery))
                    .toList();
              }
              visible.sort((a, b) => a.fullName.compareTo(b.fullName));

              return Column(
                children: [
                  _buildToggle(boysCount, girlsCount),
                  _buildSearch(),
                  const SizedBox(height: 4),
                  Expanded(
                    child: visible.isEmpty
                        ? _buildEmpty()
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                                14, 8, 14, _canAddBenefit ? 90 : 20),
                            itemCount: visible.length,
                            itemBuilder: (context, i) =>
                                _buildStudentCard(visible[i]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),

        // "Ma'lumot kiritish" FAB — faqat admin va superAdmin uchun
        if (_canAddBenefit)
          Positioned(
            right: 18,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'ijtimoiy_add_fab',
              onPressed: _showAddBenefitDialog,
              backgroundColor: _C.purple,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                "Ma'lumot kiritish",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildToggle(int boysCount, int girlsCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            Expanded(
              child: _ToggleButton(
                label: "O'g'il bolalar",
                count: boysCount,
                icon: Icons.person_rounded,
                selected: _selectedHostel == 'boys',
                color: _C.teal,
                onTap: () => setState(() => _selectedHostel = 'boys'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToggleButton(
                label: 'Qiz bolalar',
                count: girlsCount,
                icon: Icons.person_rounded,
                selected: _selectedHostel == 'girls',
                color: _C.pink,
                onTap: () => setState(() => _selectedHostel = 'girls'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Container(
        decoration: BoxDecoration(
          color: _C.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.faint),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: _C.white, fontSize: 13),
          onChanged: (v) =>
              setState(() => _searchQuery = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Talaba ismi bo\'yicha qidirish...',
            hintStyle: const TextStyle(color: _C.muted, fontSize: 13),
            prefixIcon:
                const Icon(Icons.search_rounded, color: _C.purple, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: _C.muted, size: 18),
                    onPressed: () => setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    }),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final isBoys = _selectedHostel == 'boys';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: (isBoys ? _C.teal : _C.pink).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.volunteer_activism_rounded,
                  size: 34, color: isBoys ? _C.teal : _C.pink),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? "Qidiruv bo'yicha talaba topilmadi"
                  : (isBoys
                      ? "O'g'il bolalar orasida ijtimoiy imtiyozli talaba yo'q"
                      : "Qiz bolalar orasida ijtimoiy imtiyozli talaba yo'q"),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _C.soft, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(UserModel user) {
    final data = user.additionalData ?? const {};
    final benefitType = data['benefitType'] as String?;
    final lostParentType = data['lostParentType'] as String?;
    final deathCertUrl = data['deathCertificateUrl'] as String?;
    final benefitDocUrl = data['benefitDocumentUrl'] as String?;

    final label = _benefitLabels[benefitType] ?? "Imtiyoz turi ko'rsatilmagan";
    final icon = _benefitIcons[benefitType] ?? Icons.volunteer_activism_rounded;
    final color = _benefitColors[benefitType] ?? _C.purple;

    final isLostParent = benefitType == '1';
    final fileUrl = isLostParent ? deathCertUrl : benefitDocUrl;
    final fileLabel =
        isLostParent ? "O'lim varaqasi" : 'Imtiyoz ma\'lumotnomasi';

    final initials = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()[0].toUpperCase()
        : '?';

    final subtitleParts = <String>[
      if ((user.faculty ?? '').isNotEmpty) user.faculty!,
      if ((user.course ?? '').isNotEmpty) '${user.course}-kurs',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.faint),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initials,
                    style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                            color: _C.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitleParts.join(' · '),
                          style: const TextStyle(color: _C.muted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            if (isLostParent && (lostParentType ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: _C.muted),
                  const SizedBox(width: 6),
                  Text(
                    'Boquvchisi: ${lostParentType == 'ota' ? 'Ota' : 'Ona'}',
                    style: const TextStyle(color: _C.soft, fontSize: 12.5),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: (fileUrl != null && fileUrl.isNotEmpty)
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _openFile(fileUrl, fileLabel),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
                      label: Text(
                        '$fileLabel — ko\'rish / yuklab olish',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Fayl yuklanmagan',
                        style: TextStyle(color: _C.muted, fontSize: 12.5),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _AddBenefitDialog ─────────────────────────────────────────────
/// Admin/superAdmin tomonidan ijtimoiy imtiyozga ega talabani qo'lda
/// kiritish uchun modal dialog. Talaba ism bo'yicha qidirilib,
/// imtiyoz turi tanlanadi va additional_data orqali saqlanadi.
class _AddBenefitDialog extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddBenefitDialog({required this.onSaved});

  @override
  State<_AddBenefitDialog> createState() => _AddBenefitDialogState();
}

class _AddBenefitDialogState extends State<_AddBenefitDialog> {
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<UserModel> _searchResults = [];
  UserModel? _selectedStudent;

  String? _selectedBenefitType;
  String? _lostParentType; // faqat '1' tur uchun: 'ota' yoki 'ona'

  bool _isSaving = false;
  String? _errorMsg;

  Future<void> _search(String query) async {
    if (query.trim().length < 2) return;
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _errorMsg = null;
    });
    try {
      final api = ApiService();
      final javob = await api.get(
        'students?role=talaba&per_page=30&search=${Uri.encodeComponent(query.trim())}&detailed=1',
      );
      final royxat = javob['data'];
      final natija = <UserModel>[];
      if (royxat is List) {
        for (final e in royxat) {
          if (e is Map) {
            natija.add(UserModel.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
      if (mounted) {
        setState(() {
          _searchResults = natija;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMsg = "Qidirishda xatolik: $e";
        });
      }
    }
  }

  Future<void> _save() async {
    if (_selectedStudent == null) {
      setState(() => _errorMsg = "Talabani tanlang");
      return;
    }
    if (_selectedBenefitType == null) {
      setState(() => _errorMsg = "Imtiyoz turini tanlang");
      return;
    }
    if (_selectedBenefitType == '1' &&
        (_lostParentType == null || _lostParentType!.isEmpty)) {
      setState(() => _errorMsg = "Boquvchi turini tanlang (ota yoki ona)");
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    try {
      final api = ApiService();
      final student = _selectedStudent!;

      final existingData =
          Map<String, dynamic>.from(student.additionalData ?? {});
      existingData['hasSocialBenefit'] = true;
      existingData['benefitType'] = _selectedBenefitType;
      if (_selectedBenefitType == '1') {
        existingData['lostParentType'] = _lostParentType;
      } else {
        existingData.remove('lostParentType');
      }

      await api.updateStudent(student.id, {
        'additional_data': existingData,
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "${student.fullName} uchun ijtimoiy imtiyoz muvaffaqiyatli saqlandi"),
            backgroundColor: const Color(0xFF6C5CE7),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMsg = "Saqlashda xatolik: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1730),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Sarlavha ──
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.volunteer_activism_rounded,
                        color: Color(0xFF6C5CE7), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Ijtimoiy imtiyoz kiritish",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0x66FFFFFF), size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Talaba qidirish ──
              const Text(
                "Talabani qidirish",
                style: TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0D1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x0FFFFFFF)),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.search_rounded,
                          color: Color(0xFF6C5CE7), size: 18),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: "Ism yoki email bo'yicha...",
                          hintStyle: TextStyle(
                              color: Color(0x66FFFFFF), fontSize: 13),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: _search,
                        onChanged: (v) {
                          if (_selectedStudent != null &&
                              v != _selectedStudent!.fullName) {
                            setState(() => _selectedStudent = null);
                          }
                        },
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _isSearching ? null : () => _search(_searchCtrl.text),
                      child: const Text("Qidirish",
                          style: TextStyle(
                              color: Color(0xFF6C5CE7),
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),

              // Qidiruv natijalari
              if (_isSearching) ...[
                const SizedBox(height: 12),
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF6C5CE7)),
                  ),
                ),
              ] else if (_searchResults.isNotEmpty &&
                  _selectedStudent == null) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0D1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x0FFFFFFF)),
                  ),
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final u = _searchResults[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            _selectedStudent = u;
                            _searchCtrl.text = u.fullName;
                            _searchResults = [];
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C5CE7)
                                      .withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  u.fullName.trim().isNotEmpty
                                      ? u.fullName.trim()[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Color(0xFF6C5CE7),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.fullName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    if ((u.faculty ?? '').isNotEmpty)
                                      Text(u.faculty!,
                                          style: const TextStyle(
                                              color: Color(0x66FFFFFF),
                                              fontSize: 11)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Color(0x66FFFFFF), size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Tanlangan talaba
              if (_selectedStudent != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF6C5CE7).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF6C5CE7), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedStudent!.fullName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5),
                            ),
                            if ((_selectedStudent!.faculty ?? '').isNotEmpty)
                              Text(
                                _selectedStudent!.faculty!,
                                style: const TextStyle(
                                    color: Color(0x66FFFFFF), fontSize: 11.5),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedStudent = null;
                          _searchCtrl.clear();
                        }),
                        child: const Icon(Icons.close_rounded,
                            color: Color(0x66FFFFFF), size: 16),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ── Imtiyoz turi ──
              const Text(
                "Imtiyoz turi",
                style: TextStyle(
                    color: Color(0xB3FFFFFF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0D1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x0FFFFFFF)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBenefitType,
                    hint: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text("Imtiyoz turini tanlang...",
                          style: TextStyle(
                              color: Color(0x66FFFFFF), fontSize: 13)),
                    ),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1730),
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF6C5CE7)),
                    ),
                    items: kBenefitTypes
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  e.value,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedBenefitType = v;
                      _lostParentType = null;
                    }),
                  ),
                ),
              ),

              // Faqat '1'-tur uchun: ota yoki ona
              if (_selectedBenefitType == '1') ...[
                const SizedBox(height: 14),
                const Text(
                  "Vafot etgan boquvchi",
                  style: TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _RadioTile(
                        label: "Ota",
                        value: 'ota',
                        groupValue: _lostParentType,
                        onChanged: (v) =>
                            setState(() => _lostParentType = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RadioTile(
                        label: "Ona",
                        value: 'ona',
                        groupValue: _lostParentType,
                        onChanged: (v) =>
                            setState(() => _lostParentType = v),
                      ),
                    ),
                  ],
                ),
              ],

              // Xato xabari
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Tugmalar ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xB3FFFFFF),
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Bekor qilish",
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text("Saqlash",
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _RadioTile ─────────────────────────────────────────────────────
class _RadioTile extends StatelessWidget {
  final String label;
  final String value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioTile({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C5CE7).withOpacity(0.18)
              : const Color(0xFF0F0D1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF6C5CE7).withOpacity(0.5)
                : const Color(0x0FFFFFFF),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? const Color(0xFF6C5CE7)
                  : const Color(0x66FFFFFF),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0x99FFFFFF),
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? color : _C.bgCard,
        foregroundColor: selected ? Colors.white : color,
        elevation: 0,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? Colors.transparent : _C.faint),
        ),
      ),
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withOpacity(0.22)
                  : color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
