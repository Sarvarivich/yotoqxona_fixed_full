import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:yotoqxona/modules/models/user_model.dart';
import 'package:yotoqxona/modules/services/api_service.dart';

// ─── Creative LIGHT palette ───
class _LC {
  static const bg = Color(0xFFF3F1FB);
  static const card = Colors.white;
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFA29BFE);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFFD79A8);
  static const orange = Color(0xFFFDCB6E);
  static const coral = Color(0xFFE17055);
  static const ink = Color(0xFF2D2A4A);
  static const muted = Color(0xFF8B86A8);
  static const faint = Color(0xFFE9E5FA);
}

class TalabalarList extends StatefulWidget {
  final bool isAdmin;
  final String hostel;
  final bool? canDelete;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  const TalabalarList(
      {super.key,
      required this.isAdmin,
      required this.hostel,
      this.canDelete,
      this.scaffoldKey});

  @override
  State<TalabalarList> createState() => _TalabalarListState();
}

class _TalabalarListState extends State<TalabalarList> {
  final ApiService _apiService = ApiService();
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String _selectedHostel;
  String _roomFilter = 'all';

  bool _isLoading = true;
  String? _errorMessage;
  List<UserModel> _allUsers = [];

  // --- Sahifalash holati ---
  final ScrollController _scrollController = ScrollController();
  static const int _perPage = 10;
  int _page = 1;
  int _total = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Timer? _searchDebounce;
  final Map<String, String> _roomLabelById = {};
  final Set<String> _assignedIds = {};

  bool get _canDelete => widget.canDelete ?? widget.isAdmin;

