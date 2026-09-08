import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';
import '../models/user_model.dart';
import 'murojaat_tafsilotlari.dart';
import 'murojaat_yozish.dart';

// ─── Boshqa bo'limlar bilan bir xil DARK palette ───
class _LC {
  static const bg = Color(0xFF0F0D1A);
  static const card = Color(0xFF1A1730);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFA29BFE);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFFD79A8);
  static const orange = Color(0xFFFDCB6E);
  static const coral = Color(0xFFE17055);
  static const ink = Color(0xFFFFFFFF);
  static const muted = Color(0x99FFFFFF);
  static const faint = Color(0x1FFFFFFF);
}

class MurojaatlarList extends StatefulWidget {
  final bool isAdmin;
  final String hostel;
  final String? studentId;
  final String? studentName;
  // Hozirgi login qilingan foydalanuvchi (mudir/admin javob yozganda "kimdan"
  // ma'lumotini belgilash uchun kerak).
  final UserModel? currentUser;
  // Faqat shu qabul qiluvchiga ("mudir" yoki "admin") yuborilgan murojaatlarni
  // ko'rsatish uchun filtr. null bo'lsa — barcha murojaatlar ko'rsatiladi
  // (masalan, admin barcha murojaatlarni: kimdan va kimga yuborilganini ko'radi).
  final ComplaintTarget? roleFilter;
  const MurojaatlarList({
    super.key,
    required this.isAdmin,
    required this.hostel,
    this.studentId,
    this.studentName,
    this.currentUser,
    this.roleFilter,
  });

  @override
  State<MurojaatlarList> createState() => _MurojaatlarListState();
}

