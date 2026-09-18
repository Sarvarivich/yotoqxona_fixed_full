import 'package:flutter/material.dart';
import '../../../services/api_service.dart';

import '../../theme/girls_theme.dart';
import '../../../../roles/admin_add_user_screen.dart';

// ─── GirlsRoleManagementTab: Qizlar yotoqxonasi admin qobig'i uchun
// "Rol boshqaruvi" bo'limi. Boys tomonidagi
// roles/admin_screen.dart -> _RoleManagementTab bilan BIR XIL vazifani
// bajaradi (dizayn tili ham bir xil, faqat GTheme ranglaridan
// foydalanadi): 'foydalanuvchilar' Firestore to'plamidagi BARCHA
// ro'yxatdan o'tgan talaba va hodimlarni (hostel'idan qat'i nazar)
// ko'rsatadi va ularning rolini o'zgartirish imkonini beradi.
//
// Ilgari qizlar bo'limida bunday sahifa umuman yo'q edi — shuning
// uchun "Qiz bolalar" oqimi tanlanganda ro'yxatdan o'tgan
// foydalanuvchilarni boshqarish imkonsiz edi.
class GirlsRoleManagementTab extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final bool isSuperAdmin;
  final bool canDelete;
  final String? currentUserId;

  const GirlsRoleManagementTab({
    super.key,
    required this.scaffoldKey,
    required this.isSuperAdmin,
    this.canDelete = true,
    this.currentUserId,
  });

  @override
  State<GirlsRoleManagementTab> createState() => _GirlsRoleManagementTabState();
}

