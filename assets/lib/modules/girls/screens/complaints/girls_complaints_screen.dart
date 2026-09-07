import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/complaint_model.dart';
import '../../../models/user_model.dart';
import '../../providers/girls_complaint_provider.dart';
import 'girls_complaint_details_screen.dart';

// ─── Creative LIGHT "Blossom" palette — Qizlar bo'limining boshqa
// sahifalari (Xonalar, To'lovlar) bilan bir xil mayin lavanda fon va
// gullab-yashnayotgan gradientlar, "maktub/karta" uslubidagi kartalar bilan.
class _LC {
  static const bg = Color(0xFFF6F1FB);
  static const card = Colors.white;
  static const card2 = Color(0xFFEDE8FA);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFA29BFE);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFFD79A8);
  static const rose = Color(0xFFE84393);
  static const orange = Color(0xFFFDCB6E);
  static const coral = Color(0xFFE17055);
  static const red = Color(0xFFE74C3C);
  static const ink = Color(0xFF2D2A4A);
  static const muted = Color(0xFF8B86A8);
  static const faint = Color(0xFFEDE8FA);
}

// ─── GirlsComplaintsScreen: Qizlar yotoqxonasi murojaatlari — hikoyaviy
// "maktub" uslubidagi kartalar va statistik hero header bilan.
class GirlsComplaintsScreen extends StatefulWidget {
  final UserModel? currentUser;
  const GirlsComplaintsScreen({super.key, this.currentUser});

  @override
  State<GirlsComplaintsScreen> createState() => _GirlsComplaintsScreenState();
}

