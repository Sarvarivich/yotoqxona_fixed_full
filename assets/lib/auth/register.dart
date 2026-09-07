import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../modules/services/auth_service.dart';
import '../modules/models/user_model.dart'; // UserRole enumi va kFaculties uchun shart
import '../modules/models/uzbekistan_region.dart'; // Viloyat/tuman ro'yxati
import '../modules/widgets/application_stepper.dart';

// ─── RegisterScreen: talaba o'zini ro'yxatdan o'tkazadigan sahifa ─────
// Login sahifasi bilan bir xil vizual til (quyuq fon, glow doiralar,
// gradient kartalar) asosida, ammo o'ziga xos kreativ qo'shimchalar
// bilan: bosqichma-bosqich progress, parol kuchi indikatori, animatsiyalar.

// 🎗️ Ijtimoiy imtiyoz turlari — "Ha" tanlanganda ochiladigan ro'yxat
const List<MapEntry<String, String>> kBenefitTypes = [
  MapEntry('1', "Boquvchini yo'qotgan talaba"),
  MapEntry('2', "1 yoki 2 guruh nogironligi bo'lgan talaba"),
  MapEntry('3', "To'liq davlat ta'minotida bo'lgan talaba (chin yetim)"),
  MapEntry('4', "Temir daftariga tushgan talaba"),
  MapEntry('5', "Yoshlar daftariga tushgan talaba"),
  MapEntry('6', "Ayollar daftariga tushgan talaba"),
];

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  // 🆔 Pasport seriya-raqami (masalan: AD1234567) va JSHSHIR (14 xonali)
  final _passportController = TextEditingController();
  final _jshshirController = TextEditingController();

  // 🔒 Qat'iy nazorat: Rol har doim faqat talaba bo'ladi, dropdown o'chirildi
  final UserRole _fixedRole = UserRole.talaba;

  // 🎓 Talaba o'z fakultetini tanlashi shart
  String? _selectedFaculty;

  // 📚 Talaba o'zi o'qiyotgan joriy kursini tanlashi shart (1—4)
  String? _selectedCourse;

  // 🎂 Tug'ilgan sana
  DateTime? _birthDate;

  // 📍 Viloyat va tuman/shahar — viloyat tanlanganda tuman ro'yxati
  // shunga mos ravishda yangilanadi.
  String? _selectedRegion;
  String? _selectedDistrict;

  // 🏠 Talaba qaysi yotoqxona turiga tegishli ekanini tanlashi shart —
  // parol qo'yishdan OLDIN tanlanadi. Login qilganda faqat shu
  // yotoqxonaga tegishli ma'lumotlarni ko'radi.
  String? _selectedHostel;

  // 🎗️ Ijtimoiy imtiyoz — "Siz ijtimoiy imtiyozga egamisiz?" savoliga
  // javob. Boshlang'ich holatda avtomatik "Yo'q" tanlangan bo'ladi.
  bool _hasSocialBenefit = false;

  // Tanlangan imtiyoz turi: '1'..'6' (pastdagi _kBenefitTypes ro'yxatiga qarang)
  String? _selectedBenefitType;

  // Faqat 1-tur ("Boquvchini yo'qotgan talaba") uchun: ota yoki ona
  String? _lostParentType;

  // Yuklangan hujjatlar
  PlatformFile? _deathCertificateFile; // 1-tur: o'lim varaqasi
  PlatformFile? _benefitDocumentFile; // 2—6 turlar uchun umumiy ma'lumotnoma

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  double _passwordStrength = 0;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ─── Ranglar (login.dart bilan bir xil palitra)
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

    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _passportController.dispose();
    _jshshirController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength() {
    final value = _passwordController.text;
    double strength = 0;
    if (value.length >= 6) strength += 0.34;
    if (value.length >= 10) strength += 0.16;
    if (RegExp(r'[A-Z]').hasMatch(value)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(value)) strength += 0.2;
    if (RegExp(r'[!@#\$&*~._-]').hasMatch(value)) strength += 0.1;
    setState(() => _passwordStrength = strength.clamp(0, 1));
  }

  Color get _strengthColor {
    if (_passwordStrength < 0.34) return _pink;
    if (_passwordStrength < 0.7) return const Color(0xFFffb020);
    return _teal;
  }

  String get _strengthLabel {
    if (_passwordController.text.isEmpty) return '';
    if (_passwordStrength < 0.34) return 'Zaif';
    if (_passwordStrength < 0.7) return "O'rtacha";
    return 'Kuchli';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Parollar mos kelmadi"),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Davom etish uchun shartlarga rozilik bildiring"),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedHostel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Yotoqxona turini tanlang"),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tug'ilgan sanangizni tanlang"),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedRegion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Viloyatingizni tanlang"),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tuman/shahringizni tanlang"),
          backgroundColor: _pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 🎗️ Ijtimoiy imtiyoz tanlangan bo'lsa — turi va tegishli
    // hujjat(lar) to'liq to'ldirilganini tekshiramiz.
    if (_hasSocialBenefit) {
      if (_selectedBenefitType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Imtiyoz turini tanlang"),
            backgroundColor: _pink,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_selectedBenefitType == '1') {
        if (_lostParentType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ota yoki onani tanlang"),
              backgroundColor: _pink,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        if (_deathCertificateFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("O'lim varaqasini (PDF) yuklang"),
              backgroundColor: _pink,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      } else if (_benefitDocumentFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tegishli ma'lumotnomani yuklang"),
            backgroundColor: _pink,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    await AuthService.registerAndLoginUser(
      context: context,
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      role: _fixedRole, // 🎯 Faqat talaba roli uzatiladi
      hostel: _selectedHostel!,
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      faculty: _selectedFaculty,
      course: _selectedCourse,
      passportId: _passportController.text.trim().isEmpty
          ? null
          : _passportController.text.trim().toUpperCase(),
      jshshir: _jshshirController.text.trim().isEmpty
          ? null
          : _jshshirController.text.trim(),
      birthDate: _birthDate,
      region: _selectedRegion,
      district: _selectedDistrict,
      hasSocialBenefit: _hasSocialBenefit,
      benefitType: _hasSocialBenefit ? _selectedBenefitType : null,
      lostParentType: _hasSocialBenefit && _selectedBenefitType == '1'
          ? _lostParentType
          : null,
      deathCertificateFile: _hasSocialBenefit && _selectedBenefitType == '1'
          ? _deathCertificateFile
          : null,
      benefitDocumentFile: _hasSocialBenefit && _selectedBenefitType != '1'
          ? _benefitDocumentFile
          : null,
    );
  }

  // 🎗️ 2—6 imtiyoz turlari uchun yuklash maydoni ostidagi izoh matni
  String _benefitDocumentLabel(String type) {
    switch (type) {
      case '2':
        return "Nogironligi borligi haqida ma'lumotnomani yuklang";
      case '3':
        return "To'liq davlat ta'minotidaligi haqidagi ma'lumotni yuklang";
      case '4':
        return "Temir daftariga yozilganligi haqidagi ma'lumotnomani yuklang";
      case '5':
        return "Yoshlar daftariga yozilganligi haqidagi ma'lumotnomani yuklang";
      case '6':
        return "Ayollar daftariga yozilganligi haqidagi ma'lumotnomani yuklang";
      default:
        return "Tegishli ma'lumotnomani yuklang";
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
          _GlowCircle(color: _teal, size: 260, top: -70, left: -60),
          _GlowCircle(color: _purple, size: 220, bottom: 60, right: -60),
          _GlowCircle(color: _pink, size: 150, top: 260, right: -30),

          SafeArea(
            child: Column(
              children: [
                // Orqaga qaytish
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: _white.withOpacity(0.7), size: 18),
                      ),
                    ],
                  ),
                ),

                Expanded(
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
                                // Logo
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_teal, _purple],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _teal.withOpacity(0.4),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person_add_alt_1_rounded,
                                    color: _white,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                const Text(
                                  'Talaba sifatida ro\'yxatdan o\'tish',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: _white,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Yotoqxona tizimidan foydalanish uchun ma'lumotlaringizni to'ldiring",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _white.withOpacity(0.45),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const ApplicationStepper(
                                  activeStep: 1,
                                  subtitle: "Arizani to'ldirish bosqichi",
                                ),
                                const SizedBox(height: 20),

                                // Ro'yxatdan o'tish kartasi
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _SectionLabel(
                                        icon: Icons.badge_outlined,
                                        text: 'Shaxsiy ma\'lumotlar',
                                      ),
                                      const SizedBox(height: 14),

                                      _FieldLabel('To\'liq ismingiz'),
                                      const SizedBox(height: 8),
                                      _AuthField(
                                        controller: _nameController,
                                        hint: 'Ism Familiya',
                                        icon: Icons.person_outline_rounded,
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Ismni kiriting'
                                            : (v.trim().length < 3
                                                ? 'Ism kamida 3 harf bo\'lsin'
                                                : null),
                                      ),
                                      const SizedBox(height: 16),

                                      _FieldLabel("Tug'ilgan sanangiz"),
                                      const SizedBox(height: 8),
                                      _DateOfBirthField(
                                        value: _birthDate,
                                        onChanged: (date) =>
                                            setState(() => _birthDate = date),
                                      ),
                                      const SizedBox(height: 16),

                                      _FieldLabel('Viloyatingizni tanlang'),
                                      const SizedBox(height: 8),
                                      _RegionDropdown(
                                        value: _selectedRegion,
                                        onChanged: (val) => setState(() {
                                          _selectedRegion = val;
                                          // Viloyat almashtirilganda avvalgi
                                          // tuman endi mos kelmasligi mumkin
                                          // — tozalab qo'yamiz.
                                          _selectedDistrict = null;
                                        }),
                                      ),
                                      const SizedBox(height: 16),

                                      _FieldLabel("Tuman/shahringizni tanlang"),
                                      const SizedBox(height: 8),
                                      _DistrictDropdown(
                                        region: _selectedRegion,
                                        value: _selectedDistrict,
                                        onChanged: (val) => setState(
                                            () => _selectedDistrict = val),
                                      ),

                                      const SizedBox(height: 16),

                                      _FieldLabel('Email manzil yarating !'),
                                      const SizedBox(height: 8),
                                      _AuthField(
                                        controller: _emailController,
                                        hint: 'example@gmail.com',
                                        icon: Icons.email_outlined,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Email kiriting';
                                          }
                                          if (!v.contains('@') ||
                                              !v.contains('.')) {
                                            return 'Noto\'g\'ri email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      _FieldLabel(
                                          'Telefon raqamingizni kiriting'),
                                      const SizedBox(height: 8),
                                      _AuthField(
                                        controller: _phoneController,
                                        hint: '+998 XX XXX XX XX',
                                        icon: Icons.phone_outlined,
                                        keyboardType: TextInputType.phone,
                                      ),
                                      const SizedBox(height: 16),

                                      _FieldLabel('Pasport seriya va raqami'),
                                      const SizedBox(height: 8),
                                      _AuthField(
                                        controller: _passportController,
                                        hint: 'Masalan: AD1234567',
                                        icon: Icons.badge_outlined,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                              RegExp(r'[A-Za-z0-9]')),
                                          LengthLimitingTextInputFormatter(9),
                                        ],
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Pasport ma\'lumotini kiriting';
                                          }
                                          if (!RegExp(r'^[A-Za-z]{2}\d{7}$')
                                              .hasMatch(v.trim())) {
                                            return 'Format: AA1234567 (2 harf + 7 raqam)';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      _FieldLabel('JSHSHIR'),
                                      const SizedBox(height: 8),
                                      _AuthField(
                                        controller: _jshshirController,
                                        hint: '14 xonali JSHSHIR raqami',
                                        icon: Icons.fingerprint_rounded,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(14),
                                        ],
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'JSHSHIR raqamini kiriting';
                                          }
                                          if (v.trim().length != 14) {
                                            return 'JSHSHIR 14 ta raqamdan iborat bo\'lishi kerak';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      _FieldLabel('Fakultetingizni tanlang'),
                                      const SizedBox(height: 8),
                                      _FacultyDropdown(
                                        value: _selectedFaculty,
                                        onChanged: (val) => setState(
                                            () => _selectedFaculty = val),
                                      ),
                                      const SizedBox(height: 16),

                                      // 📚 Joriy kurs — 1, 2, 3 yoki 4.
                                      // Bu tanlov o'g'il bolalar ham, qiz
                                      // bolalar ham uchun bir xil forma
                                      // orqali amalga oshiriladi (yuqoridagi
                                      // "Yotoqxona turi" bo'limida qaysi
                                      // hostelga tegishli ekani alohida
                                      // tanlanadi), shuning uchun kurs
                                      // tanlash ikkala tomon uchun ham
                                      // avtomatik ko'rinadi.
                                      _FieldLabel('Joriy kursingizni tanlang'),
                                      const SizedBox(height: 8),
                                      _CourseDropdown(
                                        value: _selectedCourse,
                                        onChanged: (val) => setState(
                                            () => _selectedCourse = val),
                                      ),

                                      const SizedBox(height: 22),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                                color:
                                                    _white.withOpacity(0.08)),
                                          ),
                                          const SizedBox(width: 10),
                                          _SectionLabel(
                                            icon: Icons.apartment_rounded,
                                            text: 'Yotoqxona turi',
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Divider(
                                                color:
                                                    _white.withOpacity(0.08)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      _FieldLabel(
                                          'Qaysi yotoqxona turini tanlang !'),
                                      const SizedBox(height: 8),
                                      _HostelSelector(
                                        value: _selectedHostel,
                                        onChanged: (val) => setState(
                                            () => _selectedHostel = val),
                                      ),

                                      const SizedBox(height: 22),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                                color:
                                                    _white.withOpacity(0.08)),
                                          ),
                                          const SizedBox(width: 10),
                                          _SectionLabel(
                                            icon: Icons
                                                .volunteer_activism_outlined,
                                            text: 'Ijtimoiy imtiyoz',
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Divider(
                                                color:
                                                    _white.withOpacity(0.08)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      _FieldLabel(
                                          'Siz ijtimoiy imtiyozga egamisiz?'),
                                      const SizedBox(height: 8),
                                      _YesNoSelector(
                                        value: _hasSocialBenefit,
                                        onChanged: (val) => setState(() {
                                          _hasSocialBenefit = val;
                                          if (!val) {
                                            // "Yo'q" tanlansa — pastdagi
                                            // barcha tanlovlar tozalanadi
                                            _selectedBenefitType = null;
                                            _lostParentType = null;
                                            _deathCertificateFile = null;
                                            _benefitDocumentFile = null;
                                          }
                                        }),
                                      ),

                                      if (_hasSocialBenefit) ...[
                                        const SizedBox(height: 16),
                                        _FieldLabel('Imtiyoz turini tanlang'),
                                        const SizedBox(height: 8),
                                        _LabeledDropdown(
                                          value: _selectedBenefitType,
                                          hintText: 'Imtiyoz turini tanlang',
                                          icon:
                                              Icons.volunteer_activism_outlined,
                                          items: kBenefitTypes,
                                          onChanged: (val) => setState(() {
                                            _selectedBenefitType = val;
                                            _lostParentType = null;
                                            _deathCertificateFile = null;
                                            _benefitDocumentFile = null;
                                          }),
                                        ),
                                      ],

                                      if (_hasSocialBenefit &&
                                          _selectedBenefitType == '1') ...[
                                        const SizedBox(height: 16),
                                        _FieldLabel('Kimni yo\'qotgansiz?'),
                                        const SizedBox(height: 8),
                                        _LabeledDropdown(
                                          value: _lostParentType,
                                          hintText: 'Ota yoki onani tanlang',
                                          icon: Icons.family_restroom_rounded,
                                          items: const [
                                            MapEntry('ota', 'Ota'),
                                            MapEntry('ona', 'Ona'),
                                          ],
                                          onChanged: (val) => setState(
                                              () => _lostParentType = val),
                                        ),
                                        const SizedBox(height: 16),
                                        _DocumentUploadField(
                                          file: _deathCertificateFile,
                                          onPick: (f) => setState(
                                              () => _deathCertificateFile = f),
                                          caption:
                                              "Vafot etgan shaxsning o'lim varaqasini yuklang. (PDF holatda)",
                                        ),
                                      ],

                                      if (_hasSocialBenefit &&
                                          _selectedBenefitType != null &&
                                          _selectedBenefitType != '1') ...[
                                        const SizedBox(height: 16),
                                        _DocumentUploadField(
                                          file: _benefitDocumentFile,
                                          onPick: (f) => setState(
                                              () => _benefitDocumentFile = f),
                                          caption: _benefitDocumentLabel(
                                              _selectedBenefitType!),
                                        ),
                                      ],

                                      const SizedBox(height: 22),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Divider(
                                                color:
                                                    _white.withOpacity(0.08)),
                                          ),
                                          const SizedBox(width: 10),
                                          _SectionLabel(
                                            icon: Icons.lock_outline_rounded,
                                            text: 'Xavfsizlik',
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Divider(
                                                color:
                                                    _white.withOpacity(0.08)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      _FieldLabel('Parol'),
                                      const SizedBox(height: 8),
                                      _AuthField(
                                        controller: _passwordController,
                                        hint: 'Kamida 6 ta belgi',
                                        icon: Icons.lock_outline_rounded,
                                        obscure: _obscurePassword,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: _white.withOpacity(0.4),
                                            size: 18,
                                          ),
                                          onPressed: () => setState(() =>
                                              _obscurePassword =
                                                  !_obscurePassword),
                                        ),
                                        validator: (v) => v == null ||
                                                v.length < 6
                                            ? 'Parol kamida 6 ta belgi bo\'lsin'
                                            : null,
                                      ),
                                      const SizedBox(height: 10),

                                      // Parol kuchi indikatori
                                      AnimatedOpacity(
                                        opacity:
                                            _passwordController.text.isEmpty
                                                ? 0
                                                : 1,
                                        duration:
                                            const Duration(milliseconds: 200),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  return Stack(
                                                    children: [
                                                      Container(
                                                        height: 5,
                                                        width: constraints
                                                            .maxWidth,
                                                        color: _white
                                                            .withOpacity(0.08),
                                                      ),
                                                      AnimatedContainer(
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    250),
                                                        height: 5,
                                                        width: constraints
                                                                .maxWidth *
                                                            _passwordStrength,
                                                        color: _strengthColor,
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _strengthLabel,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _strengthColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      _FieldLabel('Parolni takrorlang'),
                                      const SizedBox(height: 8),
                                      _AuthField(
                                        controller: _confirmPasswordController,
                                        hint: 'Parolni qayta kiriting',
                                        icon: Icons.lock_outline_rounded,
                                        obscure: _obscureConfirmPassword,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: _white.withOpacity(0.4),
                                            size: 18,
                                          ),
                                          onPressed: () => setState(() =>
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Parolni takrorlang';
                                          }
                                          if (v.trim() !=
                                              _passwordController.text.trim()) {
                                            return 'Parollar mos kelmadi';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),

                                      // Shartlarga rozilik
                                      GestureDetector(
                                        onTap: () => setState(() =>
                                            _agreedToTerms = !_agreedToTerms),
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 180),
                                              width: 20,
                                              height: 20,
                                              margin:
                                                  const EdgeInsets.only(top: 1),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                gradient: _agreedToTerms
                                                    ? const LinearGradient(
                                                        colors: [
                                                          _teal,
                                                          _purple
                                                        ],
                                                      )
                                                    : null,
                                                color: _agreedToTerms
                                                    ? null
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: _agreedToTerms
                                                      ? Colors.transparent
                                                      : _white
                                                          .withOpacity(0.25),
                                                  width: 1.4,
                                                ),
                                              ),
                                              child: _agreedToTerms
                                                  ? const Icon(
                                                      Icons.check_rounded,
                                                      size: 14,
                                                      color: _white,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Foydalanish shartlari va maxfiylik siyosatiga roziman",
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  color:
                                                      _white.withOpacity(0.55),
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),

                                      _RegisterButton(onTap: _register),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Allaqachon hisobingiz bormi? ",
                                      style: TextStyle(
                                        color: _white.withOpacity(0.4),
                                        fontSize: 13,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: const Text(
                                        "Kirish",
                                        style: TextStyle(
                                          color: _violet,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
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

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.4)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.white.withOpacity(0.4),
          ),
        ),
      ],
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

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
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
          borderSide: const BorderSide(color: Color(0xFF00CEC9), width: 1.5),
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

class _FacultyDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _FacultyDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: const Color(0xFF1B1836),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.white.withOpacity(0.4)),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Fakultetni tanlang',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 14,
        ),
        prefixIcon: Icon(Icons.account_balance_outlined,
            color: Colors.white.withOpacity(0.4), size: 18),
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
          borderSide: const BorderSide(color: Color(0xFF00CEC9), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: const Color(0xFFfd79a8).withOpacity(0.7)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFfd79a8), fontSize: 11),
      ),
      items: kFaculties
          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Fakultetni tanlang' : null,
    );
  }
}