  @override
  void initState() {
    super.initState();
    _selectedHostel =
        (widget.hostel.trim().isEmpty ? 'boys' : widget.hostel.trim())
            .toLowerCase();
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  // Qidiruv: har bosilgan harfda so'rov yubormaslik uchun
  // 400 ms kutamiz (debounce). 2500 talabada bu muhim.
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text);
      _loadData();
    });
  }

  // Ro'yxat oxiriga yaqinlashganda keyingi sahifani yuklaymiz.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final chegara = _scrollController.position.maxScrollExtent - 300;
    if (_scrollController.position.pixels >= chegara) {
      _loadMore();
    }
  }

  // Keyingi sahifa.
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() => _isLoadingMore = true);

    try {
      final javob = await _apiService.getStudentsPaged(
        page: _page + 1,
        perPage: _perPage,
        search: _searchQuery,
      );

      final royxat = javob['data'] as List<dynamic>;
      final meta = javob['meta'] as Map<String, dynamic>;

      if (!mounted) return;

      final yangilar = <UserModel>[];
      for (final s in royxat) {
        if (s is Map) {
          final userMap = Map<String, dynamic>.from(s);
          _xonaMalumotiniYig(userMap);
          yangilar.add(UserModel.fromJson(userMap));
        }
      }

      setState(() {
        _allUsers.addAll(yangilar);
        _page = (meta['current_page'] as num?)?.toInt() ?? (_page + 1);
        final oxirgi = (meta['last_page'] as num?)?.toInt() ?? _page;
        _hasMore = _page < oxirgi;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Keyingi sahifani yuklab bo\'lmadi: $e')),
      );
    }
  }

  // Xona ma'lumotini _roomLabelById va _assignedIds ga yozadi.
  void _xonaMalumotiniYig(Map<String, dynamic> userMap) {
    final activeRoom =
        userMap['active_room_assignment'] ?? userMap['activeRoomAssignment'];
    if (activeRoom is Map && activeRoom['room'] is Map) {
      final uId = userMap['id']?.toString() ?? '';
      if (uId.isNotEmpty) {
        _assignedIds.add(uId);
        final roomNum = activeRoom['room']['room_number'] ??
            activeRoom['room']['roomNumber'] ??
            '-';
        final floor = activeRoom['room']['floor'] ?? '-';
        _roomLabelById[uId] = "$roomNum-xona ($floor-qavat)";
      }
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Birinchi sahifa. Qolgani _loadMore() orqali qo'shiladi.
      _page = 1;
      _hasMore = true;
      final javob = await _apiService.getStudentsPaged(
        page: 1,
        perPage: _perPage,
        search: _searchQuery,
      );
      final studentsData = javob['data'] as List<dynamic>;
      final meta = javob['meta'] as Map<String, dynamic>;
      _total = (meta['total'] as num?)?.toInt() ?? studentsData.length;
      final oxirgiSahifa = (meta['last_page'] as num?)?.toInt() ?? 1;
      _hasMore = 1 < oxirgiSahifa;
      final assignmentsData = await _apiService.getRoomAssignments();

      final labelById = <String, String>{};
      final assigned = <String>{};

      for (final item in assignmentsData) {
        if (item is Map) {
          final studentId = (item['student_id'] ??
                  (item['student'] is Map ? item['student']['id'] : null))
              ?.toString();
          if (studentId != null) {
            assigned.add(studentId);
            if (item['room'] is Map) {
              final roomNum = item['room']['room_number'] ??
                  item['room']['roomNumber'] ??
                  '-';
              final floor = item['room']['floor'] ?? '-';
              labelById[studentId] = "$roomNum-xona ($floor-qavat)";
            }
          }
        }
      }

      final users = <UserModel>[];
      for (final s in studentsData) {
        if (s is Map) {
          final userMap = Map<String, dynamic>.from(s);
          final activeRoom = userMap['active_room_assignment'] ??
              userMap['activeRoomAssignment'];
          if (activeRoom is Map && activeRoom['room'] is Map) {
            final uId = userMap['id']?.toString() ?? '';
            if (uId.isNotEmpty) {
              assigned.add(uId);
              final roomNum = activeRoom['room']['room_number'] ??
                  activeRoom['room']['roomNumber'] ??
                  '-';
              final floor = activeRoom['room']['floor'] ?? '-';
              labelById[uId] = "$roomNum-xona ($floor-qavat)";
            }
          }
          users.add(UserModel.fromJson(userMap));
        }
      }

      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _roomLabelById.clear();
        _roomLabelById.addAll(labelById);
        _assignedIds.clear();
        _assignedIds.addAll(assigned);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  List<UserModel> _filterUsers(
      List<UserModel> users, Set<String> assignedIds) {
    Iterable<UserModel> result = users;

    result = result.where((u) {
      final hostel = (u.hostel ?? '').trim().toLowerCase();
      final normalizedHostel = hostel.isEmpty ? 'boys' : hostel;
      return normalizedHostel == _selectedHostel.toLowerCase();
    });

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((u) {
        final fullName = u.fullName.toLowerCase();
        final email = u.email.toLowerCase();
        final phone = (u.phoneNumber ?? '').toLowerCase();
        return fullName.contains(query) ||
            email.contains(query) ||
            phone.contains(query);
      });
    }

    if (_roomFilter != 'all') {
      result = result.where((u) {
        if (u.role != UserRole.talaba) return true;
        final isAssigned = assignedIds.contains(u.id);
        return _roomFilter == 'assigned' ? isAssigned : !isAssigned;
      });
    }

    return result.toList();
  }

  void _confirmDelete(BuildContext context, String docId, String fullName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _LC.coral),
            SizedBox(width: 8),
            Text('O\'chirishni tasdiqlang'),
          ],
        ),
        content: Text(
          '"$fullName" foydalanuvchisini tizimdan butunlay o\'chirmoqchimisiz?\n\nBu amalni qaytarib bo\'lmaydi!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.delete, color: Colors.white, size: 18),
            label:
                const Text('O\'chirish', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _deleteUser(context, docId, fullName);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(
    BuildContext context,
    String docId,
    String fullName,
  ) async {
    try {
      await _apiService.deleteStudent(docId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$fullName" muvaffaqiyatli o\'chirildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('O\'chirishda xatolik: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _selectedHostel == "boys" ? _LC.purple : Colors.white,
                      foregroundColor:
                          _selectedHostel == "boys" ? Colors.white : _LC.purple,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedHostel = "boys";
                      });
                    },
                    child: const Text("O'g'il bolalar"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedHostel == "girls"
                          ? _LC.purple
                          : Colors.white,
                      foregroundColor: _selectedHostel == "girls"
                          ? Colors.white
                          : _LC.purple,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedHostel = "girls";
                      });
                    },
                    child: const Text("Qiz bolalar"),
                  ),
                ),
              ],
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        leading: _isSearching
            ? null
            : widget.scaffoldKey != null
                ? IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () =>
                        widget.scaffoldKey!.currentState?.openDrawer(),
                  )
                : null,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_LC.purple, _LC.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Ism yoki email bo\'yicha izlash...',
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: Colors.white70),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Colors.white70),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              )
            : const Text(
                'Talabalar va Hodimlar',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchController.clear();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _LC.purple),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Xatolik yuz berdi:\n$_errorMessage",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text("Qayta yuklash"),
                      ),
                    ],
                  ),
                )
              : _buildBody(context, _roomLabelById, _assignedIds),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, String> roomLabelById,
      Set<String> assignedIds) {
    final docs = _filterUsers(_allUsers, assignedIds);

    Widget listArea;
    if (_allUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 56, color: _LC.muted),
            const SizedBox(height: 12),
            const Text(
              "Foydalanuvchilar topilmadi.",
              style: TextStyle(
                  fontSize: 15,
                  color: _LC.muted,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (docs.isEmpty) {
      final hostelLabel =
          _selectedHostel == "boys" ? "O'g'il bolalar" : "Qiz bolalar";
      final message = _searchQuery.isEmpty && _roomFilter == 'all'
          ? "$hostelLabel yotoqxonasida hozircha foydalanuvchi yo'q"
          : _searchQuery.isNotEmpty
              ? '"$_searchQuery" bo\'yicha natija topilmadi'
              : "Ushbu filtr bo'yicha talaba topilmadi";
      listArea = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                _searchQuery.isEmpty
                    ? Icons.people_outline_rounded
                    : Icons.search_off_rounded,
                size: 56,
                color: _LC.muted),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                  color: _LC.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      listArea = RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          itemBuilder: (context, index) {
            final currentUser = docs[index];
            final roleColor = _getRoleColor(currentUser.role);
            final roomLabel = roomLabelById[currentUser.id];
            final hasRoom = roomLabel != null;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _LC.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _LC.faint),
                boxShadow: [
                  BoxShadow(
                    color: _LC.purple.withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    _openUserManagementDialog(context, currentUser);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.person_rounded, color: roleColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUser.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: _LC.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                currentUser.email,
                                style: const TextStyle(
                                    color: _LC.muted, fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (currentUser.role == UserRole.talaba) ...[
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: (hasRoom ? _LC.mint : _LC.coral)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        hasRoom
                                            ? Icons.meeting_room_rounded
                                            : Icons.meeting_room_outlined,
                                        size: 12,
                                        color: hasRoom
                                            ? const Color(0xFF12A181)
                                            : _LC.coral,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        roomLabel ?? 'Biriktirilmagan',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: hasRoom
                                              ? const Color(0xFF12A181)
                                              : _LC.coral,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                currentUser.role
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                style: TextStyle(
                                    color: roleColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (_canDelete) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _confirmDelete(
                                    context, currentUser.id, currentUser.fullName),
                                child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: _LC.coral,
                                    size: 19),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Column(
      children: [
        _buildRoomFilterChips(),
        Expanded(child: listArea),
      ],
    );
  }

  // 🏠 "Barchasi / Biriktirilgan / Biriktirilmagan" filtr chiplari —
  // faqat talabalar ro'yxatini xona holati bo'yicha filtrlash uchun.
  Widget _buildRoomFilterChips() {
    Widget chip(String label, String value, IconData icon) {
      final selected = _roomFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => setState(() => _roomFilter = value),
          avatar:
              Icon(icon, size: 15, color: selected ? Colors.white : _LC.purple),
          label: Text(label),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _LC.ink,
          ),
          selectedColor: _LC.purple,
          backgroundColor: _LC.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: selected ? _LC.purple : _LC.faint),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Barchasi', 'all', Icons.groups_rounded),
            chip(
                'Xonaga biriktirilgan', 'assigned', Icons.meeting_room_rounded),
            chip('Biriktirilmagan', 'unassigned', Icons.meeting_room_outlined),
          ],
        ),
      ),
    );
  }

  // Rollarga qarab rang ajratish uchun yordamchi funksiya
  Color _getRoleColor(UserRole role) {
    switch (role.toString().split('.').last) {
      case 'admin':
        return _LC.coral;
      case 'mudir':
        return _LC.purple;
      case 'manager':
        return _LC.orange;
      default:
        return _LC.teal;
    }
  }

  // 🏠 Talabaga biriktirilgan xona haqida ma'lumot olish
  Future<String?> _getAssignedRoomInfo(String userId) async {
    return _roomLabelById[userId];
  }

  // 🌟 Dialogni ochishdan oldin (agar talaba bo'lsa) xona ma'lumotini
  // oldindan yuklab olamiz — shu tufayli dialog ichida "Yuklanmoqda..."
  // holatida osilib qolish muammosi butunlay bartaraf etiladi.
  Future<void> _openUserManagementDialog(
      BuildContext context, UserModel selectedUser) async {
    String? roomInfo;
    if (selectedUser.role == UserRole.talaba) {
      roomInfo = await _getAssignedRoomInfo(selectedUser.id);
    }
    if (!context.mounted) return;
    _showUserManagementDialog(context, selectedUser,
        assignedRoomInfo: roomInfo);
  }

  // 🌟 ADMIN UCHUN TANLANGAN FOYDALANUVCHINI BOSGANDA CHIQUVCHI ASOSIY DIALOG
  void _showUserManagementDialog(BuildContext context, UserModel selectedUser,
      {String? assignedRoomInfo}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.manage_accounts, color: _LC.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedUser.fullName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor:
                      _getRoleColor(selectedUser.role).withOpacity(0.1),
                  child: Icon(Icons.person,
                      size: 40, color: _getRoleColor(selectedUser.role)),
                ),
                const SizedBox(height: 16),

                // 1. FIO Ko'rinishi va tahrirlash
                ListTile(
                  leading: const Icon(Icons.person_outline, color: _LC.purple),
                  title: const Text("FIO"),
                  subtitle: Text(selectedUser.fullName),
                  trailing:
                      const Icon(Icons.edit, size: 18, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _editUserField(context, selectedUser, "FIO", "fullName",
                        selectedUser.fullName);
                  },
                ),

                // 2. Telefon Ko'rinishi va tahrirlash
                ListTile(
                  leading: const Icon(Icons.phone_android, color: _LC.teal),
                  title: const Text("Telefon"),
                  subtitle: Text(selectedUser.phoneNumber ?? "Kiritilmagan"),
                  trailing:
                      const Icon(Icons.edit, size: 18, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _editUserField(context, selectedUser, "Telefon",
                        "phoneNumber", selectedUser.phoneNumber ?? "");
                  },
                ),

                // 3. Email (O'zgartirib bo'lmaydi)
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Colors.grey),
                  title: const Text("Email"),
                  subtitle: Text(selectedUser.email),
                ),

                // 4. Rol ko'rinishi
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings,
                      color: Colors.purple),
                  title: const Text("Tizimdagi roli"),
                  subtitle: Text(selectedUser.role
                      .toString()
                      .split('.')
                      .last
                      .toUpperCase()),
                ),

                // 4.1. Faqat talabalar uchun: biriktirilgan xona ma'lumoti
                if (selectedUser.role == UserRole.talaba)
                  ListTile(
                    leading: const Icon(Icons.meeting_room_outlined,
                        color: _LC.teal),
                    title: const Text("Biriktirilgan xona"),
                    subtitle: Text(
                      assignedRoomInfo ?? "Hali xonaga biriktirilmagan",
                      style: TextStyle(
                        color: assignedRoomInfo != null &&
                                !assignedRoomInfo.startsWith("Xatolik")
                            ? _LC.ink
                            : _LC.coral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Divider(),

                // 🔐 5. ADMIN UCHUN PAROLNI TO'G'RIDAN-TO'G'RI YANGILASH
                ListTile(
                  leading: const Icon(Icons.lock_open, color: _LC.coral),
                  title: const Text(
                    "Parolni majburiy yangilash",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.red),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _adminChangeUserPassword(context, selectedUser);
                  },
                ),

                if (_canDelete) ...[
                  const Divider(),

                  // 🗑️ 6. FOYDALANUVCHINI O'CHIRISH
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: _LC.coral),
                    title: const Text(
                      "Foydalanuvchini o'chirish",
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.red),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _confirmDelete(
                          context, selectedUser.id, selectedUser.fullName);
                    },
                  ),
                ],
              ],
            ),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Yopish"),
            ),
          ],
        );
      },
    );
  }

  // 📝 FOYDALANUVCHI MA'LUMOTLARINI (FIO, TELEFON) TAHRIRLASH DIALOGI
  void _editUserField(BuildContext context, UserModel selectedUser,
      String label, String fieldName, String currentValue) {
    final TextEditingController fieldController =
        TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$label tahrirlash"),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: fieldController,
            decoration: InputDecoration(
              labelText: label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? "Maydon bo'sh bo'lishi mumkin emas"
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openUserManagementDialog(context, selectedUser);
            },
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              String newValue = fieldController.text.trim();
              try {
                final Map<String, dynamic> updateBody = {};
                if (fieldName == 'fullName') {
                  updateBody['name'] = newValue;
                  updateBody['full_name'] = newValue;
                } else if (fieldName == 'phoneNumber') {
                  updateBody['phone'] = newValue;
                  updateBody['phone_number'] = newValue;
                } else {
                  updateBody[fieldName] = newValue;
                }

                await _apiService.updateStudent(selectedUser.id, updateBody);

                if (context.mounted) {
                  Navigator.pop(context);
                  final updatedUser = UserModel(
                    id: selectedUser.id,
                    fullName: fieldName == 'fullName'
                        ? newValue
                        : selectedUser.fullName,
                    email: selectedUser.email,
                    role: selectedUser.role,
                    phoneNumber: fieldName == 'phoneNumber'
                        ? newValue
                        : selectedUser.phoneNumber,
                    hostel: selectedUser.hostel,
                    roomId: selectedUser.roomId,
                    faculty: selectedUser.faculty,
                    course: selectedUser.course,
                  );
                  _openUserManagementDialog(context, updatedUser);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("$label muvaffaqiyatli o'zgartirildi!"),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Xatolik yuz berdi: $e"),
                      backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text("Saqlash", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🔐 ADMIN UCHUN FOYDALANUVCHI PAROLINI MAJBURIY YANGILASH DIALOGI
  void _adminChangeUserPassword(BuildContext context, UserModel selectedUser) {
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    final passwordFormKey = GlobalKey<FormState>();
    // 🔓 Standart holatda KO'RINADIGAN qilib qo'ydik (yashirin emas) —
    // chunki bu SuperAdmin BOSHQA birovning (talabaning) yangi parolini
    // o'rnatyapti, o'zining shaxsiy paroli emas. Yashirin bo'lsa, xato
    // yozilgan harf/raqamni hech kim ko'rmaydi va shu "ko'rinmas xato"
    // aynan "email yoki parol xato" shikoyatining asosiy sababi bo'lgan.
    bool obscurePassword = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: _LC.coral),
                  SizedBox(width: 8),
                  Text("Yangi parol o'rnatish"),
                ],
              ),
              content: Form(
                key: passwordFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${selectedUser.fullName} uchun yangi kirish parolini belgilang.",
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Yangi kirish paroli",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Parol kiriting";
                        }
                        if (value.length < 6) {
                          return "Parol kamida 6 belgidan iborat bo'lsin";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // 🆕 Tasdiqlash maydoni: ikkala maydonga bir xil parol
                    // yozilmasa, formani yuborib bo'lmaydi. Shu orqali
                    // ko'rinmas yozuv xatosi (typo) sababli talaba keyin
                    // "to'g'ri" parol bilan ham kira olmay qolishining oldi
                    // olinadi.
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscurePassword,
                      decoration: const InputDecoration(
                        labelText: "Parolni tasdiqlang",
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12))),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Parolni qayta kiriting";
                        }
                        if (value != newPasswordController.text) {
                          return "Parollar mos kelmayapti";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _openUserManagementDialog(context, selectedUser);
                  },
                  child: const Text("Bekor qilish"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!passwordFormKey.currentState!.validate()) return;
                    final String newPassword =
                        newPasswordController.text.trim();
                    try {
                      // ✅ Endi Firestore'ga emas — haqiqiy Firebase
                      // Authentication parolini serverdagi Cloud Function
                      // (Admin SDK) orqali yangilaydi. Shu tufayli
                      // o'zgartirilgan yangi parol bilan darhol kirish
                      // mumkin bo'ladi.
                      await _apiService.updateStudentPassword(
                          studentId: selectedUser.id,
                          newPassword: newPassword);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _openUserManagementDialog(context, selectedUser);
                        // 📋 Yangi parolni aniq ko'rsatamiz va nusxalash
                        // imkonini beramiz — shunda talabaga og'zaki yoki
                        // yozib aytilganda xato ketmaydi (aynan shu turdagi
                        // "typo" xatolari "email/parol xato" shikoyatlarining
                        // eng ko'p uchraydigan sababi bo'lган).
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text("Parol yangilandi"),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${selectedUser.fullName} uchun yangi parol:",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          newPassword,
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded,
                                            size: 18),
                                        tooltip: "Nusxalash",
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: newPassword));
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text("Parol nusxalandi")),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  "Buni talabaga aynan shu ko'rinishda (katta-kichik harflarga e'tibor berib) yetkazing.",
                                  style: TextStyle(
                                      fontSize: 11.5, color: Colors.grey),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Yopish"),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Parol yangilanishida xatolik: $e"),
                            backgroundColor: Colors.red),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Yangilash",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
