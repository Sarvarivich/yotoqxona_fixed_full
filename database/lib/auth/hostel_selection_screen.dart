import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login.dart';

// ─── HostelSelectionScreen: ilova ishga tushganda LOGIN sahifasidan
// OLDIN ochiladigan yotoqxona tanlash sahifasi. Foydalanuvchi 2 ta
// variantdan birini tanlaydi: "O'g'il bolalar uchun yotoqxona" yoki
// "Qiz bolalar uchun yotoqxona".
//
// "O'g'il bolalar uchun yotoqxona" bosilganda — Login sahifasi
// ochiladi (agar `destination` berilgan bo'lsa, eskicha xatti-harakat
// sifatida to'g'ridan-to'g'ri o'sha sahifaga o'tadi — masalan, boshqa
// joydan qayta chaqirilsa ham ishlayveradi).
//
// "Qiz bolalar uchun yotoqxona" bosilganda — hozircha alohida tizim
// tayyor emasligi haqida chiroyli "Tez kunda" sahifasi ko'rsatiladi.
// Kelajakda shu joyga qizlar yotoqxonasi uchun mustaqil oqim
// ulanishi mumkin.

class HostelSelectionScreen extends StatefulWidget {
  final Widget? destination;
  final String? userFullName;

  const HostelSelectionScreen({
    super.key,
    this.destination,
    this.userFullName,
  });

  @override
  State<HostelSelectionScreen> createState() => _HostelSelectionScreenState();
}

class _HostelSelectionScreenState extends State<HostelSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _bg = Color(0xFF0A0818);
  static const _card = Color(0xFF13102A);
  static const _purple = Color(0xFF6C5CE7);
  static const _violet = Color(0xFFa29bfe);
  static const _teal = Color(0xFF00CEC9);
  static const _pink = Color(0xFFfd79a8);
  static const _white = Colors.white;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _openBoys() {
    // Agar `destination` berilgan bo'lsa (eski xatti-harakat) — to'g'ridan
    // to'g'ri o'sha sahifaga o'tamiz. Aks holda (yangi oqim: bu ekran
    // ilova ochilganda birinchi bo'lib ko'rsatiladi) — Login sahifasiga
    // o'tamiz.
    if (widget.destination != null) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.destination!,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
        (route) => false,
      );
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(
          hostel: 'boys',
        ),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _openGirls() {
    // ✅ Qizlar yotoqxonasi tizimi endi ishga tushirilgan — shuning
    // uchun "Tez kunda" sahifasi o'rniga to'g'ridan-to'g'ri Login
    // sahifasiga o'tkazamiz (xuddi o'g'il bolalar oqimi kabi).
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(
          hostel: 'girls',
        ),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          _GlowCircle(color: _purple, size: 280, top: -80, right: -60),
          _GlowCircle(color: _teal, size: 200, bottom: 60, left: -60),
          _GlowCircle(color: _pink, size: 150, top: 260, left: -40),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 96,
                          height: 96,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _purple.withOpacity(0.35),
                                blurRadius: 28,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo/kuhostel_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.userFullName != null
                              ? 'Xush kelibsiz, ${widget.userFullName}!'
                              : 'Xush kelibsiz!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Davom etish uchun yotoqxona turini tanlang',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: _white.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 36),
                        _HostelChoiceCard(
                          title: "O'g'il bolalar uchun yotoqxona",
                          subtitle: 'Tizimga kirish',
                          icon: Icons.boy_outlined,
                          gradientColors: const [
                            Color(0xFF6C5CE7),
                            Color(0xFF00CEC9),
                          ],
                          onTap: _openBoys,
                        ),
                        const SizedBox(height: 20),
                        _HostelChoiceCard(
                          title: 'Qiz bolalar uchun yotoqxona',
                          subtitle: 'Tizimga kirish',
                          icon: Icons.girl_sharp,
                          gradientColors: const [
                            Color(0xFFfd79a8),
                            Color(0xFFa29bfe),
                          ],
                          onTap: _openGirls,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostelChoiceCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _HostelChoiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_HostelChoiceCard> createState() => _HostelChoiceCardState();
}

class _HostelChoiceCardState extends State<_HostelChoiceCard> {
  double _scale = 1;

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.97 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF13102A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.gradientColors.first.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.35),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, bottom, left, right;

  const _GlowCircle({
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
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: size,
              spreadRadius: size / 3,
            ),
          ],
        ),
      ),
    );
  }
}
