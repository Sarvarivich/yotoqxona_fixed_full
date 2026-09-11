import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../modules/models/user_model.dart';
import '../modules/models/tolov_cheklari_screen.dart';
import '../modules/hisobot/moliya_dashboard.dart';
import '../modules/hisobot/moliya_tolov_tarixi.dart';
import '../modules/hisobot/budjet_xarajatlari.dart';
import '../modules/hisobot/qarzdorlar_royxati.dart';
import '../modules/services/auth_service.dart';
import '../modules/services/api_service.dart';

// РІвЂќР‚РІвЂќР‚РІвЂќР‚ Moliyachi (Moliya bo'limi) profili РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚
// Bu profil talabalarning to'lov cheklari bo'yicha murojaatlarini
// tasdiqlaydi/rad etadi, to'lov tarixini, byudjet va xarajatlar
// hisobotini hamda qarzdorlar ro'yxatini boshqaradi.
// Dizayn tili mudir/admin profillari bilan bir xil.

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

class MoliyachiScreen extends StatefulWidget {
  final UserModel user;
  const MoliyachiScreen({super.key, required this.user});

  @override
  State<MoliyachiScreen> createState() => _MoliyachiScreenState();
}

class _MoliyachiScreenState extends State<MoliyachiScreen> {
  int _selectedIndex = 0;
  final List<Widget> _tabs = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<_NavItem> _navItems = const [
    _NavItem('Dashboard', Icons.space_dashboard_rounded,
        Icons.space_dashboard_outlined, _C.violet),
    _NavItem(
        'Murojaatlar', Icons.forum_rounded, Icons.forum_outlined, _C.orange),
    _NavItem("To'lov tarixi", Icons.history_rounded, Icons.history_outlined,
        _C.mint),
    _NavItem("Byudjet va xarajatlar", Icons.pie_chart_rounded,
        Icons.pie_chart_outline_rounded, _C.pink),
    _NavItem(
        'Qarzdorlar', Icons.groups_rounded, Icons.groups_outlined, _C.coral),
    _NavItem('Sozlamalar', Icons.tune_rounded, Icons.tune_outlined, _C.teal),
  ];

  @override
  void initState() {
    super.initState();
    _tabs.addAll([
      MoliyaDashboard(
        user: widget.user,
        onNavigate: (i) => setState(() => _selectedIndex = i),
      ),
      TolovCheklariScreen(
          onBack: () => setState(() => _selectedIndex = 0),
          currentUser: widget.user),
      const MoliyaTolovTarixi(),
      ByudjetXarajatlar(user: widget.user),
      const QarzdorlarRoyxati(),
      _MoliyaSettingsTab(user: widget.user),
    ]);
  }

  void _logout() async {
    try {
      // FirebaseAuth.signOut() olib tashlandi: Firebase sozlanmagan
      // platformada (Windows) u xato tashlab, chiqishni to'xtatib
      // qo'yardi. AuthService.logout() ichida ikkala seans ham
      // yopiladi va Firebase xatosi yutiladi.
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

  // "Murojaatlar" (index 1) o'z AppBar'iga ega
  bool get _ownsAppBar => _selectedIndex == 1;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _C.bgBase,
      appBar: _ownsAppBar
          ? null
          : _CreativeAppBar(
              title: _navItems[_selectedIndex].label,
              showGradient: _selectedIndex != 0,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onLogoutTap: _logout,
            ),
      drawer: _buildDrawer(),
      body: _tabs.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _C.violet))
          : IndexedStack(
              index: _selectedIndex,
              children: _tabs,
            ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _C.bgBase,
      child: Column(
        children: [
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
                        Icons.account_balance_wallet_rounded,
                        size: 36,
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
                        "MOLIYA BO'LIMI",
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
              "Yotoqxona Р’В· Versiya 1.0.0",
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
                if (index == 1) const _MurojaatBadgeDot(),
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

// РІвЂќР‚РІвЂќР‚РІвЂќР‚ Creative AppBar РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚РІвЂќР‚
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

// Kutilayotgan to'lov cheklari soni.
//
// Ilgari Firestore snapshots() bilan real vaqtda sanardi.
// Firebase sozlanmagan platformada (Windows) bu butun
// menyuni qizil ekranga aylantirardi.
//
// Endi Laravel API'dan bir marta yuklanadi. Xato bo'lsa
// belgi shunchaki ko'rinmaydi - menyu buzilmaydi.
class _MurojaatBadgeDot extends StatelessWidget {
  const _MurojaatBadgeDot();

  Future<int> _kutilayotganlar() async {
    try {
      final javob = await ApiService().get('payments');
      final royxat = javob['data'];
      if (royxat is! List) return 0;

      return royxat.where((t) {
        if (t is! Map) return false;
        return (t['status'] ?? '').toString().toLowerCase() ==
            'pending';
      }).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _kutilayotganlar(),
      builder: (context, snap) {
        final count = snap.data ?? 0;
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

// ========== MOLIYACHI SOZLAMALAR TAB ==========
class _MoliyaSettingsTab extends StatelessWidget {
  final UserModel user;
  const _MoliyaSettingsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                icon: Icons.person_outline_rounded,
                iconColor: _C.violet,
                title: "Profil ma'lumotlari",
                child: Column(
                  children: [
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      title: "To'liq ismi",
                      subtitle: user.fullName,
                    ),
                    Divider(color: _C.white.withOpacity(0.06)),
                    _InfoTile(
                      icon: Icons.email_outlined,
                      title: "Email",
                      subtitle: user.email,
                    ),
                    Divider(color: _C.white.withOpacity(0.06)),
                    _InfoTile(
                      icon: Icons.phone_outlined,
                      title: "Telefon",
                      subtitle: user.phoneNumber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SettingsCard(
                icon: Icons.info_outline_rounded,
                iconColor: _C.orange,
                title: "Tizim haqida",
                child: Column(
                  children: const [
                    _InfoTile(
                      icon: Icons.apartment_outlined,
                      title: "Yotoqxona Boshqaruvi Tizimi",
                      subtitle: "Versiya 1.0.0",
                    ),
                    Divider(color: Color(0x11FFFFFF)),
                    _InfoTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: "Rol",
                      subtitle: "Moliya bo'limi",
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
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoTile(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: _C.muted, size: 19),
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
        ],
      ),
    );
  }
}
