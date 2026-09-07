import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../modules/models/user_model.dart';
import '../modules/services/auth_service.dart';

// ─── Creative dark palette (talaba/admin dizayni bilan bir xil til) ───
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

class _RoleOption {
  final String value;
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  const _RoleOption(this.value, this.label, this.desc, this.icon, this.color);
}

class _HostelOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _HostelOption(this.value, this.label, this.icon, this.color);
}

class AdminAddUserScreen extends StatefulWidget {
  // Faqat superAdmin 'admin' yoki 'superAdmin' rolidagi hisob yarata oladi.
  final bool isSuperAdmin;
  // Ekran ochilganda oldindan tanlangan bo'ladigan yotoqxona ('boys' yoki
  // 'girls'). Masalan, Qizlar bo'limidagi Rol boshqaruvidan ochilganda
  // 'girls' beriladi — shunda admin har safar qo'lda tanlamasa ham bo'ladi.
  final String initialHostel;
  const AdminAddUserScreen({
    super.key,
    this.isSuperAdmin = false,
    this.initialHostel = 'boys',
  });

  @override
  State<AdminAddUserScreen> createState() => _AdminAddUserScreenState();
}

class _AdminAddUserScreenState extends State<AdminAddUserScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  String _selectedRole = 'talaba';
  late String _selectedHostel = widget.initialHostel;
  // 🎓 Faqat 'talaba' roli tanlanganda ko'rinadi va talab qilinadi.
  String? _selectedFaculty;
  String? _selectedCourse;
  bool _isLoading = false;
  bool _obscurePassword = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // Admin huquqlari (Faqat rol 'superAdmin' bo'lsa ishlaydi)
  final Map<String, bool> permissions = {
    'canEditRooms': false,
    'canDeleteUsers': false,
    'canExportExcel': false,
  };

  final List<_HostelOption> _hostels = const [
    _HostelOption('boys', "O'g'il bolalar", Icons.man_rounded, _C.teal),
    _HostelOption('girls', 'Qiz bolalar', Icons.woman_rounded, _C.pink),
  ];

  List<_RoleOption> get _roles => [
        if (widget.isSuperAdmin)
          const _RoleOption(
              'superAdmin',
              'Super Admin',
              "To'liq boshqaruv huquqi",
              Icons.workspace_premium_rounded,
              _C.purple),
        if (widget.isSuperAdmin)
          const _RoleOption('admin', 'Admin', 'Cheklangan boshqaruv huquqi',
              Icons.admin_panel_settings_rounded, _C.violet),
        const _RoleOption('mudir', 'Mudir', "Yotoqxona boshqaruvchisi",
            Icons.badge_rounded, _C.orange),
        const _RoleOption('moliyachi', 'Moliyachi',
            "To'lovlarni nazorat qiladi", Icons.payments_rounded, _C.mint),
        const _RoleOption('talaba', 'Talaba', 'Oddiy foydalanuvchi',
            Icons.school_rounded, _C.coral),
      ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  _RoleOption get _currentRole => _roles
      .firstWhere((r) => r.value == _selectedRole, orElse: () => _roles.last);

  void _createUser() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    if (_selectedRole == 'talaba' &&
        (_selectedFaculty == null || _selectedCourse == null)) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fakultet va kursni tanlang"),
          backgroundColor: _C.pink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // ✅ Firebase Authentication orqali xavfsiz hisob yaratiladi —
      // parol endi Firestore'ga umuman yozilmaydi.
      final success = await AuthService.addUserByAdmin(
        context: context,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: UserRole.fromString(_selectedRole),
        hostel: _selectedHostel,
        faculty: _selectedRole == 'talaba' ? _selectedFaculty : null,
        course: _selectedRole == 'talaba' ? _selectedCourse : null,
        extraData:
            _selectedRole == 'superAdmin' ? {'permissions': permissions} : null,
      );

      // 🎉 Muvaffaqiyatli yaratilgach — rol kartasi bilan bir xil uslubdagi
      // izoh (banner) bir necha soniya ko'rsatiladi, so'ng ekran yopiladi.
      if (success && mounted) {
        await _showSuccessBanner(_currentRole);
        if (mounted) Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── "Super Admin" kartasi uslubidagi muvaffaqiyat izohi ───────
  Future<void> _showSuccessBanner(_RoleOption role) {
    final overlay = Overlay.of(context);
    final completer = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 12,
        left: 16,
        right: 16,
        child: _SuccessBannerCard(
          name: _nameController.text.trim(),
          role: role,
          onDone: () {
            entry.remove();
            if (!completer.isCompleted) completer.complete();
          },
        ),
      ),
    );
    overlay.insert(entry);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: _C.bgBase,
      body: Stack(
        children: [
          // Fon bezaklari
          Positioned(
            top: -80,
            right: -60,
            child: _GlowBlob(color: _currentRole.color, size: 220),
          ),
          Positioned(
            bottom: -60,
            left: -70,
            child: _GlowBlob(color: _C.purple, size: 200),
          ),
          SafeArea(
            child: _isLoading
                ? const _LoadingState()
                : FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Column(
                        children: [
                          _Header(
                            role: _currentRole,
                            name: _nameController.text,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _SectionLabel(
                                        icon: Icons.badge_outlined,
                                        text: "Shaxsiy ma'lumotlar"),
                                    const SizedBox(height: 12),
                                    _GlassCard(
                                      child: Column(
                                        children: [
                                          _DarkField(
                                            controller: _nameController,
                                            label: "To'liq ismi (F.I.O)",
                                            icon: Icons.person_outline_rounded,
                                            validator: (v) =>
                                                v == null || v.isEmpty
                                                    ? "Ismni kiriting"
                                                    : null,
                                          ),
                                          const _FieldDivider(),
                                          _DarkField(
                                            controller: _emailController,
                                            label: 'Email',
                                            icon: Icons.alternate_email_rounded,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            validator: (v) =>
                                                v == null || v.isEmpty
                                                    ? "Emailni kiriting"
                                                    : (!v.contains('@')
                                                        ? "Email noto'g'ri"
                                                        : null),
                                          ),
                                          const _FieldDivider(),
                                          _DarkField(
                                            controller: _passwordController,
                                            label: 'Parol (kamida 6 ta belgi)',
                                            icon: Icons.lock_outline_rounded,
                                            obscure: _obscurePassword,
                                            suffix: IconButton(
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                        .visibility_off_rounded
                                                    : Icons.visibility_rounded,
                                                color: _C.muted,
                                                size: 20,
                                              ),
                                              onPressed: () => setState(() =>
                                                  _obscurePassword =
                                                      !_obscurePassword),
                                            ),
                                            validator: (v) =>
                                                v == null || v.length < 6
                                                    ? 'Parol juda qisqa'
                                                    : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // YOTOQXONA TANLASH
                                    const _SectionLabel(
                                        icon: Icons.apartment_rounded,
                                        text: 'Yotoqxonani tanlang'),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: _hostels.map((h) {
                                        final selected =
                                            _selectedHostel == h.value;
                                        return Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                                right: h == _hostels.first
                                                    ? 12
                                                    : 0),
                                            child: _SelectTile(
                                              label: h.label,
                                              icon: h.icon,
                                              color: h.color,
                                              selected: selected,
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setState(() =>
                                                    _selectedHostel = h.value);
                                              },
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 24),

                                    // ROLNI TANLASH
                                    // 'admin' va 'superAdmin' rollarini faqat
                                    // superAdmin ko'radi va yarata oladi.
                                    const _SectionLabel(
                                        icon: Icons.workspace_premium_outlined,
                                        text: 'Rolni tanlang'),
                                    const SizedBox(height: 12),
                                    Column(
                                      children: _roles
                                          .map((r) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 10),
                                                child: _RoleTile(
                                                  role: r,
                                                  selected:
                                                      _selectedRole == r.value,
                                                  onTap: () {
                                                    HapticFeedback
                                                        .selectionClick();
                                                    setState(() =>
                                                        _selectedRole =
                                                            r.value);
                                                  },
                                                ),
                                              ))
                                          .toList(),
                                    ),

                                    // 🎓 FAKULTET VA KURS (faqat 'talaba' rolida)
                                    AnimatedSize(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      child: _selectedRole == 'talaba'
                                          ? Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 14),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const _SectionLabel(
                                                      icon:
                                                          Icons.school_outlined,
                                                      text:
                                                          "O'qish ma'lumotlari"),
                                                  const SizedBox(height: 12),
                                                  _GlassCard(
                                                    child: Column(
                                                      children: [
                                                        _DarkDropdown(
                                                          label: 'Fakultet',
                                                          icon: Icons
                                                              .account_balance_outlined,
                                                          value:
                                                              _selectedFaculty,
                                                          items: kFaculties,
                                                          onChanged: (v) =>
                                                              setState(() =>
                                                                  _selectedFaculty =
                                                                      v),
                                                        ),
                                                        const _FieldDivider(),
                                                        _DarkDropdown(
                                                          label: 'Kurs',
                                                          icon: Icons
                                                              .numbers_rounded,
                                                          value:
                                                              _selectedCourse,
                                                          items: kCourses,
                                                          itemLabel: (c) =>
                                                              '$c-kurs',
                                                          onChanged: (v) =>
                                                              setState(() =>
                                                                  _selectedCourse =
                                                                      v),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),

                                    // 🔐 ADMIN HUQUQLARI
                                    AnimatedSize(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      child: _selectedRole == 'superAdmin'
                                          ? Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 14),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const _SectionLabel(
                                                      icon: Icons
                                                          .security_rounded,
                                                      text:
                                                          'Super admin huquqlari'),
                                                  const SizedBox(height: 12),
                                                  _GlassCard(
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 4),
                                                    child: Column(
                                                      children: [
                                                        _PermissionSwitch(
                                                          label:
                                                              "Xonalarni tahrirlash",
                                                          icon: Icons
                                                              .meeting_room_outlined,
                                                          value: permissions[
                                                              'canEditRooms']!,
                                                          onChanged: (v) =>
                                                              setState(() =>
                                                                  permissions[
                                                                      'canEditRooms'] = v),
                                                        ),
                                                        const _FieldDivider(),
                                                        _PermissionSwitch(
                                                          label:
                                                              "Foydalanuvchilarni o'chirish",
                                                          icon: Icons
                                                              .person_remove_outlined,
                                                          value: permissions[
                                                              'canDeleteUsers']!,
                                                          onChanged: (v) =>
                                                              setState(() =>
                                                                  permissions[
                                                                      'canDeleteUsers'] = v),
                                                        ),
                                                        const _FieldDivider(),
                                                        _PermissionSwitch(
                                                          label:
                                                              "Excel eksport qilish",
                                                          icon: Icons
                                                              .file_download_outlined,
                                                          value: permissions[
                                                              'canExportExcel']!,
                                                          onChanged: (v) =>
                                                              setState(() =>
                                                                  permissions[
                                                                      'canExportExcel'] = v),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),

                                    const SizedBox(height: 28),
                                    _SubmitButton(
                                      color: _currentRole.color,
                                      onTap: _createUser,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Muvaffaqiyat izohi: rol kartasi bilan bir xil uslub ─────────
// (kvadrat gradient ikonka + qalin sarlavha + xira izoh matni) —
// "Super Admin / To'liq boshqaruv huquqi" kartasi bilan bir xil til.
class _SuccessBannerCard extends StatefulWidget {
  final String name;
  final _RoleOption role;
  final VoidCallback onDone;

  const _SuccessBannerCard({
    required this.name,
    required this.role,
    required this.onDone,
  });

  @override
  State<_SuccessBannerCard> createState() => _SuccessBannerCardState();
}

class _SuccessBannerCardState extends State<_SuccessBannerCard> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => mounted ? setState(() => _visible = true) : null);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _visible = false);
    });
    Future.delayed(const Duration(milliseconds: 1800), widget.onDone);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.name.isNotEmpty ? widget.name : 'Foydalanuvchi';
    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        offset: _visible ? Offset.zero : const Offset(0, -0.5),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          opacity: _visible ? 1 : 0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _C.bgCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: widget.role.color.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: widget.role.color.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.role.color,
                          widget.role.color.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check_circle_rounded,
                        color: _C.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${widget.role.label} sifatida yaratildi",
                          style:
                              const TextStyle(color: _C.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header: orqaga tugmasi + sarlavha + jonli avatar ───────────
class _Header extends StatelessWidget {
  final _RoleOption role;
  final String name;
  const _Header({required this.role, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 6),
      child: Row(
        children: [
          _BackButton(onTap: () => Navigator.pop(context)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Yangi foydalanuvchi",
                  style: TextStyle(
                    color: _C.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Rol boshqaruvi tizimi",
                  style: TextStyle(color: _C.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [role.color, role.color.withOpacity(0.55)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: role.color.withOpacity(0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: _C.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _C.bgCard,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _C.faint),
          ),
          child:
              const Icon(Icons.arrow_back_rounded, color: _C.white, size: 20),
        ),
      ),
    );
  }
}

// ─── Fon uchun yumshoq nur dog'i ─────────────────────────────────
class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withOpacity(0.28), color.withOpacity(0.0)],
          ),
        ),
      ),
    );
  }
}

// ─── Bo'lim sarlavhasi ────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _C.violet),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: _C.soft,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─── Shisha ko'rinishidagi karta ─────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _GlassCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.faint),
        boxShadow: const [
          BoxShadow(
              color: Color(0x30000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: _C.faint, height: 1);
}

// ─── Qorong'i uslubdagi matn maydoni ─────────────────────────────
// ─── Tungi uslubdagi dropdown — _DarkField bilan bir xil ko'rinish,
// lekin ro'yxatdan tanlash uchun (fakultet, kurs va h.k.).
class _DarkDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final String Function(String)? itemLabel;
  final ValueChanged<String?> onChanged;

  const _DarkDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: _C.bgCard2,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.muted),
      style: const TextStyle(color: _C.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _C.muted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: _C.violet, fontSize: 13),
        prefixIcon: Icon(icon, color: _C.muted, size: 20),
        border: InputBorder.none,
        errorStyle: const TextStyle(color: _C.pink, fontSize: 11.5),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      items: items
          .map((i) => DropdownMenuItem(
                value: i,
                child: Text(itemLabel != null ? itemLabel!(i) : i),
              ))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? "$label ni tanlang" : null,
    );
  }
}

class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: _C.white, fontSize: 15),
      cursorColor: _C.violet,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _C.muted, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: _C.violet, fontSize: 13),
        prefixIcon: Icon(icon, color: _C.muted, size: 20),
        suffixIcon: suffix,
        border: InputBorder.none,
        errorStyle: const TextStyle(color: _C.pink, fontSize: 11.5),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

// ─── Yotoqxona tanlash kartasi (toggle style) ────────────────────
class _SelectTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SelectTile({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.16) : _C.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : _C.faint,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : _C.muted, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? _C.white : _C.soft,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rol tanlash kartasi ──────────────────────────────────────────
class _RoleTile extends StatelessWidget {
  final _RoleOption role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleTile(
      {required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? role.color.withOpacity(0.14) : _C.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? role.color : _C.faint,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: role.color.withOpacity(selected ? 0.9 : 0.18),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(role.icon,
                  color: selected ? _C.white : role.color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: TextStyle(
                      color: _C.white,
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    role.desc,
                    style: const TextStyle(color: _C.muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? role.color : Colors.transparent,
                border: Border.all(
                  color: selected ? role.color : _C.muted,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 15, color: _C.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Huquq switch qatori ──────────────────────────────────────────
class _PermissionSwitch extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionSwitch({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: value ? _C.violet : _C.muted, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: value ? _C.white : _C.soft,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: _C.violet,
            activeTrackColor: _C.purple.withOpacity(0.4),
            inactiveThumbColor: _C.muted,
            inactiveTrackColor: _C.faint,
          ),
        ],
      ),
    );
  }
}

// ─── Yaratish tugmasi ──────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _SubmitButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.purple, color],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      color: _C.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    "Foydalanuvchini yaratish",
                    style: TextStyle(
                      color: _C.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Yuklanish holati ───────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.bgCard,
              border: Border.all(color: _C.faint),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: _C.violet,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            "Hisob yaratilmoqda...",
            style: TextStyle(
              color: _C.soft,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

