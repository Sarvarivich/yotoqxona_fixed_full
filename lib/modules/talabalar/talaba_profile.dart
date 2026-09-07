import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Ushbu faylni oldingi student_home_screen.dart dagi AppColors bilan birga ishlating.
// AppColors class shu faylda ham qo'shilgan (standalone ishlatish uchun).

void main() {
  runApp(const ProfileApp());
}

class ProfileApp extends StatelessWidget {
  const ProfileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Profil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'SF Pro Display',
        scaffoldBackgroundColor: const Color(0xFF0F0D1A),
      ),
      home: const LegacyStudentProfileScreen(),
    );
  }
}

// ─── Colors ────────────────────────────────────────────────────
class _C {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1E1B2E);
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

// ─── Screen ────────────────────────────────────────────────────
class LegacyStudentProfileScreen extends StatelessWidget {
  const LegacyStudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ));

    return Scaffold(
      backgroundColor: _C.bgBase,
      body: Stack(
        children: [
          // Glow orbs
          _GlowOrb(color: _C.purple, size: 220, top: -60, right: -30),
          _GlowOrb(color: _C.pink, size: 180, bottom: 300, left: -40),

          // Scrollable content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _TopBar()),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _HeroCard(),
                    const SizedBox(height: 16),
                    const _StatsStrip(),
                    const SizedBox(height: 16),
                    const _InfoCard(
                      title: 'Shaxsiy ma\'lumotlar',
                      iconColor: _C.violet,
                      iconBg: Color(0x2Ea29bfe),
                      icon: Icons.person_outline_rounded,
                      rows: [
                        _InfoRow(
                          icon: Icons.badge_outlined,
                          label: 'Ism familya',
                          value: 'Asliddin',
                        ),
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Telefon',
                          value: '+998908527292',
                        ),
                        _InfoRow(
                          icon: Icons.perm_identity_outlined,
                          label: 'Student ID',
                          value: '—',
                          valueMuted: true,
                        ),
                        _InfoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: 'asliddin@talaba.uz',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _InfoCard(
                      title: 'Xona ma\'lumotlari',
                      iconColor: _C.teal,
                      iconBg: Color(0x2600CEC9),
                      icon: Icons.apartment_outlined,
                      rows: [
                        _InfoRow(
                          icon: Icons.door_front_door_outlined,
                          label: 'Xona raqami',
                          value: '214-B',
                        ),
                        _InfoRow(
                          icon: Icons.layers_outlined,
                          label: 'Qavat / Blok',
                          value: '2-qavat · Blok A',
                        ),
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Shartnoma tugashi',
                          value: '2025-07-01',
                          valueColor: _C.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _LogoutButton(),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),

          // Bottom nav
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomNav(),
          ),
        ],
      ),
    );
  }
}

// ─── Glow Orb ──────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, bottom, left, right;

  const _GlowOrb({
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.13),
        ),
      ),
    );
  }
}

// ─── Top Bar ───────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      child: Row(
        children: [
          const Text(
            'Mening profilim',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _C.white,
            ),
          ),
          const Spacer(),
          _IconBtn(icon: Icons.edit_outlined, onTap: () {}),
          const SizedBox(width: 10),
          _IconBtn(icon: Icons.qr_code_2_rounded, onTap: () {}),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: _C.soft),
      ),
    );
  }
}

// ─── Hero Card ─────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B2E), Color(0xFF2D2060), Color(0xFF1A1535)],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: _C.purple.withOpacity(0.25)),
      ),
      child: Stack(
        children: [
          // Background glow top-right
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _C.purple.withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Background glow bottom-left
          Positioned(
            bottom: -40,
            left: 50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _C.teal.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Avatar + info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_C.purple, _C.violet, _C.pink],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Online dot
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _C.mint,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1E1B2E),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      // Camera button
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _C.purple,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF1E1B2E),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asliddin',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _C.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'asliddin@talaba.uz',
                            style: TextStyle(
                              fontSize: 12,
                              color: _C.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _C.purple.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _C.violet.withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.school_outlined,
                                  size: 11,
                                  color: _C.violet,
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'TALABA',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _C.violet,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Edit + share buttons
              Row(
                children: [
                  Expanded(
                    child: _HeroActionBtn(
                      icon: Icons.edit_outlined,
                      label: 'Profilni tahrirlash',
                      color: _C.violet,
                      bg: _C.purple.withOpacity(0.2),
                      border: _C.purple.withOpacity(0.35),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeroIconBtn(
                    icon: Icons.share_outlined,
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg, border;
  final VoidCallback onTap;

  const _HeroActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, size: 18, color: _C.muted),
      ),
    );
  }
}

// ─── Stats Strip ───────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _StatBox(
            icon: Icons.calendar_month_outlined,
            value: '0',
            label: 'Kun',
            valueColor: _C.violet,
            iconColor: _C.violet,
            iconBg: Color(0x2Ea29bfe),
            topGradient: [_C.purple, _C.violet],
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.receipt_long_outlined,
            value: '0',
            label: 'To\'lov',
            valueColor: _C.teal,
            iconColor: _C.teal,
            iconBg: Color(0x2200CEC9),
            topGradient: [_C.teal, _C.mint],
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.description_outlined,
            value: '0',
            label: 'Ariza',
            valueColor: _C.orange,
            iconColor: _C.orange,
            iconBg: Color(0x22fdcb6e),
            topGradient: [_C.orange, _C.coral],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color valueColor, iconColor, iconBg;
  final List<Color> topGradient;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.valueColor,
    required this.iconColor,
    required this.iconBg,
    required this.topGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.faint),
      ),
      child: Column(
        children: [
          // Top accent bar
          Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: topGradient),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: _C.muted,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Card ─────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final Color iconColor;
  final Color iconBg;
  final IconData icon;
  final List<_InfoRow> rows;

  const _InfoCard({
    required this.title,
    required this.iconColor,
    required this.iconBg,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.faint),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _C.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x0DFFFFFF), height: 1),

          // Rows
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return Column(
              children: [
                e.value,
                if (!isLast)
                  const Divider(
                    color: Color(0x0AFFFFFF),
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool valueMuted;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueMuted = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Icon(icon, size: 17, color: _C.muted),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.45),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueMuted ? _C.muted : (valueColor ?? _C.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Logout Button ─────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E1B2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Chiqish',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            content: Text(
              'Hisobdan chiqishni tasdiqlaysizmi?',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Bekor qilish',
                    style: TextStyle(color: Color(0xFFa29bfe))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Chiqish',
                    style: TextStyle(color: Color(0xFFfd79a8))),
              ),
            ],
          ),
        );
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _C.pink.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.pink.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, size: 18, color: _C.pink),
            SizedBox(width: 8),
            Text(
              'Chiqish',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _C.pink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Nav ────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, Icons.home_outlined, 'Bosh', false),
      (Icons.apartment_rounded, Icons.apartment_outlined, 'Yotoqxona', false),
      (
        Icons.receipt_long_rounded,
        Icons.receipt_long_outlined,
        'To\'lovlar',
        false
      ),
      (Icons.person_rounded, Icons.person_outline_rounded, 'Profil', true),
    ];

    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          color: _C.bgBase.withOpacity(0.96),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        padding: EdgeInsets.only(
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          left: 20,
          right: 20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final isActive = item.$4;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _C.purple.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isActive ? item.$1 : item.$2,
                    color: isActive ? _C.violet : _C.muted,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$3,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: isActive ? _C.violet : _C.muted,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
