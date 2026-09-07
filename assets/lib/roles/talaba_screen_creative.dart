import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modules/models/user_model.dart';
import '../modules/models/room_model.dart';
import '../modules/murojaat/murojaatlar_list.dart';

import 'talaba_tolovlar_screen.dart';
import '../auth/hostel_selection_screen.dart';

// ─── Muammo: talaba_screen_creative.dart ichida TolovCheklariScreen
// kodi yozilgan edi — StudentProfileScreen yo'q edi.
// Yechim: to'liq StudentProfileScreen bilan almashtirildi.
//
// login.dart dagi muammo ham hal qilindi:
// LoginScreen classi login.dart ga qo'shildi.

class _C {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
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

// ─── Shell: 3 tab (Bosh sahifa / To'lovlar / Profil) ────────────
class StudentProfileScreen extends StatefulWidget {
  final UserModel? user;
  const StudentProfileScreen({super.key, this.user});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  int _tab = 0;
  late UserModel? _user;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _onUserUpdated(UserModel u) => setState(() => _user = u);

  void _selectTab(int i) {
    Navigator.of(context).maybePop(); // drawer ochiq bo'lsa yopish
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
    ));

    final pages = [
      _HomeTab(user: _user, onPayTap: () => setState(() => _tab = 1)),
      TalabaTolovlarScreen(user: _user),
      MurojaatlarList(
        isAdmin: false,
        hostel: _user?.hostel ?? 'boys',
        studentId: _user?.id,
        studentName: _user?.fullName,
      ),
      _ProfileTab(user: _user, onUserUpdated: _onUserUpdated),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _C.bgBase,
      drawer: _StudentDrawer(
        userName:
            _user?.fullName.isNotEmpty == true ? _user!.fullName : 'Talaba',
        userEmail: _user?.email ?? '',
        selected: _tab,
        onSelect: _selectTab,
      ),
      // Sahifalar endi to'liq ekranni egallaydi — pastki navbar olib
      // tashlandi, chunki u har bir sahifaning o'z FloatingActionButton
      // tugmasini (masalan "Murojaat yozish") yashirib qo'yayotgan edi.
      body: Stack(
        children: [
          IndexedStack(index: _tab, children: pages),
          // Doimiy ko'rinadigan menyu (hamburger) tugmasi — Drawer'ni ochadi
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _MenuButton(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menyuni ochuvchi doimiy tugma ──────────────────────────────
class _MenuButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _C.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.white.withOpacity(0.1)),
          ),
          child: const Icon(Icons.menu_rounded, color: _C.white, size: 20),
        ),
      ),
    );
  }
}