class _CourseDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _CourseDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: const Color(0xFF1B1836),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.white.withOpacity(0.4)),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Kursni tanlang',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 14,
        ),
        prefixIcon: Icon(Icons.menu_book_outlined,
            color: Colors.white.withOpacity(0.4), size: 18),
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
          borderSide: const BorderSide(color: Color(0xFF00CEC9), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: const Color(0xFFfd79a8).withOpacity(0.7)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFfd79a8), fontSize: 11),
      ),
      items: kCourses
          .map((c) => DropdownMenuItem(value: c, child: Text('$c-kurs')))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Kursni tanlang' : null,
    );
  }
}

class _DateOfBirthField extends FormField<DateTime> {
  _DateOfBirthField({
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) : super(
          initialValue: value,
          validator: (v) => v == null ? "Tug'ilgan sanani tanlang" : null,
          builder: (state) {
            String two(int n) => n.toString().padLeft(2, '0');
            String format(DateTime d) =>
                '${two(d.day)}.${two(d.month)}.${d.year}';

            Future<void> pick() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: state.context,
                initialDate:
                    state.value ?? DateTime(now.year - 18, now.month, now.day),
                firstDate: DateTime(now.year - 80),
                lastDate: now,
                helpText: "Tug'ilgan sanani tanlang",
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF00CEC9),
                        onPrimary: Colors.white,
                        surface: Color(0xFF1B1836),
                        onSurface: Colors.white,
                      ), dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF13102A)),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                state.didChange(picked);
                onChanged(picked);
              }
            }

            return GestureDetector(
              onTap: pick,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: state.hasError
                            ? const Color(0xFFfd79a8).withOpacity(0.7)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cake_outlined,
                            color: Colors.white.withOpacity(0.4), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            state.value == null
                                ? 'Kun.Oy.Yil (masalan: 15.05.2007)'
                                : format(state.value!),
                            style: TextStyle(
                              color: state.value == null
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.calendar_month_rounded,
                            color: Colors.white.withOpacity(0.4), size: 18),
                      ],
                    ),
                  ),
                  if (state.hasError) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        state.errorText ?? '',
                        style: const TextStyle(
                          color: Color(0xFFfd79a8),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
}

