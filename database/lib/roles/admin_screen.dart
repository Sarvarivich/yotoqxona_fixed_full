import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // SignOut kafolatli ishlashi uchun
import 'package:yotoqxona/modules/models/tolov_cheklari_screen.dart';
import 'package:yotoqxona/modules/models/ijtimoiy_imtiyoz_screen.dart';
import '../modules/models/user_model.dart';
import '../modules/talabalar/talabalar_list.dart';
import '../modules/xonalar/xonalar_list.dart';
import '../modules/hisobot/dashboard.dart';
import '../modules/murojaat/murojaatlar_list.dart';
import '../modules/bildirishnoma/bildirishnoma_yuborish.dart';
import '../modules/services/auth_service.dart';
import '../roles/admin_add_user_screen.dart'; // Yangi qo'shiladigan sahifa importi
import '../modules/services/excel_service.dart'; // Papka iyerarxiyasiga qarab bitta nuqta (.) yoki ikkita (..) bo'lishi mumkin

// ─── Creative dark palette (talaba dizayni bilan bir xil til) ───
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

class AdminScreen extends StatefulWidget {
  final UserModel user;
  const AdminScreen({super.key, required this.user});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;
  final List<Widget> _tabs = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // superAdmin barcha huquqlarga ega; oddiy "admin" cheklangan huquqlarga ega
  // (o'chirish tugmalari va Ma'lumotlar bazasi bo'limi yashiriladi).
  bool get _isSuperAdmin => widget.user.role == UserRole.superAdmin;