class _MurojaatlarListState extends State<MurojaatlarList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String _selectedHostel;

  @override
  void initState() {
    super.initState();
    // ✅ Admin/mudir uchun ekran o'z yotoqxonasi tanlangan holda ochiladi,
    // so'ngra "O'g'il bolalar" / "Qiz bolalar" tugmalari orqali ikkalasi
    // orasida almashtirishi mumkin (Talabalar va Hodimlar hamda Xonalar
    // bo'limlaridagi kabi). Talaba o'zining murojaatlarini ko'rayotganda
    // bu tanlov ishlatilmaydi — u faqat o'z hostel'i doirasida qoladi.
    _selectedHostel =
        (widget.hostel.trim().isEmpty ? 'boys' : widget.hostel.trim())
            .toLowerCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ Admin/mudir uchun joriy tanlangan bo'lim (_selectedHostel) bo'yicha,
    // talaba uchun esa o'zining hostel'i (widget.hostel) bo'yicha filtrlanadi.
    final effectiveHostel = widget.isAdmin ? _selectedHostel : widget.hostel;
    Query query = FirebaseFirestore.instance
        .collection('murojaatlar')
        .where('hostel', isEqualTo: effectiveHostel);
    if (!widget.isAdmin && widget.studentId != null) {
      query = query.where('studentId', isEqualTo: widget.studentId);
    } else if (widget.isAdmin && widget.roleFilter != null) {
      // Masalan, mudir faqat o'ziga yuborilgan murojaatlarni ko'radi
      query = query.where('targetRole', isEqualTo: widget.roleFilter!.value);
    }

    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.isAdmin
              ? (widget.roleFilter != null
                  ? "${widget.roleFilter!.displayName}ga murojaatlar"
                  : "Barcha murojaatlar")
              : "Mening murojaatlarim",
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _LC.card,
        actions: [
          if (widget.isAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (value) {},
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'all', child: Text("Barcha")),
                PopupMenuItem(value: 'pending', child: Text("Kutilmoqda")),
                PopupMenuItem(
                    value: 'reviewing', child: Text("Ko'rib chiqilmoqda")),
                PopupMenuItem(value: 'resolved', child: Text("Hal qilingan")),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // 🚻 Admin/mudir uchun yotoqxona turini tanlash — Talabalar va
          // Hodimlar hamda Xonalar bo'limlaridagi kabi, murojaatlar ham
          // "O'g'il bolalar" va "Qiz bolalar" uchun alohida-alohida
          // ko'rsatiladi.
          if (widget.isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: SizedBox(
                height: 46,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedHostel == "boys" ? _LC.purple : _LC.card,
                          foregroundColor: _selectedHostel == "boys"
                              ? Colors.white
                              : _LC.muted,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: _selectedHostel == "boys"
                                    ? Colors.transparent
                                    : _LC.faint),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _selectedHostel = "boys");
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
                              : _LC.card,
                          foregroundColor: _selectedHostel == "girls"
                              ? Colors.white
                              : _LC.muted,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: _selectedHostel == "girls"
                                    ? Colors.transparent
                                    : _LC.faint),
                          ),
                        ),
                        onPressed: () {
                          setState(() => _selectedHostel = "girls");
                        },
                        child: const Text("Qiz bolalar"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 🔎 Admin va mudir uchun talaba ismi bo'yicha qidiruv
          if (widget.isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _LC.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _LC.faint),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Talaba ismi bo'yicha qidirish...",
                    hintStyle: const TextStyle(color: _LC.muted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: _LC.purple, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: _LC.muted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 56, color: _LC.coral),
                        const SizedBox(height: 16),
                        Text("Xatolik: ${snapshot.error}",
                            style: const TextStyle(color: _LC.muted)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _LC.purple,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => setState(() {}),
                          child: const Text("Qayta urunish",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: _LC.purple));
                }

                var complaints = snapshot.data!.docs;

                // 🔎 Talaba ismi bo'yicha mahalliy filtrlash
                if (widget.isAdmin && _searchQuery.isNotEmpty) {
                  complaints = complaints.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final studentName =
                        (data['studentName'] ?? '').toString().toLowerCase();
                    return studentName.contains(_searchQuery);
                  }).toList();
                }

                if (complaints.isEmpty) {
                  final noResultsForSearch =
                      widget.isAdmin && _searchQuery.isNotEmpty;
                  final hostelLabel = _selectedHostel == "boys"
                      ? "O'g'il bolalar"
                      : "Qiz bolalar";
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          noResultsForSearch
                              ? Icons.search_off_rounded
                              : Icons.forum_outlined,
                          size: 72,
                          color: _LC.muted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          noResultsForSearch
                              ? "Hech narsa topilmadi"
                              : "Murojaatlar yo'q",
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _LC.ink),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          noResultsForSearch
                              ? "\"$_searchQuery\" bo'yicha murojaat topilmadi"
                              : (widget.isAdmin
                                  ? "$hostelLabel yotoqxonasida hali hech qanday murojaat yozilmagan"
                                  : "Siz hali murojaat yozmagansiz"),
                          style: const TextStyle(color: _LC.muted),
                          textAlign: TextAlign.center,
                        ),
                        if (!widget.isAdmin && widget.studentId != null) ...[
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MurojaatYozish(
                                    studentId: widget.studentId!,
                                    studentName: widget.studentName ?? "",
                                    hostel: widget.hostel,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text("Murojaat yozish"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _LC.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: complaints.length,
                  itemBuilder: (context, index) {
                    var complaint = ComplaintModel.fromJson(
                            complaints[index].data() as Map<String, dynamic>)
                        .copyWith(id: complaints[index].id);
                    return _buildComplaintCard(
                        context, complaint, widget.isAdmin);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (!widget.isAdmin && widget.studentId != null)
          ? FloatingActionButton.extended(
              backgroundColor: _LC.purple,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text("Murojaat yozish"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MurojaatYozish(
                      studentId: widget.studentId!,
                      studentName: widget.studentName ?? "",
                      hostel: widget.hostel,
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _buildComplaintCard(
      BuildContext context, ComplaintModel complaint, bool isAdmin) {
    final statusColor = _getStatusColor(complaint.status);
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MurojaatTafsilotlari(
                  complaint: complaint,
                  isAdmin: isAdmin,
                  currentUser: widget.currentUser,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _getStatusIcon(complaint.status),
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: _LC.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        complaint.description,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _LC.muted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(complaint.category),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              complaint.category,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getStatusText(complaint.status),
                              style: TextStyle(
                                fontSize: 9.5,
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(complaint.createdAt),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: _LC.muted,
                            ),
                          ),
                        ],
                      ),
                      // Murojaat kimga (va admin/mudirga — kimdan) yuborilgani
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          // Talaba ham, admin/mudir ham murojaat kimga
                          // yuborilganini ko'rsin
                          _tagChip(
                            icon: Icons.forward_to_inbox_rounded,
                            label: "Kimga: ${complaint.targetRole.displayName}",
                            color: _LC.pink,
                          ),
                          // "Kimdan" faqat admin/mudir uchun — talaba
                          // buni o'zi biladi
                          if (isAdmin)
                            _tagChip(
                              icon: Icons.person_outline_rounded,
                              label: complaint.isAnonymous
                                  ? "Kimdan: ${complaint.studentName.isNotEmpty ? complaint.studentName : "Noma'lum"} (anonim so'ragan)"
                                  : "Kimdan: ${complaint.studentName.isNotEmpty ? complaint.studentName : "Noma'lum"}",
                              color: _LC.teal,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: _LC.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tagChip(
      {required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return _LC.orange;
      case ComplaintStatus.reviewing:
        return _LC.purple;
      case ComplaintStatus.resolved:
        return _LC.teal;
      case ComplaintStatus.closed:
        return _LC.muted;
    }
  }

  IconData _getStatusIcon(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return Icons.pending_rounded;
      case ComplaintStatus.reviewing:
        return Icons.visibility_rounded;
      case ComplaintStatus.resolved:
        return Icons.check_circle_rounded;
      case ComplaintStatus.closed:
        return Icons.lock_rounded;
    }
  }

  String _getStatusText(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.pending:
        return "Kutilmoqda";
      case ComplaintStatus.reviewing:
        return "Ko'rib chiqilmoqda";
      case ComplaintStatus.resolved:
        return "Hal qilindi";
      case ComplaintStatus.closed:
        return "Yopilgan";
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Texnik':
        return _LC.coral;
      case 'Ijtimoiy':
        return _LC.orange;
      case 'Moliyaviy':
        return _LC.violet;
      default:
        return _LC.purple;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return "${difference.inDays} kun oldin";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} soat oldin";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minut oldin";
    } else {
      return "Hozirgina";
    }
  }
}