// ─── Talaba uchun yon menyu (Drawer) ────────────────────────────
class _StudentDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;
  final int selected;
  final void Function(int) onSelect;

  const _StudentDrawer({
    required this.userName,
    required this.userEmail,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'Bosh sahifa'),
      (Icons.receipt_long_rounded, "To'lovlar"),
      (Icons.forum_rounded, 'Murojaat'),
      (Icons.person_rounded, 'Profil'),
    ];

    return Drawer(
      backgroundColor: _C.bgCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _C.purple.withOpacity(0.25),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
                      style: const TextStyle(
                        color: _C.violet,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            color: _C.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (userEmail.isNotEmpty)
                          Text(
                            userEmail,
                            style: TextStyle(
                              color: _C.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: _C.white.withOpacity(0.08), height: 1),
            const SizedBox(height: 8),
            ...items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final active = i == selected;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: Material(
                  color:
                      active ? _C.purple.withOpacity(0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(
                      item.$1,
                      color: active ? _C.violet : _C.muted,
                    ),
                    title: Text(
                      item.$2,
                      style: TextStyle(
                        color: active ? _C.violet : _C.white,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => onSelect(i),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Bosh sahifa tabi ───────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onPayTap;
  const _HomeTab({required this.user, required this.onPayTap});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  String get _name => widget.user?.fullName.isNotEmpty == true
      ? widget.user!.fullName
      : 'Talaba';
  String get _email =>
      widget.user?.email.isNotEmpty == true ? widget.user!.email : '—';
  String get _initials {
    final parts = _name.trim().split(' ');
    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : _name.isNotEmpty
            ? _name[0].toUpperCase()
            : 'T';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _Orb(color: _C.purple, size: 240, top: -80, right: -50),
        _Orb(color: _C.teal, size: 200, bottom: 250, left: -60),
        _Orb(color: _C.pink, size: 160, top: 350, right: -40),
        FadeTransition(
          opacity: _fade,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _TopBar(name: _name)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _HeroCard(name: _name, email: _email, initials: _initials),
                    const SizedBox(height: 16),
                    const _StatsRow(),
                    const SizedBox(height: 16),
                    const _ActivityCard(),
                    const SizedBox(height: 16),
                    _QuickActions(onPayTap: widget.onPayTap),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Profil tabi ─────────────────────────────────────────────────
class _ProfileTab extends StatefulWidget {
  final UserModel? user;
  final ValueChanged<UserModel> onUserUpdated;
  const _ProfileTab({required this.user, required this.onUserUpdated});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  RoomModel? _room;
  bool _loadingRoom = true;

  @override
  void initState() {
    super.initState();
    _fetchRoom();
  }

  @override
  void didUpdateWidget(covariant _ProfileTab old) {
    super.didUpdateWidget(old);
    if (old.user?.roomId != widget.user?.roomId) _fetchRoom();
  }

  Future<void> _fetchRoom() async {
    final rid = widget.user?.roomId;
    if (rid == null || rid.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _room = null;
          _loadingRoom = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _loadingRoom = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('xonalar')
          .where('roomNumber', isEqualTo: int.tryParse(rid) ?? -1)
          .limit(1)
          .get();

      RoomModel? found;
      if (snap.docs.isNotEmpty) {
        found = RoomModel.fromJson(snap.docs.first.data());
      } else {
        final byStudent = await FirebaseFirestore.instance
            .collection('xonalar')
            .where('studentIds', arrayContains: widget.user?.id ?? '')
            .limit(1)
            .get();
        if (byStudent.docs.isNotEmpty) {
          found = RoomModel.fromJson(byStudent.docs.first.data());
        }
      }
      if (mounted) {
        setState(() {
          _room = found;
          _loadingRoom = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _room = null;
          _loadingRoom = false;
        });
      }
    }
  }

  String get _name => widget.user?.fullName.isNotEmpty == true
      ? widget.user!.fullName
      : 'Talaba';
  String get _email =>
      widget.user?.email.isNotEmpty == true ? widget.user!.email : '—';
  String get _phone => widget.user?.phoneNumber.isNotEmpty == true
      ? widget.user!.phoneNumber
      : '—';
  String get _initials {
    final parts = _name.trim().split(' ');
    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : _name.isNotEmpty
            ? _name[0].toUpperCase()
            : 'T';
  }

  Future<void> _openEdit() async {
    final user = widget.user;
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.fullName);
    final phoneCtrl = TextEditingController(text: user.phoneNumber);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    final updated = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: const BoxDecoration(
              color: _C.bgCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: _C.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const Text('Profilni tahrirlash',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.white)),
                  const SizedBox(height: 20),
                  _EditLabel('Ism familya'),
                  const SizedBox(height: 8),
                  _EditField(
                    ctrl: nameCtrl,
                    icon: Icons.badge_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ism familyani kiriting'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _EditLabel('Telefon raqam'),
                  const SizedBox(height: 8),
                  _EditField(
                    ctrl: phoneCtrl,
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Telefon kiriting'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: GestureDetector(
                      onTap: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              ss(() => saving = true);
                              try {
                                await FirebaseFirestore.instance
                                    .collection('foydalanuvchilar')
                                    .doc(user.id)
                                    .update({
                                  'fullName': nameCtrl.text.trim(),
                                  'phoneNumber': phoneCtrl.text.trim(),
                                });
                                if (ctx.mounted) {
                                  Navigator.pop(
                                      ctx,
                                      user.copyWith(
                                        fullName: nameCtrl.text.trim(),
                                        phoneNumber: phoneCtrl.text.trim(),
                                      ));
                                }
                              } catch (e) {
                                ss(() => saving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text('Xatolik: $e'),
                                          backgroundColor: Colors.red));
                                }
                              }
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [_C.purple, _C.violet]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text('Saqlash',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (updated != null) {
      widget.onUserUpdated(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Profil yangilandi'), backgroundColor: Colors.green));
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Chiqish',
            style: TextStyle(
                color: _C.white, fontWeight: FontWeight.w700, fontSize: 18)),
        content: Text('Hisobdan chiqishni tasdiqlaysizmi?',
            style: TextStyle(color: _C.white.withOpacity(0.6), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish',
                style:
                    TextStyle(color: _C.violet, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const HostelSelectionScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text('Chiqish',
                style: TextStyle(color: _C.pink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _room;
    final roomRows = _loadingRoom
        ? [
            const _InfoRow(
                icon: Icons.hourglass_empty_outlined,
                label: 'Yuklanmoqda...',
                value: '')
          ]
        : r == null
            ? [
                const _InfoRow(
                    icon: Icons.info_outline,
                    label: 'Holat',
                    value: 'Xonaga biriktirilmagan',
                    muted: true)
              ]
            : [
                _InfoRow(
                    icon: Icons.door_front_door_outlined,
                    label: 'Xona raqami',
                    value: '${r.roomNumber}'),
                _InfoRow(
                    icon: Icons.layers_outlined,
                    label: 'Qavat',
                    value: '${r.floor}-qavat'),
                _InfoRow(
                    icon: Icons.groups_2_outlined,
                    label: 'Joylar',
                    value: '${r.currentOccupants}/${r.capacity}'),
                _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Oylik narx',
                    value: "${r.pricePerMonth.toStringAsFixed(0)} so'm",
                    color: _C.teal),
                _InfoRow(
                    icon: Icons.verified_outlined,
                    label: 'Holati',
                    value: r.status.displayName,
                    color:
                        r.status == RoomStatus.occupied ? _C.mint : _C.orange),
              ];

    return Stack(
      children: [
        _Orb(color: _C.violet, size: 220, top: -60, right: -40),
        _Orb(color: _C.coral, size: 160, bottom: 300, left: -50),
        SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      const Text('Profil',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _C.white,
                              letterSpacing: -0.3)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _fetchRoom,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _C.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(11),
                            border:
                                Border.all(color: _C.white.withOpacity(0.08)),
                          ),
                          child: const Icon(Icons.refresh_rounded,
                              color: _C.soft, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _HeroCard(
                      name: _name,
                      email: _email,
                      initials: _initials,
                      onEditTap: _openEdit,
                    ),
                    const SizedBox(height: 16),
                    _InfoCard(
                      title: 'Shaxsiy ma\'lumotlar',
                      iconColor: _C.violet,
                      iconBg: const Color(0x2Ea29bfe),
                      icon: Icons.person_outline_rounded,
                      rows: [
                        _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Ism familya',
                            value: _name),
                        _InfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Telefon',
                            value: _phone),
                        _InfoRow(
                          icon: Icons.perm_identity_outlined,
                          label: 'Student ID',
                          value: widget.user?.studentId ?? '—',
                          muted: widget.user?.studentId == null,
                        ),
                        _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: _email),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _InfoCard(
                      title: 'Xona ma\'lumotlari',
                      iconColor: _C.teal,
                      iconBg: const Color(0x2200CEC9),
                      icon: Icons.apartment_outlined,
                      rows: roomRows,
                    ),
                    const SizedBox(height: 20),
                    _LogoutBtn(onTap: _logout),
                    const SizedBox(height: 110),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SHARED UI COMPONENTS
// ══════════════════════════════════════════════════════════════════

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double? top, bottom, left, right;
  const _Orb(
      {required this.color,
      required this.size,
      this.top,
      this.bottom,
      this.left,
      this.right});

  @override
  Widget build(BuildContext context) => Positioned(
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
                color: color.withOpacity(0.18),
                blurRadius: size * 0.8,
                spreadRadius: size * 0.2,
              )
            ],
          ),
        ),
      );
}

// ─── Top Bar ───────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String name;
  const _TopBar({required this.name});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greeting = h < 12
        ? 'Xayrli tong 🌤'
        : h < 17
            ? 'Xayrli kun ☀️'
            : 'Xayrli kech 🌙';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: TextStyle(
                          fontSize: 12,
                          color: _C.white.withOpacity(0.45),
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _C.white,
                          letterSpacing: -0.3),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            _TopBtn(icon: Icons.notifications_outlined, badge: true),
            const SizedBox(width: 8),
            _TopBtn(icon: Icons.settings_outlined),
          ],
        ),
      ),
    );
  }
}

class _TopBtn extends StatelessWidget {
  final IconData icon;
  final bool badge;
  const _TopBtn({required this.icon, this.badge = false});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _C.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.white.withOpacity(0.08)),
            ),
            child: Icon(icon, color: _C.soft, size: 19),
          ),
          if (badge)
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _C.pink,
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.bgBase, width: 1.5),
                ),
              ),
            ),
        ],
      );
}