  final List<_NavItem> _navItems = const [
    _NavItem('Dashboard', Icons.space_dashboard_rounded,
        Icons.space_dashboard_outlined, _C.violet),
    _NavItem('Talabalar va Hodimlar', Icons.groups_rounded,
        Icons.groups_outlined, _C.teal),
    _NavItem('Xonalar', Icons.apartment_rounded, Icons.apartment_outlined,
        _C.orange),
    _NavItem('Murojaatlar', Icons.forum_rounded, Icons.forum_outlined, _C.pink),
    _NavItem('Rol boshqaruvi', Icons.admin_panel_settings_rounded,
        Icons.admin_panel_settings_outlined, _C.violet),
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
        hostel: widget.user.hostel ?? 'boys',
      ),
      TalabalarList(
        isAdmin: true,
        canDelete: _isSuperAdmin,
        scaffoldKey: _scaffoldKey,
        hostel: widget.user.hostel ?? 'boys',
      ),
      XonalarList(
        isAdmin: true,
        hostel: widget.user.hostel ?? 'boys',
      ),
      // Admin endi BARCHA murojaatlarni ko'radi: ham o'ziga ("admin"),
      // ham mudirga yuborilganlarni — har birida "kimga" va "kimdan"
      // (yuboruvchi) ma'lumoti bilan birga.
      MurojaatlarList(
        isAdmin: true,
        hostel: widget.user.hostel ?? 'boys',
        studentId: null,
        currentUser: widget.user,
        roleFilter: null,
      ),
      _RoleManagementTab(
          scaffoldKey: _scaffoldKey, isSuperAdmin: _isSuperAdmin),
      TolovCheklariScreen(
          onBack: () => setState(() => _selectedIndex = 0),
          currentUser: widget.user),
      IjtimoiyImtiyozScreen(
          onBack: () => setState(() => _selectedIndex = 0),
          initialHostel: widget.user.hostel),
      _AdminSettingsTab(user: widget.user),
    ]);
  }

  // 3️⃣ Barcha foydalanuvchilar va admin uchun tizimdan chiqishni to'g'rilash
  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut(); // Firebase seansini yopish
      await AuthService.logout(); // Mavjud servisni ham chaqiramiz

      if (mounted) {
        // Router muammosini oldini olish uchun pushAndRemoveUntil bilan login sahifasiga tozalab o'tamiz
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

  // Bu sahifalar o'z AppBar'iga ega — qobiqning AppBar'ini berkitamiz
  bool get _ownsAppBar =>
      _selectedIndex == 4 ||
      _selectedIndex == 1 ||
      _selectedIndex == 5 ||
      _selectedIndex == 6;

  @override
  Widget build(BuildContext context) {
    debugPrint("===============");
    debugPrint("Admin hostel = ${widget.user.hostel}");
    debugPrint("Admin role = ${widget.user.role}");
    debugPrint("===============");

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _C.bgBase,
      extendBodyBehindAppBar: false,
      appBar: _ownsAppBar
          ? null
          : _CreativeAppBar(
              title: _navItems[_selectedIndex].label,
              showGradient: _selectedIndex != 0 && _selectedIndex != 7,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onBellTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BildirishnomaYuborish()),
                );
              },
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
                      child: const Text(
                        "SUPER ADMIN",
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
                if (index == 5) const _TolovBadgeDot(),
                if (index == 6) const IjtimoiyImtiyozBadge(),
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
  final VoidCallback onBellTap;
  final VoidCallback onLogoutTap;
  final bool showGradient;

  const _CreativeAppBar({
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
                colors: [_C.purple, _C.violet], // #6C5CE7 → #A29BFE
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
                        color: _C.pink,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: showGradient ? _C.violet : _C.bgBase,
                            width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
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

// ========== ROLE MANAGEMENT TAB ==========
class _RoleManagementTab extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool isSuperAdmin;
  const _RoleManagementTab(
      {required this.scaffoldKey, required this.isSuperAdmin});
  @override
  __RoleManagementTabState createState() => __RoleManagementTabState();
}

class __RoleManagementTabState extends State<_RoleManagementTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final query = _searchQuery.toLowerCase();
    return _users.where((user) {
      final fullName = (user['fullName'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      return fullName.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('foydalanuvchilar').get();
      if (!mounted) return;
      _users = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Xatolik foydalanuvchilarni yuklashda: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRole(String userId, String newRole) async {
    await FirebaseFirestore.instance
        .collection('foydalanuvchilar')
        .doc(userId)
        .update({
      'role': newRole,
    });
    await _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Rol o'zgartirildi"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgBase,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: _C.bgBase,
            border:
                Border(bottom: BorderSide(color: _C.white.withOpacity(0.06))),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  if (!_isSearching)
                    _AppBarIconBtn(
                      icon: Icons.menu_rounded,
                      onTap: () =>
                          widget.scaffoldKey.currentState?.openDrawer(),
                    )
                  else
                    const SizedBox(width: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isSearching
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            style:
                                const TextStyle(color: _C.white, fontSize: 14),
                            cursorColor: _C.violet,
                            decoration: InputDecoration(
                              hintText: "Ism yoki email bo'yicha izlash...",
                              hintStyle:
                                  TextStyle(color: _C.muted, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          )
                        : const Text(
                            'Rol boshqaruvi',
                            style: TextStyle(
                              color: _C.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  _AppBarIconBtn(
                    icon: _isSearching
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    onTap: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) _searchController.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_C.purple, _C.violet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _C.purple.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      AdminAddUserScreen(isSuperAdmin: widget.isSuperAdmin)),
            ).then((_) => _loadUsers());
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
          label: const Text("Yangi foydalanuvchi",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _C.violet))
          : _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 56, color: _C.muted),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Foydalanuvchilar topilmadi'
                            : '"$_searchQuery" bo\'yicha natija yo\'q',
                        style: TextStyle(color: _C.muted, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    var user = _filteredUsers[index];
                    String currentRole = user['role'] ?? 'talaba';
                    String fullName = user['fullName'] ?? 'Noma\'lum';
                    String email = user['email'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _C.bgCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _C.faint),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color:
                                  _getRoleColor(currentRole).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: _getRoleColor(currentRole)
                                      .withOpacity(0.35)),
                            ),
                            child: Center(
                              child: Text(
                                fullName.isNotEmpty
                                    ? fullName[0].toUpperCase()
                                    : "?",
                                style: TextStyle(
                                  color: _getRoleColor(currentRole),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    color: _C.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  style: TextStyle(
                                      color: _C.muted, fontSize: 11.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(builder: (context) {
                            // Oddiy 'admin' rolidagi foydalanuvchi
                            // 'admin'/'superAdmin' rolidagi boshqa
                            // foydalanuvchining rolini umuman o'zgartira
                            // olmaydi — bu huquq faqat superAdmin'da.
                            final bool isProtectedTarget =
                                !widget.isSuperAdmin &&
                                    (currentRole == 'admin' ||
                                        currentRole == 'superAdmin');
                            final List<String> selectableRoles = [
                              // Faqat superAdmin boshqa foydalanuvchini
                              // 'admin' yoki 'superAdmin' qilib
                              // o'zgartira oladi — oddiy admin bu
                              // huquqlarni ko'rmaydi.
                              if (widget.isSuperAdmin) 'superAdmin',
                              if (widget.isSuperAdmin) 'admin',
                              'mudir',
                              'moliyachi',
                              'talaba',
                              // Joriy qiymat ro'yxatda bo'lishi shart
                              // (Dropdown value assertion uchun), hatto
                              // tanlab bo'lmasa ham.
                              if (![
                                'superAdmin',
                                'admin',
                                'mudir',
                                'moliyachi',
                                'talaba'
                              ].contains(currentRole))
                                currentRole,
                              if (isProtectedTarget) currentRole,
                            ];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _C.bgBase,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: _C.white.withOpacity(0.08)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  dropdownColor: _C.bgCard,
                                  style: TextStyle(
                                      color: _getRoleColor(currentRole),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                  icon: Icon(Icons.expand_more_rounded,
                                      color: _C.muted, size: 18),
                                  value: selectableRoles.contains(currentRole)
                                      ? currentRole
                                      : 'talaba',
                                  // isProtectedTarget bo'lsa, dropdown
                                  // faol bo'lsa-da tanlash imkonsiz —
                                  // faqat bitta variant (joriy rol) beriladi.
                                  items: (isProtectedTarget
                                          ? {currentRole}
                                          : selectableRoles.toSet())
                                      .map((role) {
                                    return DropdownMenuItem(
                                      value: role,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(role),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_getRoleText(role)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: isProtectedTarget
                                      ? null
                                      : (newRole) {
                                          if (newRole != null &&
                                              newRole != currentRole) {
                                            _changeRole(user['id'], newRole);
                                          }
                                        },
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'superAdmin':
        return _C.violet;
      case 'admin':
        return _C.pink;
      case 'mudir':
        return _C.teal;
      case 'moliyachi':
        return _C.orange;
      case 'talaba':
        return _C.mint;
      default:
        return _C.muted;
    }
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'superAdmin':
        return "Super Admin";
      case 'admin':
        return "Admin";
      case 'mudir':
        return "Yotoqxona Mudiri";
      case 'moliyachi':
        return "Moliyachi";
      case 'talaba':
        return "Talaba";
      default:
        return role;
    }
  }
}

// ========== ADMIN SETTINGS TAB ==========
class _AdminSettingsTab extends StatefulWidget {
  final UserModel user;
  const _AdminSettingsTab({required this.user});
  @override
  __AdminSettingsTabState createState() => __AdminSettingsTabState();
}

class __AdminSettingsTabState extends State<_AdminSettingsTab> {
  bool _notificationsEnabled = true;
  double _defaultPaymentAmount = 500000;
  bool _isLoading = false;

  bool get _isSuperAdmin => widget.user.role == UserRole.superAdmin;

  // 4️⃣ O'g'il bolalar yotoqxonasidagi TALABALARNI to'liq shaxsiy
  // ma'lumotlari (ro'yxatdan o'tgan vaqti, o'zi/Admin qo'shganligi va
  // ro'yxatdan o'tishda kiritilgan barcha ma'lumotlari bilan) Excel
  // formatida yuklab olish (Export to Excel) integratsiyasi.
  void _exportDatabase() async {
    setState(() => _isLoading = true);
    try {
      await ExcelExportService.exportBoysStudentsToExcel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Excel yuklab olindi!"),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Excel yuklashda xatolik: $e"),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                                      "Admin \"Xonalar\" bo'limidan bo'sh xonalarni ko'radi",
                                ),
                                SizedBox(height: 8),
                                _StepRow(
                                  number: "3",
                                  text:
                                      "Admin talabaga mos xonani tanlab, \"Xona taqsimlash\" orqali biriktiradi",
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
                                  "Bunday tartib xato biriktirish ehtimolini yo'q qiladi va har bir qaror admin nazoratida bo'ladi.",
                                  style: TextStyle(
                                      fontSize: 12.5, color: _C.muted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 🔒 Admin uchun "Ma'lumotlar bazasi" bo'limi umuman
                    // ko'rinmasligi kerak — faqat superAdmin ko'radi.
                    if (_isSuperAdmin) ...[
                      const SizedBox(height: 14),
                      _SettingsCard(
                        icon: Icons.storage_rounded,
                        iconColor: _C.teal,
                        title: "Ma'lumotlar bazasi",
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: GestureDetector(
                                onTap: _exportDatabase,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_C.teal, _C.mint],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.file_download_rounded,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          "Barcha talabalarni (o'g'il va qiz bolalar) to'liq ma'lumotlari bilan Excelga yuklash (XLSX)",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: GestureDetector(
                                onTap: _clearAllData,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    color: _C.pink.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: _C.pink.withOpacity(0.25)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete_sweep_outlined,
                                          color: _C.pink, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        "Barcha ma'lumotlarni tozalash",
                                        style: TextStyle(
                                            color: _C.pink,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ], // if (_isSuperAdmin) — Ma'lumotlar bazasi bo'limi
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
                            title: "Super Admin",
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

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _C.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _C.pink),
            SizedBox(width: 8),
            Text("DIQQAT!",
                style: TextStyle(color: _C.white, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          "Barcha ma'lumotlar o'chiriladi.\nBu amalni qaytarib bo'lmaydi!\n\nDavom etasizmi?",
          style: TextStyle(color: _C.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Bekor qilish", style: TextStyle(color: _C.muted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              final collections = [
                'foydalanuvchilar',
                'xonalar',
                'murojaatlar',
                'tolovlar',
                'bildirishnomalar',
                'sorovnomalar'
              ];
              try {
                for (var col in collections) {
                  var snapshot =
                      await FirebaseFirestore.instance.collection(col).get();
                  for (var doc in snapshot.docs) {
                    await doc.reference.delete();
                  }
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Barcha ma'lumotlar tozalandi"),
                      backgroundColor: Colors.red),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Xatolik yuz berdi: $e"),
                      backgroundColor: Colors.orange),
                );
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Ha, tozalash",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Settings UI yordamchilari ──────────────────────────────────
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