class _GirlsComplaintsScreenState extends State<GirlsComplaintsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ComplaintStatus? _filter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.pending:
        return _LC.orange;
      case ComplaintStatus.reviewing:
        return _LC.violet;
      case ComplaintStatus.resolved:
        return _LC.mint;
      case ComplaintStatus.closed:
        return _LC.muted;
    }
  }

  IconData _statusIcon(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.pending:
        return Icons.hourglass_bottom_rounded;
      case ComplaintStatus.reviewing:
        return Icons.visibility_rounded;
      case ComplaintStatus.resolved:
        return Icons.check_circle_rounded;
      case ComplaintStatus.closed:
        return Icons.lock_rounded;
    }
  }

  Color _priorityColor(ComplaintPriority p) {
    switch (p) {
      case ComplaintPriority.low:
        return _LC.mint;
      case ComplaintPriority.medium:
        return _LC.orange;
      case ComplaintPriority.high:
        return _LC.red;
    }
  }

  bool _matchesSearch(ComplaintModel c) {
    if (_searchQuery.trim().isEmpty) return true;
    final q = _searchQuery.trim().toLowerCase();
    return c.studentName.toLowerCase().contains(q) ||
        c.title.toLowerCase().contains(q);
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GirlsComplaintProvider>();

    return Scaffold(
      backgroundColor: _LC.bg,
      body: StreamBuilder<List<ComplaintModel>>(
        stream: provider.complaints,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _LC.purple));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 56, color: _LC.coral),
                  const SizedBox(height: 16),
                  Text("Xatolik: ${snapshot.error}",
                      style: const TextStyle(color: _LC.muted)),
                ],
              ),
            );
          }

          final all = snapshot.data ?? [];
          var items = all;
          if (_filter != null) {
            items = items.where((c) => c.status == _filter).toList();
          }
          items = items.where(_matchesSearch).toList();

          final pending =
              all.where((c) => c.status == ComplaintStatus.pending).length;
          final reviewing =
              all.where((c) => c.status == ComplaintStatus.reviewing).length;
          final resolved =
              all.where((c) => c.status == ComplaintStatus.resolved).length;
          final urgent = all
              .where((c) =>
                  c.priority == ComplaintPriority.high &&
                  c.status != ComplaintStatus.resolved &&
                  c.status != ComplaintStatus.closed)
              .length;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                elevation: 0,
                backgroundColor: _LC.rose,
                expandedHeight: 200,
                iconTheme: const IconThemeData(color: Colors.white),
                title: const Text('Murojaatlar',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                flexibleSpace: FlexibleSpaceBar(
                  background: _ComplaintsHero(
                    pending: pending,
                    reviewing: reviewing,
                    resolved: resolved,
                    urgent: urgent,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _LC.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _LC.faint),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(
                          () => _searchQuery = value.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: "Talaba ismi yoki mavzu bo'yicha qidirish...",
                        hintStyle:
                            const TextStyle(color: _LC.muted, fontSize: 13),
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
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: 'Barchasi',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        for (final s in ComplaintStatus.values)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _FilterChip(
                              label: s.displayName,
                              selected: _filter == s,
                              onTap: () => setState(() => _filter = s),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.forum_outlined,
                    title: "Murojaatlar yo'q",
                    subtitle:
                        "Qizlar yotoqxonasida hali hech qanday murojaat yozilmagan",
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.search_off_rounded,
                    title: "Hech narsa topilmadi",
                    subtitle: "\"$_searchQuery\" bo'yicha murojaat topilmadi",
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(14),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final complaint = items[index];
                        return _buildComplaintCard(context, complaint);
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComplaintCard(BuildContext context, ComplaintModel complaint) {
    final statusColor = _statusColor(complaint.status);
    final priorityColor = _priorityColor(complaint.priority);
    final isHigh = complaint.priority == ComplaintPriority.high;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _LC.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isHigh ? priorityColor.withOpacity(0.4) : _LC.faint,
            width: isHigh ? 1.2 : 1),
        boxShadow: [
          BoxShadow(
              color: _LC.purple.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GirlsComplaintDetailsScreen(
                  complaint: complaint, currentUser: widget.currentUser),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar — talaba ismi bosh harflari (yoki anonim ikonka)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: complaint.isAnonymous
                              ? [_LC.muted, const Color(0xFF6B6690)]
                              : [_LC.pink, _LC.purple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: complaint.isAnonymous
                            ? const Icon(Icons.person_off_rounded,
                                color: Colors.white, size: 20)
                            : Text(_initials(complaint.studentName),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            complaint.title,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: _LC.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            complaint.isAnonymous
                                ? 'Anonim talaba'
                                : complaint.studentName,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: _LC.muted,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isHigh)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.priority_high_rounded,
                            color: priorityColor, size: 15),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  complaint.description,
                  style: const TextStyle(
                      fontSize: 12.5, color: _LC.muted, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: _LC.purple.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        complaint.category,
                        style: const TextStyle(
                            fontSize: 9.5,
                            color: _LC.violet,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(_statusIcon(complaint.status),
                        size: 13, color: statusColor),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        complaint.status.displayName,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Statistik hero — murojaatlar bo'yicha umumiy holat: kutilmoqda,
// ko'rib chiqilmoqda, hal qilindi va shoshilinch sonlari.
class _ComplaintsHero extends StatelessWidget {
  final int pending;
  final int reviewing;
  final int resolved;
  final int urgent;
  const _ComplaintsHero({
    required this.pending,
    required this.reviewing,
    required this.resolved,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_LC.rose, _LC.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            right: -10,
            child: Icon(Icons.forum_rounded,
                size: 110, color: Colors.white.withOpacity(0.1)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Qizlar murojaatlari',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 19)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _HeroStat(
                          color: _LC.orange,
                          icon: Icons.hourglass_bottom_rounded,
                          label: 'Kutilmoqda',
                          value: '$pending'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroStat(
                          color: _LC.violet,
                          icon: Icons.visibility_rounded,
                          label: "Ko'rilmoqda",
                          value: '$reviewing'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroStat(
                          color: _LC.mint,
                          icon: Icons.check_circle_rounded,
                          label: 'Hal qilindi',
                          value: '$resolved'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroStat(
                          color: _LC.red,
                          icon: Icons.priority_high_rounded,
                          label: 'Shoshilinch',
                          value: '$urgent'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String value;
  const _HeroStat(
      {required this.color,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(height: 5),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const SizedBox(height: 1),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration:
                  BoxDecoration(color: _LC.card, shape: BoxShape.circle),
              child: Icon(icon, size: 46, color: _LC.violet),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: _LC.ink)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(color: _LC.muted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_LC.pink, _LC.purple])
              : null,
          color: selected ? null : _LC.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.transparent : _LC.faint),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : _LC.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
