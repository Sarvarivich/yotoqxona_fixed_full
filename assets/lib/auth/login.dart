import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modules/models/user_model.dart';
import '../modules/services/api_service.dart';
import '../roles/admin_screen.dart';
import '../roles/mudir_screen.dart';
import '../roles/moliyachi_screen.dart';
import '../roles/talaba_profile_screen.dart';
import '../modules/girls/screens/admin/girls_admin_screen.dart';
import 'register.dart';

// ─── LoginScreen: loyihaning kirish sahifasi ───────────────────
// Muammo: login.dart da LoginScreen classi yo'q edi, faqat
// ProfileApp va LegacyStudentProfileScreen bor edi.
// Yechim: login.dart ni to'g'ri LoginScreen bilan almashtiramiz.

class LoginScreen extends StatefulWidget {
  final String hostel;

  const LoginScreen({
    super.key,
    required this.hostel,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ─── Ranglar
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
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // ✅ Laravel backend (yotoqxona_backend) orqali login.
      // ApiService.login() ichida token avtomatik saqlanadi
      // (SharedPreferences), shu sababli keyingi barcha so'rovlar
      // (to'lov yuborish, cheklarni ko'rish va h.k.) darhol ishlay
      // boshlaydi.
      final response = await ApiService().login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );

      final apiUser = response['user'];
      if (apiUser is! Map) {
        throw Exception("Server noto'g'ri javob qaytardi.");
      }

      final user =
          UserModel.fromApiJson(Map<String, dynamic>.from(apiUser));

// ====== HOSTEL TEKSHIRISH ======
// ✅ ADMIN / SUPERADMIN ikkala yotoqxonani ham (o'g'il bolalar va
// qiz bolalar) boshqarishi kerak bo'lgani uchun, ularning
// hostel_id'si odatda bo'sh (null) — bu tekshiruvdan chetlab
// o'tiladi. Shuningdek, hostel_id umuman to'ldirilmagan boshqa
// foydalanuvchilar (masalan ikkala yotoqxonaga xizmat qiluvchi
// moliyachi) ham "global" hisoblanadi.
      final bool isHostelCheckExempt = user.role == UserRole.superAdmin ||
          user.role == UserRole.admin ||
          user.hostel == null;

      if (!isHostelCheckExempt && user.hostel != widget.hostel) {
        await ApiService.clearToken();
        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              widget.hostel == 'boys'
                  ? "Bu login O'g'il bolalar yotoqxonasiga tegishli emas."
                  : "Bu login Qiz bolalar yotoqxonasiga tegishli emas.",
            ),
          ),
        );

        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Rolga qarab sahifaga yo'naltirish. Agar foydalanuvchi "girls"
      // (qizlar) yotoqxonasiga tegishli bo'lsa va roli admin/superAdmin/
      // mudir bo'lsa — alohida GirlsAdminScreen qobig'iga yo'naltiriladi.
      // ✅ Yo'naltirish saqlangan `user.hostel` qiymati emas, balki
      // admin/superAdmin AYNAN QAYSI tugmani bosgani (`widget.hostel`)
      // asosida amalga oshiriladi.
      final isGirlsHostel = widget.hostel == 'girls';

      Widget destination;
      if (isGirlsHostel &&
          (user.role == UserRole.superAdmin ||
              user.role == UserRole.admin ||
              user.role == UserRole.mudir)) {
        destination = GirlsAdminScreen(user: user);
      } else {
        switch (user.role) {
          case UserRole.superAdmin:
          case UserRole.admin:
            destination = AdminScreen(user: user);
            break;
          case UserRole.mudir:
            destination = MudirScreen(user: user);
            break;
          case UserRole.moliyachi:
            destination = MoliyachiScreen(user: user);
            break;
          case UserRole.talaba:
          default:
            destination = TalabaProfileScreen(user: user);
            break;
        }
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xatolik: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          // Fon glow orblari
          _GlowCircle(color: _purple, size: 280, top: -80, right: -60),
          _GlowCircle(color: _teal, size: 200, bottom: 100, left: -60),
          _GlowCircle(color: _pink, size: 150, top: 200, left: -40),

          // Asosiy kontent
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          // Logo — Qo'qon Universiteti rasmiy emblemasi
                          Hero(
                            tag: 'ku_logo',
                            child: Container(
                              width: 120,
                              height: 120,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 25,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/logo/kuhostel_logo.png',
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                  isAntiAlias: true,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          const SizedBox(height: 6),
                          Text(
                            'Tizimga kirish uchun ma\'lumotlaringizni kiriting',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _white.withOpacity(0.65),
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Login kartasi
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _white.withOpacity(0.07),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Email
                                _FieldLabel('Email manzil'),
                                const SizedBox(height: 8),
                                _LoginField(
                                  controller: _emailCtrl,
                                  hint: 'example@email.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Email kiriting';
                                    }
                                    if (!v.contains('@')) {
                                      return 'Email formati noto\'g\'ri';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Parol
                                _FieldLabel('Parol'),
                                const SizedBox(height: 8),
                                _LoginField(
                                  controller: _passwordCtrl,
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscure,
                                  suffixIcon: GestureDetector(
                                    onTap: () =>
                                        setState(() => _obscure = !_obscure),
                                    child: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: _white.withOpacity(0.4),
                                      size: 18,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Parol kiriting';
                                    }
                                    if (v.trim().length < 4) {
                                      return 'Parol kamida 4 ta belgi';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 28),

                                // Kirish tugmasi
                                _LoginButton(
                                  isLoading: _isLoading,
                                  onTap: _isLoading ? null : _login,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Ro'yxatdan o'tish havolasi
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Hisob yo'qmi? ",
                                style: TextStyle(
                                  color: _white.withOpacity(0.4),
                                  fontSize: 13,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                                child: const Text(
                                  "Ro'yxatdan o'tish",
                                  style: TextStyle(
                                    color: _violet,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
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

// ─── Yordamchi widgetlar ────────────────────────────────────────

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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(0.55),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _LoginField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffixIcon,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: const Color(0xFFfd79a8).withOpacity(0.7)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFfd79a8), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFfd79a8), fontSize: 11),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _LoginButton({required this.isLoading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [const Color(0xFF4a4070), const Color(0xFF6C5CE7)]
                : [const Color(0xFF6C5CE7), const Color(0xFF8B7CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Kirish',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}