// ─── Hero Card ─────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final String name, email, initials;
  final VoidCallback? onEditTap;
  const _HeroCard(
      {required this.name,
      required this.email,
      required this.initials,
      this.onEditTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B2E), Color(0xFF16132B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: _C.purple.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_C.purple, _C.violet],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: _C.white.withOpacity(0.15), width: 2),
                    ),
                    child: Center(
                        child: Text(initials,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white))),
                  ),
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
                            color: const Color(0xFF1E1B2E), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _C.white,
                            letterSpacing: -0.3),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(email,
                        style: TextStyle(fontSize: 12, color: _C.muted),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _C.purple.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: _C.violet.withOpacity(0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_outlined,
                              size: 11, color: _C.violet),
                          SizedBox(width: 5),
                          Text('TALABA',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _C.violet,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onEditTap != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onEditTap,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: _C.purple.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.purple.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: _C.violet),
                    SizedBox(width: 6),
                    Text('Profilni tahrirlash',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.violet)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Stats Row ─────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) => Row(
        children: const [
          Expanded(
              child: _StatBox(
            icon: Icons.calendar_month_outlined,
            value: '0',
            label: 'Kun',
            color: _C.violet,
            iconBg: Color(0x2Ea29bfe),
            grad: [_C.purple, _C.violet],
          )),
          SizedBox(width: 10),
          Expanded(
              child: _StatBox(
            icon: Icons.receipt_long_outlined,
            value: '0',
            label: "To'lov",
            color: _C.teal,
            iconBg: Color(0x2200CEC9),
            grad: [_C.teal, _C.mint],
          )),
          SizedBox(width: 10),
          Expanded(
              child: _StatBox(
            icon: Icons.notifications_active_outlined,
            value: '0',
            label: 'Xabar',
            color: _C.pink,
            iconBg: Color(0x22fd79a8),
            grad: [_C.pink, _C.coral],
          )),
        ],
      );
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color, iconBg;
  final List<Color> grad;
  const _StatBox(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color,
      required this.iconBg,
      required this.grad});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
        decoration: BoxDecoration(
          color: _C.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.faint),
        ),
        child: Column(
          children: [
            Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: grad),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: _C.muted,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4)),
          ],
        ),
      );
}

