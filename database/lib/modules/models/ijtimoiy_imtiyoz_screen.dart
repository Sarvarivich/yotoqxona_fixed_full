import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_model.dart';

// ─── Creative LIGHT palette (tolov_cheklari_screen bilan bir xil til) ───
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

// 🎗️ Imtiyoz turi kodini ('1'..'6') o'qish uchun to'liq matnga o'giradi.
String benefitTypeLabel(String? type) {
  switch (type) {
    case '1':
      return "Boquvchini yo'qotgan talaba";
    case '2':
      return "1 yoki 2 guruh nogironligi bo'lgan talaba";
    case '3':
      return "To'liq davlat ta'minotida bo'lgan talaba (chin yetim)";
    case '4':
      return "Temir daftariga tushgan talaba";
    case '5':
      return "Yoshlar daftariga tushgan talaba";
    case '6':
      return "Ayollar daftariga tushgan talaba";
    default:
      return "Imtiyoz turi ko'rsatilmagan";
  }
}

// Har bir imtiyoz turi uchun alohida rang — kartalarda vizual farqlash uchun.
Color benefitTypeColor(String? type) {
  switch (type) {
    case '1':
      return _LC.coral;
    case '2':
      return _LC.purple;
    case '3':
      return _LC.teal;
    case '4':
      return _LC.orange;
    case '5':
      return _LC.mint;
    case '6':
      return _LC.pink;
    default:
      return _LC.muted;
  }
}

String _lostParentLabel(String? value) {
  switch (value) {
    case 'ota':
      return 'Otasidan';
    case 'ona':
      return 'Onasidan';
    default:
      return "Noma'lum";
  }
}

/// 🎗️ ADMIN uchun: barcha talabalar ro'yxatdan o'tishda yuklagan
/// "Ijtimoiy imtiyoz" ma'lumotlari (imtiyoz turi + tasdiqlovchi hujjat/rasm)
/// shu yerda bitta joyda ko'rinadi. "O'g'il bolalar" / "Qiz bolalar"
/// tugmalari orqali ikkala yotoqxona orasida almashtiriladi, ism yoki
/// sana bo'yicha qidirish ham mavjud — dizayn "To'lov cheklari"
/// bo'limi bilan bir xil vizual tilda qurilgan.
class IjtimoiyImtiyozScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final String? initialHostel;

  const IjtimoiyImtiyozScreen({
    super.key,
    this.onBack,
    this.initialHostel,
  });

  @override
  State<IjtimoiyImtiyozScreen> createState() => _IjtimoiyImtiyozScreenState();
}

