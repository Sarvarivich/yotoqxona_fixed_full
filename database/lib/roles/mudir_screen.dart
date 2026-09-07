import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // SignOut kafolatli ishlashi uchun
import 'package:yotoqxona/modules/models/tolov_cheklari_screen.dart';
import 'package:yotoqxona/modules/models/ijtimoiy_imtiyoz_screen.dart';
import '../modules/models/user_model.dart';
import '../modules/talabalar/talabalar_list.dart';
import '../modules/xonalar/xonalar_list.dart';
import '../modules/hisobot/dashboard.dart';
import '../modules/murojaat/murojaatlar_list.dart';
import '../modules/models/complaint_model.dart';
import '../modules/services/auth_service.dart';

// ─── Creative dark palette (admin dizayni bilan bir xil til) ───
// Mudir profili — Super Admin bilan bir xil ko'rinish va imkoniyatlarga ega,
// lekin "Rol boshqaruvi" va "Talabalar va Hodimlar" bo'limlarisiz.
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

class MudirScreen extends StatefulWidget {
  final UserModel user;
  const MudirScreen({super.key, required this.user});

  @override
  _MudirScreenState createState() => _MudirScreenState();
}

class _MudirScreenState extends State<MudirScreen> {
  int _selectedIndex = 0;
  final List<Widget> _tabs = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Diqqat: to'liq "Talabalar va Hodimlar" boshqaruvi (hodimlar, o'chirish)
  // va "Rol boshqaruvi" bo'limlari mudir profilida ataylab yo'q qilingan.
  // Mudir faqat talabalar ro'yxatini ko'ra oladi (o'chirish huquqisiz).
  final List<_NavItem> _navItems = const [
    _NavItem('Dashboard', Icons.space_dashboard_rounded,
        Icons.space_dashboard_outlined, _C.violet),
    _NavItem('Talabalar ro\'yxati', Icons.groups_rounded, Icons.groups_outlined,
        _C.mint),
    _NavItem('Xonalar', Icons.apartment_rounded, Icons.apartment_outlined,
        _C.orange),
    _NavItem('Murojaatlar', Icons.forum_rounded, Icons.forum_outlined, _C.pink),
    _NavItem("To'lov cheklari", Icons.receipt_long_rounded,
        Icons.receipt_long_outlined, _C.teal),
    _NavItem('Ijtimoiy imtiyozlar', Icons.volunteer_activism_rounded,
        Icons.volunteer_activism_outlined, _C.pink),
    _NavItem('Sozlamalar', Icons.tune_rounded, Icons.tune_outlined, _C.coral),
  ];

  @override
  void initState() {
    super.initState();
    _tabs.addAll([
      Dashboard(
        showFinancials: false,
        hostel: widget.user.hostel ?? 'boys',
      ),
      TalabalarList(
        isAdmin: false,
        hostel: widget.user.hostel ?? 'boys',
      ),
      XonalarList(
        isAdmin: true,
        hostel: widget.user.hostel ?? 'boys',
      ),
      MurojaatlarList(
        isAdmin: true,
        hostel: widget.user.hostel ?? 'boys',
        studentId: null,
        currentUser: widget.user,
        roleFilter: ComplaintTarget.mudir,
      ),
      TolovCheklariScreen(
          onBack: () => setState(() => _selectedIndex = 0),
          currentUser: widget.user),
      IjtimoiyImtiyozScreen(
          onBack: () => setState(() => _selectedIndex = 0),
          initialHostel: widget.user.hostel),
      _MudirSettingsTab(user: widget.user),
    ]);
  }

  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await AuthService.logout();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Chiqishda xatolik: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // "To'lov cheklari" (index 4) o'z AppBar'iga ega — qobiqning AppBar'ini berkitamiz
  bool get _ownsAppBar => _selectedIndex == 4 || _selectedIndex == 5;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _C.bgBase,
      extendBodyBehindAppBar: false,
      appBar: _ownsAppBar
          ? null
          : _CreativeAppBar(
              title: _navItems[_selectedIndex].label,
              showGradient: _selectedIndex != 0 && _selectedIndex != 6,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onLogoutTap: _logout,
            ),
      drawer: _buildDrawer(),
      body: _tabs.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _C.violet))
          : _tabs[_selectedIndex],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _C.bgBase,
      child: Column(
        children: [
          // ─── Profil bezagi ───────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.purple, Color(0xFF4A3FA0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -40,
                  right: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(
                        Icons.badge_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.user.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "YOTOQXONA MUDIRI",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                for (int i = 0; i < _navItems.length; i++)
                  _buildDrawerItem(item: _navItems[i], index: i),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: Divider(color: _C.white.withOpacity(0.08)),
                ),
                _buildLogoutTile(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Yotoqxona · Versiya 1.0.0",
              style: TextStyle(color: _C.muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({required _NavItem item, required int index}) {
    final isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() => _selectedIndex = index);
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isActive ? item.color.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isActive
                  ? Border.all(color: item.color.withOpacity(0.3))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive
                        ? item.color.withOpacity(0.22)
                        : _C.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    size: 18,
                    color: isActive ? item.color : _C.muted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isActive ? _C.white : _C.soft,
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (index == 3) const _TolovBadgeDot(),
                if (index == 5) const IjtimoiyImtiyozBadge(),
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _logout,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _C.pink.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.pink.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, size: 18, color: _C.pink),
                SizedBox(width: 14),
                Text(
                  "Chiqish",
                  style: TextStyle(
                      color: _C.pink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData activeIcon;
  final IconData icon;
  final Color color;
  const _NavItem(this.label, this.activeIcon, this.icon, this.color);
}

// ─── Creative AppBar ─────────────────────────────────────────────
class _CreativeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onLogoutTap;
  final bool showGradient;

  const _CreativeAppBar({
    required this.title,
    required this.onMenuTap,
    required this.onLogoutTap,
    this.showGradient = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: showGradient ? null : Colors.transparent,
        gradient: showGradient
            ? const LinearGradient(
                colors: [_C.purple, _C.violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: Border(
          bottom: BorderSide(color: _C.white.withOpacity(0.06)),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              const SizedBox(width: 8),
              _AppBarIconBtn(icon: Icons.menu_rounded, onTap: onMenuTap),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _C.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                color: _C.bgCard,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _C.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.white.withOpacity(0.08)),
                  ),
                  child:
                      Icon(Icons.more_vert_rounded, color: _C.soft, size: 19),
                ),
                onSelected: (value) {
                  if (value == 'logout') onLogoutTap();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: const [
                        Icon(Icons.logout_rounded, color: _C.pink, size: 18),
                        SizedBox(width: 10),
                        Text("Chiqish",
                            style: TextStyle(
                                color: _C.pink, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _C.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: _C.soft, size: 19),
      ),
    );
  }
}

class _TolovBadgeDot extends StatelessWidget {
  const _TolovBadgeDot();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tolov_cheklari')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        if (count == 0) return const SizedBox(width: 8);
        return Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _C.pink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}

// ========== MUDIR SETTINGS TAB ==========
// Admin sozlamalari bilan bir xil imkoniyatlar (Excel eksport,
// standart to'lov summasi, ma'lumotlar bazasini tozalash va h.k.)
class _MudirSettingsTab extends StatefulWidget {
  final UserModel user;
  const _MudirSettingsTab({required this.user});
  @override
  __MudirSettingsTabState createState() => __MudirSettingsTabState();
}

class __MudirSettingsTabState extends State<_MudirSettingsTab> {
  bool _notificationsEnabled = true;
  double _defaultPaymentAmount = 500000;
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: _C.violet))
        : Stack(
            children: [
              Positioned(
                top: -60,
                right: -40,
                child: _GlowOrb(color: _C.purple, size: 200),
              ),
              Positioned(
                bottom: 200,
                left: -50,
                child: _GlowOrb(color: _C.teal, size: 160),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  children: [
                    _SettingsCard(
                      icon: Icons.tune_rounded,
                      iconColor: _C.violet,
                      title: "Tizim sozlamalari",
                      child: Column(
                        children: [
                          _SwitchTile(
                            title: "Bildirishnomalar",
                            subtitle: "SMS, Email va Push xabarlar",
                            value: _notificationsEnabled,
                            onChanged: (val) =>
                                setState(() => _notificationsEnabled = val),
                          ),
                          Divider(color: _C.white.withOpacity(0.06)),
                          _ActionTile(
                            icon: Icons.payments_outlined,
                            iconColor: _C.teal,
                            title: "Standart to'lov summasi",
                            subtitle:
                                "${_defaultPaymentAmount.toStringAsFixed(0)} so'm",
                            trailingIcon: Icons.edit_outlined,
                            onTap: _showEditPaymentDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SettingsCard(
                      icon: Icons.tips_and_updates_rounded,
                      iconColor: _C.orange,
                      title: "Xona taqsimlash tartibi",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _C.orange.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: _C.orange.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Tavsiya etilgan tartib:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _C.orange,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 10),
                                _StepRow(
                                  number: "1",
                                  text:
                                      "Yangi talaba ro'yxatdan o'tadi — tizim uni \"Biriktirilmagan\" holatda saqlaydi",
                                ),
                                SizedBox(height: 8),
                                _StepRow(
                                  number: "2",
                                  text:
                                      "Mudir \"Xonalar\" bo'limidan bo'sh xonalarni ko'radi",
                                ),
                                SizedBox(height: 8),
                                _StepRow(
                                  number: "3",
                                  text:
                                      "Mudir talabaga mos xonani tanlab, \"Xona taqsimlash\" orqali biriktiradi",
                                ),
                                SizedBox(height: 8),
                                _StepRow(
                                  number: "4",
                                  text:
                                      "Talabaga bildirishnoma yuboriladi — xona raqami va qavatini xabar qiladi",
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: _C.mint, size: 17),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Bunday tartib xato biriktirish ehtimolini yo'q qiladi va har bir qaror mudir nazoratida bo'ladi.",
                                  style: TextStyle(
                                      fontSize: 12.5, color: _C.muted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SettingsCard(
                      icon: Icons.info_outline_rounded,
                      iconColor: _C.violet,
                      title: "Tizim haqida",
                      child: Column(
                        children: [
                          _ActionTile(
                            icon: Icons.apartment_outlined,
                            iconColor: _C.violet,
                            title: "Yotoqxona Boshqaruvi Tizimi",
                            subtitle: "Versiya 1.0.0",
                          ),
                          Divider(color: _C.white.withOpacity(0.06)),
                          _ActionTile(
                            icon: Icons.person_outline_rounded,
                            iconColor: _C.violet,
                            title: "Yotoqxona Mudiri",
                            subtitle: widget.user.email,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  void _showEditPaymentDialog() {
    TextEditingController controller =
        TextEditingController(text: _defaultPaymentAmount.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Standart to'lovni o'zgartirish",
            style: TextStyle(
                color: _C.white, fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: _C.white),
          decoration: InputDecoration(
            labelText: "To'lov summasi (so'm)",
            labelStyle: TextStyle(color: _C.muted),
            prefixIcon:
                const Icon(Icons.monetization_on_outlined, color: _C.teal),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _C.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.violet),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Bekor qilish", style: TextStyle(color: _C.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.purple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _defaultPaymentAmount = double.parse(controller.text);
                });
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("To'lov summasi yangilandi"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text("Saqlash", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Sozlamalar UI yordamchilari ──────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.16),
            blurRadius: size * 0.8,
            spreadRadius: size * 0.2,
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.faint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _C.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _C.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: _C.muted, fontSize: 11.5)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _C.violet,
            activeTrackColor: _C.purple.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _C.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: _C.muted, fontSize: 11.5),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailingIcon != null)
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _C.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(trailingIcon, size: 15, color: iconColor),
              ),
            ),
        ],
      ),
    );
  }
}

// ========== STEP ROW WIDGET ==========
class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: _C.orange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                  color: Color(0xFF1A1730),
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: _C.soft),
          ),
        ),
      ],
    );
  }
}