// ─── Activity Card ─────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  const _ActivityCard();

  @override
  Widget build(BuildContext context) {
    final days = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
    final h = [0.4, 0.7, 0.5, 0.9, 0.6, 0.3, 0.8];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.faint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.bar_chart_rounded, color: _C.teal, size: 18),
                SizedBox(width: 8),
                Text('Haftalik faollik',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.white)),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _C.teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Bu hafta',
                    style: TextStyle(
                        fontSize: 10,
                        color: _C.teal,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final isToday = i == 4;
                return Container(
                  width: 28,
                  height: 48 * h[i],
                  decoration: BoxDecoration(
                    gradient: isToday
                        ? const LinearGradient(
                            colors: [_C.teal, _C.mint],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter)
                        : LinearGradient(
                            colors: [
                                _C.purple.withOpacity(0.5),
                                _C.violet.withOpacity(0.5)
                              ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter),
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.asMap().entries.map((e) {
              final isToday = e.key == 4;
              return SizedBox(
                width: 28,
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: isToday ? _C.teal : _C.muted,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Actions ─────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final VoidCallback onPayTap;
  const _QuickActions({required this.onPayTap});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.payment_outlined,
        "To'lov\nqilish",
        _C.teal,
        const Color(0x1500CEC9),
        onPayTap
      ),
      (
        Icons.wifi_outlined,
        'Wi-Fi\nparol',
        _C.violet,
        const Color(0x156C5CE7),
        () {}
      ),
      (
        Icons.support_agent_outlined,
        'Yordam\nmarkazi',
        _C.pink,
        const Color(0x15fd79a8),
        () {}
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12, left: 2),
          child: Text('Tez harakatlar',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _C.white)),
        ),
        Row(
          children: actions.asMap().entries.map((e) {
            final a = e.value;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: e.key < actions.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: a.$5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    decoration: BoxDecoration(
                      color: a.$4,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: a.$3.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: a.$3.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(a.$1, color: a.$3, size: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(a.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10,
                                color: a.$3,
                                fontWeight: FontWeight.w600,
                                height: 1.3)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Info Card / Row ───────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String title;
  final Color iconColor, iconBg;
  final IconData icon;
  final List<_InfoRow> rows;
  const _InfoCard(
      {required this.title,
      required this.iconColor,
      required this.iconBg,
      required this.icon,
      required this.rows});

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: iconBg, borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _C.white)),
              ],
            ),
          ),
          const Divider(color: Color(0x0DFFFFFF), height: 1),
          ...rows.asMap().entries.map((e) => Column(
                children: [
                  e.value,
                  if (e.key < rows.length - 1)
                    const Divider(
                        color: Color(0x0AFFFFFF),
                        height: 1,
                        indent: 16,
                        endIndent: 16),
                ],
              )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool muted;
  final Color? color;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.muted = false,
      this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            SizedBox(width: 32, child: Icon(icon, size: 17, color: _C.muted)),
            Text(label,
                style:
                    TextStyle(fontSize: 13, color: _C.white.withOpacity(0.4))),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: muted ? _C.muted : (color ?? _C.white),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

// ─── Edit dialog yordamchilari ──────────────────────────────────
class _EditLabel extends StatelessWidget {
  final String label;
  const _EditLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _C.white.withOpacity(0.55),
          letterSpacing: 0.3));
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  const _EditField(
      {required this.ctrl, required this.icon, this.keyboard, this.validator});

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        validator: validator,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon:
              Icon(icon, color: Colors.white.withOpacity(0.4), size: 18),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _C.purple, width: 1.5)),
          errorStyle: const TextStyle(color: _C.pink, fontSize: 11),
        ),
      );
}

// ─── Logout Button ─────────────────────────────────────────────
class _LogoutBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: _C.pink.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.pink.withOpacity(0.2)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 17, color: _C.pink),
              SizedBox(width: 8),
              Text('Tizimdan chiqish',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.pink)),
            ],
          ),
        ),
      );
}