class _IjtimoiyImtiyozScreenState extends State<IjtimoiyImtiyozScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  late String _selectedHostel;

  @override
  void initState() {
    super.initState();
    final forced = (widget.initialHostel ?? '').trim();
    _selectedHostel = (forced.isEmpty ? 'boys' : forced).toLowerCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        title: const Text("Ijtimoiy imtiyozlar",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_LC.purple, _LC.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Orqaga',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              widget.onBack?.call();
            }
          },
        ),
      ),
      body: Column(
        children: [
          // 🚻 Yotoqxona turini tanlash
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: SizedBox(
              height: 46,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedHostel == "boys"
                            ? _LC.purple
                            : Colors.white,
                        foregroundColor: _selectedHostel == "boys"
                            ? Colors.white
                            : _LC.purple,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: _selectedHostel == "boys"
                                  ? Colors.transparent
                                  : _LC.faint),
                        ),
                      ),
                      onPressed: () {
                        setState(() => _selectedHostel = "boys");
                      },
                      child: const Text("O'g'il bolalar"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedHostel == "girls"
                            ? _LC.purple
                            : Colors.white,
                        foregroundColor: _selectedHostel == "girls"
                            ? Colors.white
                            : _LC.purple,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: _selectedHostel == "girls"
                                  ? Colors.transparent
                                  : _LC.faint),
                        ),
                      ),
                      onPressed: () {
                        setState(() => _selectedHostel = "girls");
                      },
                      child: const Text("Qiz bolalar"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 🔎 Ism yoki sana bo'yicha qidiruv
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Container(
              decoration: BoxDecoration(
                color: _LC.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _LC.faint),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText:
                      "Ism yoki sana (masalan 17.07.2026) bo'yicha qidirish...",
                  hintStyle: const TextStyle(color: _LC.muted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _LC.purple, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: _LC.muted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    // ✅ Faqat "talaba" rolidagilarni so'raymiz, so'ng "Ijtimoiy imtiyozga
    // egaman" deb belgilaganlarini (hasSocialBenefit == true) mahalliy
    // filtrlaymiz — bu maydon UserModel.additionalData orqali hujjatning
    // TO'G'RIDAN-TO'G'RI ustida saqlanadi (register.dart / auth_service.dart
    // ga qarang), shu bois qo'shimcha composite index shart emas.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .where('role', isEqualTo: UserRole.talaba.name)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 56, color: _LC.coral),
                  const SizedBox(height: 12),
                  Text(
                    "Ma'lumotlarni yuklashda xatolik: ${snap.error}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _LC.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          );
        }

        final allDocs = snap.data?.docs ?? [];

        // 🎗️ Faqat ijtimoiy imtiyozni tanlagan talabalar
        final benefitDocs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['hasSocialBenefit'] == true;
        }).toList();

        // 🚻 Tanlangan yotoqxona bo'yicha filtrlaymiz
        final docs = benefitDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final hostel = (d['hostel'] ?? '').toString().trim().toLowerCase();
          final normalized = hostel.isEmpty ? 'boys' : hostel;
          return normalized == _selectedHostel;
        }).toList();

        // 🔎 Ism yoki ro'yxatdan o'tgan sana bo'yicha mahalliy qidirish
        final filteredDocs = _searchQuery.isEmpty
            ? docs
            : docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final fullName =
                    (d['fullName'] ?? '').toString().toLowerCase();
                if (fullName.contains(_searchQuery)) return true;

                String fmt(dynamic ts) {
                  if (ts == null) return '';
                  try {
                    final dt = (ts as dynamic).toDate() as DateTime;
                    final dd = dt.day.toString().padLeft(2, '0');
                    final mm = dt.month.toString().padLeft(2, '0');
                    return '$dd.$mm.${dt.year}';
                  } catch (_) {
                    return '';
                  }
                }

                return fmt(d['createdAt']).contains(_searchQuery);
              }).toList();

        // Eng yangi ro'yxatdan o'tganlar tepada ko'rinsin
        filteredDocs.sort((a, b) {
          final da = (a.data() as Map<String, dynamic>)['createdAt'];
          final db = (b.data() as Map<String, dynamic>)['createdAt'];
          final ta = da is Timestamp ? da.millisecondsSinceEpoch : 0;
          final tb = db is Timestamp ? db.millisecondsSinceEpoch : 0;
          return tb.compareTo(ta);
        });

        if (filteredDocs.isEmpty) {
          final noResultsForSearch = _searchQuery.isNotEmpty;
          final hostelLabel =
              _selectedHostel == "boys" ? "O'g'il bolalar" : "Qiz bolalar";
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  noResultsForSearch
                      ? Icons.search_off_rounded
                      : Icons.volunteer_activism_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Text(
                  noResultsForSearch
                      ? "\"$_searchQuery\" bo'yicha talaba topilmadi"
                      : "$hostelLabel: ijtimoiy imtiyozli talabalar yo'q",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filteredDocs.length,
          itemBuilder: (context, i) {
            final doc = filteredDocs[i];
            final d = doc.data() as Map<String, dynamic>;
            return _buildBenefitCard(d);
          },
        );
      },
    );
  }

  Widget _buildBenefitCard(Map<String, dynamic> d) {
    final studentName = (d['fullName'] ?? "Noma'lum talaba") as String;
    final benefitType = d['benefitType'] as String?;
    final lostParentType = d['lostParentType'] as String?;
    final deathCertificateUrl = (d['deathCertificateUrl'] ?? '') as String;
    final benefitDocumentUrl = (d['benefitDocumentUrl'] ?? '') as String;
    final faculty = (d['faculty'] ?? '') as String;
    final course = (d['course'] ?? '') as String;
    final color = benefitTypeColor(benefitType);

    final ts = d['createdAt'];
    String dateStr = '—';
    if (ts != null) {
      try {
        final dt = (ts as dynamic).toDate() as DateTime;
        dateStr =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
      } catch (_) {}
    }

    // Talaba yuklagan hujjat: 1-tur uchun o'lim varaqasi, 2—6 turlar
    // uchun mos ma'lumotnoma. Ba'zan ikkalasi bo'sh bo'lishi mumkin
    // (talaba imtiyozni tanlagan-u, hujjatni hali yuklamagan).
    final fileUrl =
        deathCertificateUrl.isNotEmpty ? deathCertificateUrl : benefitDocumentUrl;
    final fileLabel = deathCertificateUrl.isNotEmpty
        ? "O'lim guvohnomasi"
        : "Imtiyoz ma'lumotnomasi";

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _LC.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _LC.faint),
        boxShadow: [
          BoxShadow(
            color: _LC.purple.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_LC.purple, _LC.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: _LC.ink)),
                      Text(
                        _subtitleFor(faculty, course, dateStr),
                        style:
                            const TextStyle(fontSize: 12, color: _LC.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Imtiyozli',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 🎗️ Imtiyoz turi va (agar mos bo'lsa) kimdan ajralgani
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.volunteer_activism_rounded,
                    label: "Imtiyoz turi",
                    value: benefitTypeLabel(benefitType),
                    valueColor: color,
                  ),
                ),
                if (benefitType == '1') ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.family_restroom_rounded,
                      label: "Kimdan ajralgan",
                      value: _lostParentLabel(lostParentType),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (fileUrl.isEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _LC.orange.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _LC.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: _LC.orange, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Tasdiqlovchi hujjat hali yuklanmagan",
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _LC.ink),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (_isImageUrl(fileUrl)) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    fileUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _LC.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _LC.faint),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isImageUrl(fileUrl)
                          ? Icons.image_rounded
                          : Icons.picture_as_pdf_rounded,
                      color:
                          _isImageUrl(fileUrl) ? _LC.purple : _LC.coral,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fileLabel,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _LC.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _LC.purple,
                    side: BorderSide(color: _LC.purple.withOpacity(0.35)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.file_download_rounded, size: 18),
                  label: const Text(
                    'Hujjatni yuklab olish',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse(fileUrl);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Karta sarlavhasi ostidagi qisqa matn: "Fakultet · N-kurs · sana"
  // (fakultet/kurs bo'sh bo'lsa, faqat sana ko'rsatiladi).
  String _subtitleFor(String faculty, String course, String dateStr) {
    final parts = <String>[
      if (faculty.isNotEmpty) faculty,
      if (course.isNotEmpty) "$course-kurs",
    ];
    if (parts.isEmpty) return "Ro'yxatdan o'tgan: $dateStr";
    return "${parts.join(' · ')} · $dateStr";
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp', '.gif']
        .any((ext) => lower.contains(ext));
  }
}

// Imtiyoz turi / qo'shimcha ma'lumot uchun chip
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _LC.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _LC.faint),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _LC.purple),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9.5, color: _LC.muted),
                ),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? _LC.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// "Ijtimoiy imtiyozli" talabalar soni bo'yicha real-time badge — drawer
// menyusida (masalan "To'lov cheklari"dagi kabi) ko'rsatish uchun.
class IjtimoiyImtiyozBadge extends StatelessWidget {
  const IjtimoiyImtiyozBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .where('hasSocialBenefit', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _LC.pink,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