class _RegionDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _RegionDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF1B1836),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.white.withOpacity(0.4)),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Viloyatni tanlang',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 14,
        ),
        prefixIcon: Icon(Icons.map_outlined,
            color: Colors.white.withOpacity(0.4), size: 18),
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
          borderSide: const BorderSide(color: Color(0xFF00CEC9), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: const Color(0xFFfd79a8).withOpacity(0.7)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFfd79a8), fontSize: 11),
      ),
      items: kRegions
          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Viloyatni tanlang' : null,
    );
  }
}

class _DistrictDropdown extends StatelessWidget {
  final String? region;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DistrictDropdown({
    required this.region,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final districts = region != null
        ? (kRegionsWithDistricts[region] ?? const [])
        : const <String>[];
    final enabled = region != null && districts.isNotEmpty;

    // ⚠️ Foydalanuvchi avval viloyat almashtirsa-yu, hozirgi `value`
    // yangi ro'yxatda mavjud bo'lmasa, DropdownButtonFormField xato
    // beradi — shu sabab bunday holatda `value`ni null qilib beramiz.
    final safeValue =
        (value != null && districts.contains(value)) ? value : null;

    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: DropdownButtonFormField<String>(
          initialValue: safeValue,
          isExpanded: true,
          dropdownColor: const Color(0xFF1B1836),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withOpacity(0.4)),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: enabled
                ? 'Tuman yoki shaharingizni tanlang'
                : 'Avval viloyatni tanlang',
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 14,
            ),
            prefixIcon: Icon(Icons.location_city_outlined,
                color: Colors.white.withOpacity(0.4), size: 18),
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
              borderSide:
                  const BorderSide(color: Color(0xFF00CEC9), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  BorderSide(color: const Color(0xFFfd79a8).withOpacity(0.7)),
            ),
            errorStyle: const TextStyle(color: Color(0xFFfd79a8), fontSize: 11),
          ),
          items: districts
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: enabled ? onChanged : null,
          validator: (v) =>
              v == null || v.isEmpty ? 'Tuman/shaharni tanlang' : null,
        ),
      ),
    );
  }
}