class _GirlsRoleManagementTabState extends State<GirlsRoleManagementTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _hostelFilter = 'all'; // all | girls | boys

  List<Map<String, dynamic>> get _filteredUsers {
    var list = _users;
    if (_hostelFilter != 'all') {
      list = list.where((user) {
        final h = (user['hostel'] ?? 'boys').toString().toLowerCase();
        return h == _hostelFilter;
      }).toList();
    }
    if (_searchQuery.isEmpty) return list;
    final query = _searchQuery.toLowerCase();
    return list.where((user) {
      final fullName = ((user['full_name'] ?? user['fullName']) ?? '')
          .toString()
          .toLowerCase();
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
      // Laravel'da boys va girls yagona `users` jadvalida, shuning
      // uchun bu yerda ikkala yotoqxonadagi barcha talaba va xodim
      // ko'rinadi. Backend ruxsatni o'zi tekshiradi.
      //
      // per_page=100 hozircha yetarli. 2500 foydalanuvchida bu
      // ekranga ham sahifalash qo'shish kerak bo'ladi.
      final javob = await ApiService().get('students?per_page=100');
      if (!mounted) return;

      final royxat = javob['data'];
      _users = royxat is List
          ? royxat
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint("Xatolik foydalanuvchilarni yuklashda: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRole(String userId, String newRole) async {
    // Rolni faqat superAdmin o'zgartira oladi - buni backend
    // UserPolicy::changeRole() tekshiradi.
    try {
      await ApiService().updateStudent(userId, {'role': newRole});
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Rol o'zgartirildi"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Rolni o'zgartirib bo'lmadi: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _confirmDelete(String userId, String fullName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GTheme.bgCard,
        title: const Text("Foydalanuvchini o'chirish",
            style: TextStyle(color: Colors.white)),
        content: Text(
          "Haqiqatan ham \"$fullName\" foydalanuvchisini o'chirmoqchimisiz? Ushbu amalni ortga qaytarib bo'lmaydi.",
          style: const TextStyle(color: GTheme.soft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("O'chirish", style: TextStyle(color: GTheme.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService().deleteStudent(userId);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Foydalanuvchi o'chirildi"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("O'chirishda xatolik: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GTheme.bgBase,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: GTheme.bgBase,
            border: Border(
                bottom: BorderSide(color: GTheme.white.withOpacity(0.06))),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  if (!_isSearching)
                    _GirlsAppBarIconBtn(
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
                            style: const TextStyle(
                                color: GTheme.white, fontSize: 14),
                            cursorColor: GTheme.pink,
                            decoration: InputDecoration(
                              hintText: "Ism yoki email bo'yicha izlash...",
                              hintStyle:
                                  TextStyle(color: GTheme.muted, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          )
                        : const Text(
                            'Rol boshqaruvi',
                            style: TextStyle(
                              color: GTheme.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  _GirlsAppBarIconBtn(
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
            colors: [GTheme.pink, GTheme.violet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: GTheme.pink.withOpacity(0.4),
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
                  builder: (_) => AdminAddUserScreen(
                        isSuperAdmin: widget.isSuperAdmin,
                        initialHostel: 'girls',
                      )),
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
      body: Column(
        children: [
          // Yotoqxona filter chip-lari
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _filterChip('all', 'Barchasi'),
                const SizedBox(width: 8),
                _filterChip('girls', 'Qizlar'),
                const SizedBox(width: 8),
                _filterChip('boys', "O'g'il bolalar"),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: GTheme.pink))
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 56, color: GTheme.muted),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Foydalanuvchilar topilmadi'
                                  : '"$_searchQuery" bo\'yicha natija yo\'q',
                              style:
                                  TextStyle(color: GTheme.muted, fontSize: 14),
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
                          String fullName =
                              (user['full_name'] ?? user['fullName']) ??
                                  'Noma\'lum';
                          String email = user['email'] ?? '';
                          String hostel = user['hostel'] ?? 'boys';
                          // Oddiy 'admin' rolidagi foydalanuvchi
                          // 'admin'/'superAdmin' rolidagi boshqa
                          // foydalanuvchining rolini yoki hisobini o'zgartira/o'chira
                          // olmaydi — bu huquq faqat superAdmin'da.
                          final bool isProtectedTarget = !widget.isSuperAdmin &&
                              (currentRole == 'admin' ||
                                  currentRole == 'superAdmin');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: GTheme.bgCard,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: GTheme.faint),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(currentRole)
                                        .withOpacity(0.18),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              fullName,
                                              style: const TextStyle(
                                                color: GTheme.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          _HostelChip(hostel: hostel),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        email,
                                        style: TextStyle(
                                            color: GTheme.muted,
                                            fontSize: 11.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Builder(builder: (context) {
                                  final List<String> selectableRoles = [
                                    if (widget.isSuperAdmin) 'superAdmin',
                                    if (widget.isSuperAdmin) 'admin',
                                    'mudir',
                                    'moliyachi',
                                    'talaba',
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
                                      color: GTheme.bgBase,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color:
                                              GTheme.white.withOpacity(0.08)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        dropdownColor: GTheme.bgCard,
                                        style: TextStyle(
                                            color: _getRoleColor(currentRole),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700),
                                        icon: Icon(Icons.expand_more_rounded,
                                            color: GTheme.muted, size: 18),
                                        value: selectableRoles
                                                .contains(currentRole)
                                            ? currentRole
                                            : 'talaba',
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
                                                  _changeRole(
                                                      user['id'], newRole);
                                                }
                                              },
                                      ),
                                    ),
                                  );
                                }),
                                if (widget.canDelete &&
                                    user['id'] != widget.currentUserId &&
                                    !isProtectedTarget) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: GTheme.red,
                                        size: 20),
                                    tooltip: "O'chirish",
                                    onPressed: () => _confirmDelete(
                                        user['id'] ?? '', fullName),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _hostelFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _hostelFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? GTheme.pink : GTheme.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? GTheme.pink : GTheme.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : GTheme.soft,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'superAdmin':
        return GTheme.violet;
      case 'admin':
        return GTheme.pink;
      case 'mudir':
        return GTheme.teal;
      case 'moliyachi':
        return GTheme.orange;
      case 'talaba':
        return GTheme.mint;
      default:
        return GTheme.muted;
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

// ─── Yotoqxona (boys/girls) yorlig'i — qaysi yotoqxonaga
// ro'yxatdan o'tganini bir qarashda ko'rsatadi.
class _HostelChip extends StatelessWidget {
  final String hostel;
  const _HostelChip({required this.hostel});

  @override
  Widget build(BuildContext context) {
    final isGirls = hostel == 'girls';
    final color = isGirls ? GTheme.pink : GTheme.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isGirls ? 'Qizlar' : "O'g'illar",
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GirlsAppBarIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GirlsAppBarIconBtn({required this.icon, required this.onTap});

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
