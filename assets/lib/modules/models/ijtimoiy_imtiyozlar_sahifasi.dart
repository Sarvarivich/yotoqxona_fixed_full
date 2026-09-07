import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/register.dart' show kBenefitTypes;
import '../models/user_model.dart';

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

  const IjtimoiyImtiyozlarSahifasi({super.key, this.initialHostel});

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

  @override
  void initState() {
    super.initState();
    final forced = (widget.initialHostel ?? '').trim().toLowerCase();
    _selectedHostel = forced.isNotEmpty ? forced : 'boys';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bgBase,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('foydalanuvchilar')
            .where('hasSocialBenefit', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Ma'lumotlarni yuklashda xatolik: ${snapshot.error}",
                style: const TextStyle(color: _C.soft),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _C.purple),
            );
          }

          final allUsers = snapshot.data!.docs.map((doc) {
            final data =
                Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
            data['id'] = doc.id;
            return UserModel.fromJson(data);
          }).toList();

          final boysCount =
              allUsers.where((u) => (u.hostel ?? 'boys') != 'girls').length;
          final girlsCount =
              allUsers.where((u) => (u.hostel ?? 'boys') == 'girls').length;

          var visible = allUsers
              .where((u) => (u.hostel ?? 'boys') == _selectedHostel)
              .toList();

          if (_searchQuery.isNotEmpty) {
            visible = visible
                .where((u) => u.fullName.toLowerCase().contains(_searchQuery))
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
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                        itemCount: visible.length,
                        itemBuilder: (context, i) =>
                            _buildStudentCard(visible[i]),
                      ),
              ),
            ],
          );
        },
      ),
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
