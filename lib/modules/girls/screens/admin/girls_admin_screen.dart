import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../theme/girls_theme.dart';
import '../complaints/girls_complaints_screen.dart';
import '../dashboard/girls_dashboard.dart';
import '../notifications/girls_notifications_screen.dart';
import '../notifications/send_girls_notification_screen.dart';
import '../payments/girls_payments_screen.dart';
import '../reports/girls_reports_screen.dart';
import '../rooms/girls_rooms_screen.dart';
import '../settings/girls_settings_screen.dart';
import '../students/girls_students_screen.dart';
import '../../../models/ijtimoiy_imtiyozlar_sahifasi.dart';
 // 🎗️ Ijtimoiy imtiyoz hujjatlari sahifasi
// ─── GirlsAdminScreen: Qizlar yotoqxonasi uchun yagona boshqaruv
// qobig'i (shell). SuperAdmin, Admin va Mudira (mudir) rollari shu
// yerdan barcha bo'limlarga (Bosh sahifa, Talabalar, Xonalar,
// Murojaatlar, Bildirishnomalar, To'lovlar, Hisobotlar, Sozlamalar)
// kira oladi.
//
// ✅ Dizayn va struktura endi boys/roles/admin_screen.dart bilan
// TO'LIQ bir xil til ishlatadi (bir xil AppBar, bir xil Drawer profil
// bezagi, bir xil navigatsiya elementi ko'rinishi, bir xil chiqish
// tugmasi uslubi) — faqat ma'lumotlari butunlay alohida ('girls_*'
// Firestore to'plamlari) orqali boshqariladi. Funksional o'zgarish
// KIRITILMAGAN, faqat vizual qobiq (shell) qayta qurilgan.
class GirlsAdminScreen extends StatefulWidget {
  final UserModel user;
  const GirlsAdminScreen({super.key, required this.user});

  @override
  State<GirlsAdminScreen> createState() => _GirlsAdminScreenState();
}

class _GirlsAdminScreenState extends State<GirlsAdminScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<_NavItem> get _navItems => [
        const _NavItem('Bosh sahifa', Icons.space_dashboard_rounded,
            Icons.space_dashboard_outlined, GTheme.pink),
        const _NavItem('Talabalar', Icons.groups_rounded, Icons.groups_outlined,
            GTheme.violet),
        const _NavItem('Xonalar', Icons.meeting_room_rounded,
            Icons.meeting_room_outlined, GTheme.teal),
        const _NavItem('Murojaatlar', Icons.forum_rounded, Icons.forum_outlined,
            GTheme.orange),
        const _NavItem('Bildirishnomalar', Icons.campaign_rounded,
            Icons.campaign_outlined, GTheme.mint),
        const _NavItem("To'lovlar", Icons.payments_rounded,
            Icons.payments_outlined, GTheme.coral),
        const _NavItem('Hisobotlar', Icons.bar_chart_rounded,
            Icons.bar_chart_outlined, GTheme.violet),
        const _NavItem('Ijtimoiy imtiyozlar', Icons.volunteer_activism_rounded,
            Icons.volunteer_activism_outlined, GTheme.coral),
        const _NavItem(
            'Sozlamalar', Icons.tune_rounded, Icons.tune_outlined, GTheme.pink),
      ];

  List<Widget> get _tabs => [
        GirlsDashboard(
          user: widget.user,
          onNavigate: (i) => setState(() => _selectedIndex = i),
        ),
        const GirlsStudentsScreen(),
        const GirlsRoomsScreen(),
        GirlsComplaintsScreen(currentUser: widget.user),
        GirlsNotificationsScreen(currentUser: widget.user),
        GirlsPaymentsScreen(currentUser: widget.user),
        const GirlsReportsScreen(),
        const IjtimoiyImtiyozlarSahifasi(initialHostel: 'girls'),
        GirlsSettingsScreen(user: widget.user),
      ];

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await AuthService.logout();
    } finally {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'SUPER ADMIN';
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.mudir:
        return 'MUDIRA';
      case UserRole.moliyachi:
        return 'MOLIYACHI';
      case UserRole.talaba:
        return 'TALABA';
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: GTheme.bgBase,
      extendBodyBehindAppBar: false,
      appBar: _GirlsCreativeAppBar(
        title: _navItems[_selectedIndex].label,
        showGradient:
            _selectedIndex != 0 && _selectedIndex != _navItems.length - 1,
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        onBellTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const SendGirlsNotificationScreen()),
          );
        },
        onLogoutTap: _logout,
      ),
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: GTheme.bgBase,
      child: Column(
        children: [
          // ─── Profil bezagi ───────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            decoration: const BoxDecoration(
              gradient: GTheme.primaryGradient,
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
                        Icons.admin_panel_settings_rounded,
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
                      child: Text(
                        _roleLabel(widget.user.role),
                        style: const TextStyle(
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
                  child: Divider(color: GTheme.white.withOpacity(0.08)),
                ),
                _buildLogoutTile(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Qizlar yotoqxonasi · Versiya 1.0.0",
              style: TextStyle(color: GTheme.muted, fontSize: 11),
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
                        : GTheme.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    size: 18,
                    color: isActive ? item.color : GTheme.muted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isActive ? GTheme.white : GTheme.soft,
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
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
              color: GTheme.pink.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GTheme.pink.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, size: 18, color: GTheme.pink),
                SizedBox(width: 14),
                Text(
                  "Chiqish",
                  style: TextStyle(
                      color: GTheme.pink,
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

// ─── Creative AppBar (boys/roles/admin_screen.dart bilan bir xil) ──
class _GirlsCreativeAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final VoidCallback onMenuTap;
  final VoidCallback onBellTap;
  final VoidCallback onLogoutTap;
  final bool showGradient;

  const _GirlsCreativeAppBar({
    required this.title,
    required this.onMenuTap,
    required this.onBellTap,
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
                colors: [GTheme.pink, GTheme.violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        border: Border(
          bottom: BorderSide(color: GTheme.white.withOpacity(0.06)),
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
                    color: GTheme.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _AppBarIconBtn(
                      icon: Icons.notifications_outlined, onTap: onBellTap),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: GTheme.pink,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: showGradient ? GTheme.violet : GTheme.bgBase,
                            width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                color: GTheme.bgCard,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: GTheme.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GTheme.white.withOpacity(0.08)),
                  ),
                  child: Icon(Icons.more_vert_rounded,
                      color: GTheme.soft, size: 19),
                ),
                onSelected: (value) {
                  if (value == 'logout') onLogoutTap();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: const [
                        Icon(Icons.logout_rounded,
                            color: GTheme.pink, size: 18),
                        SizedBox(width: 10),
                        Text("Chiqish",
                            style: TextStyle(
                                color: GTheme.pink,
                                fontWeight: FontWeight.w600)),
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
          color: GTheme.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GTheme.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: GTheme.soft, size: 19),
      ),
    );
  }
}