class _HostelSelector extends StatelessWidget {
  final String? value; // "boys" yoki "girls"
  final ValueChanged<String?> onChanged;

  const _HostelSelector({required this.value, required this.onChanged});

  static const _teal = Color(0xFF00CEC9);
  static const _pink = Color(0xFFfd79a8);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HostelOption(
            label: "O'g'il bolalar",
            icon: Icons.person_rounded,
            color: _teal,
            selected: value == 'boys',
            onTap: () => onChanged('boys'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HostelOption(
            label: 'Qiz bolalar',
            icon: Icons.person_rounded,
            color: _pink,
            selected: value == 'girls',
            onTap: () => onChanged('girls'),
          ),
        ),
      ],
    );
  }
}

class _HostelOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _HostelOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.14)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? color : Colors.white.withOpacity(0.4),
                size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? color : Colors.white.withOpacity(0.55),
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── _YesNoSelector: "Ha" / "Yo'q" tugmalari (Ijtimoiy imtiyoz savoli) ──
class _YesNoSelector extends StatelessWidget {
  final bool value; // true = "Ha", false = "Yo'q" (standart)
  final ValueChanged<bool> onChanged;

  const _YesNoSelector({required this.value, required this.onChanged});

  static const _teal = Color(0xFF00CEC9);
  static const _purple = Color(0xFF6C5CE7);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HostelOption(
            label: 'Yo\'q',
            icon: Icons.close_rounded,
            color: _purple,
            selected: !value,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HostelOption(
            label: 'Ha',
            icon: Icons.check_rounded,
            color: _teal,
            selected: value,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

// ─── _LabeledDropdown: _RegionDropdown bilan bir xil vizual uslubdagi,
// istalgan (value, label) ro'yxati uchun ishlatiladigan umumiy dropdown ──
class _LabeledDropdown extends StatelessWidget {
  final String? value;
  final String hintText;
  final IconData icon;
  final List<MapEntry<String, String>> items;
  final ValueChanged<String?> onChanged;

  const _LabeledDropdown({
    required this.value,
    required this.hintText,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Ro'yxatda mavjud bo'lmagan qiymat DropdownButtonFormField'da
    // xatolikka olib kelmasligi uchun himoya.
    final safeValue = items.any((e) => e.key == value) ? value : null;

    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      dropdownColor: const Color(0xFF1B1836),
      icon: Icon(Icons.keyboard_arrow_down_rounded,
          color: Colors.white.withOpacity(0.4)),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
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
          borderSide: const BorderSide(color: Color(0xFF00CEC9), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: const Color(0xFFfd79a8).withOpacity(0.7)),
        ),
        errorStyle: const TextStyle(color: Color(0xFFfd79a8), fontSize: 11),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Tanlov qiling' : null,
    );
  }
}

// ─── _DocumentUploadField: PDF/rasm ko'rinishidagi ma'lumotnomani
// yuklash uchun umumiy tugma — tanlangan fayl nomi va pastida izoh
// matni (masalan "... ma'lumotnomani yuklang") ko'rsatiladi.
class _DocumentUploadField extends StatelessWidget {
  final PlatformFile? file;
  final ValueChanged<PlatformFile?> onPick;
  final String caption;

  const _DocumentUploadField({
    required this.file,
    required this.onPick,
    required this.caption,
  });

  static const _teal = Color(0xFF00CEC9);
  static const _pink = Color(0xFFfd79a8);

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true, // web va mobil uchun bir xil ishlashi uchun
    );
    if (result != null && result.files.isNotEmpty) {
      onPick(result.files.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = file != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pick,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: picked
                  ? _teal.withOpacity(0.1)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: picked ? _teal : Colors.white.withOpacity(0.08),
                width: picked ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  picked
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  color: picked ? _teal : Colors.white.withOpacity(0.4),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    picked ? file!.name : 'Fayl tanlash uchun bosing (PDF)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          picked ? Colors.white : Colors.white.withOpacity(0.4),
                      fontSize: 13,
                      fontWeight: picked ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (picked)
                  GestureDetector(
                    onTap: () => onPick(null),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white.withOpacity(0.4), size: 18),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: TextStyle(
            color: picked
                ? Colors.white.withOpacity(0.55)
                : _pink.withOpacity(0.85),
            fontSize: 11.5,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _RegisterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RegisterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00CEC9), Color(0xFF6C5CE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00CEC9).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Ro'yxatdan o'tish",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
