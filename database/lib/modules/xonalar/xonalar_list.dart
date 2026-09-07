import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart'; // Model joylashgan to'g'ri import yo'lini tekshiring
import 'package:yotoqxona/roles/room_assignment_screen.dart'; // RoomDetailsScreen importi

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

class XonalarList extends StatefulWidget {
  final bool isAdmin;
  final String hostel;

  const XonalarList({
    super.key,
    required this.isAdmin,
    this.hostel = 'boys',
  });

  @override
  State<XonalarList> createState() => _XonalarListState();
}

class _XonalarListState extends State<XonalarList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  RoomStatus? _statusFilter;
  late String _selectedHostel;

  @override
  void initState() {
    super.initState();
    // ✅ Talabalar va Hodimlar bo'limidagi kabi, ekran ochilganda
    // admin/mudirning o'z yotoqxonasi tanlangan bo'lib boshlanadi,
    // so'ngra u "O'g'il bolalar" / "Qiz bolalar" tugmalari orqali
    // ikkalasi orasida erkin almashtirishi mumkin.
    _selectedHostel =
        (widget.hostel.trim().isEmpty ? 'boys' : widget.hostel.trim())
            .toLowerCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🔎 Qidiruv matniga mos keladigan xonalarni filtrlash
  bool _matchesSearch(RoomModel room) {
    if (_searchQuery.trim().isEmpty) return true;
    final query = _searchQuery.trim().toLowerCase();
    final roomNumberStr = room.roomNumber.toString();
    final floorStr = room.floor.toString();
    final statusStr = room.status.displayName.toLowerCase();
    return roomNumberStr.contains(query) ||
        floorStr.contains(query) ||
        statusStr.contains(query);
  }

  // 🗑️ Xonani o'chirishni tasdiqlash oynasi
  void _confirmDeleteRoom(
      BuildContext context, String roomDocId, int roomNumber) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text("Xonani o'chirish"),
          content: Text(
              "$roomNumber-xonani butunlay o'chirmoqchimisiz? Bu amalni ortga qaytarib bo'lmaydi."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Bekor qilish", style: TextStyle(color: _LC.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _LC.coral,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteRoom(context, roomDocId, roomNumber);
              },
              child: const Text("O'chirish",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // 🗑️ Xonani Firebase'dan o'chirish
  Future<void> _deleteRoom(
      BuildContext context, String roomDocId, int roomNumber) async {
    try {
      await FirebaseFirestore.instance
          .collection('xonalar')
          .doc(roomDocId)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("$roomNumber-xona muvaffaqiyatli o'chirildi!")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xatolik yuz berdi: $e")),
        );
      }
    }
  }

  // 🛠️ Xona holatini Firebase'da yangilash
  void _updateRoomStatus(
      BuildContext context, String roomDocId, RoomStatus newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('xonalar')
          .doc(roomDocId)
          .update({
        'status': newStatus.name,
        'updatedAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Xona holati yangilandi!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik yuz berdi: $e")),
      );
    }
  }

  // 🛠️ Admin uchun xona holatini o'zgartirish BottomSheet menyusi
  void _showStatusEditMenu(BuildContext context, String roomDocId,
      RoomStatus currentStatus, int roomNumber) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Xona holatini o'zgartirish",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ...RoomStatus.values.map((status) {
                return ListTile(
                  leading: Icon(
                    status == RoomStatus.empty
                        ? Icons.check_circle
                        : status == RoomStatus.occupied
                            ? Icons.block
                            : status == RoomStatus.renovation
                                ? Icons.build
                                : Icons.payment,
                    color: _getStatusColorByEnum(status),
                  ),
                  title: Text(status.displayName),
                  trailing: currentStatus == status
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    _updateRoomStatus(context, roomDocId, status);
                    Navigator.pop(context);
                  },
                );
              }),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.delete_forever_rounded, color: _LC.coral),
                title: const Text(
                  "Xonani o'chirish",
                  style:
                      TextStyle(color: _LC.coral, fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteRoom(context, roomDocId, roomNumber);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColorByEnum(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty:
        return _LC.teal;
      case RoomStatus.occupied:
        return _LC.purple;
      case RoomStatus.renovation:
        return _LC.coral;
      case RoomStatus.paymentPending:
        return _LC.orange;
    }
  }

  // 🌟 ADMIN UCHUN QULAYLIKLAR BILAN XONA QO'SHISH DIALOGI
  // 🎨 Qulaylik nomiga mos ikonka
  IconData _facilityIcon(String name) {
    switch (name) {
      case 'Wi-Fi':
        return Icons.wifi_rounded;
      case 'Konditsioner':
        return Icons.ac_unit_rounded;
      case 'Sanuzel':
        return Icons.bathtub_rounded;
      case 'Muzlatgich':
        return Icons.kitchen_rounded;
      case 'Televizor':
        return Icons.tv_rounded;
      case 'Krovat':
        return Icons.bed_rounded;
      case 'To\'shak':
        return Icons.king_bed_rounded;
      case 'Kiyim javoni':
        return Icons.checkroom_rounded;
      case 'Tortma':
        return Icons.inventory_2_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  void _showAddRoomDialog(BuildContext context) {
    final TextEditingController roomNumberController = TextEditingController();
    final TextEditingController floorController = TextEditingController();
    final TextEditingController capacityController =
        TextEditingController(text: "4");
    final TextEditingController priceController =
        TextEditingController(text: "250000"); // Standart oylik narx
    final formKey = GlobalKey<FormState>();

    // ✨ Yangilangan xona qulayliklari ro'yxati
    final List<Map<String, dynamic>> availableFacilities = [
      {'name': 'Wi-Fi', 'isChecked': false},
      {'name': 'Konditsioner', 'isChecked': false},
      {'name': 'Sanuzel', 'isChecked': false},
      {'name': 'Muzlatgich', 'isChecked': false},
      {'name': 'Televizor', 'isChecked': false},
      {'name': 'Krovat', 'isChecked': false},
      {'name': 'To\'shak', 'isChecked': false},
      {'name': 'Kiyim javoni', 'isChecked': false},
      {'name': 'Tortma', 'isChecked': false},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;
            final dialogWidth = screenWidth < 560 ? screenWidth * 0.94 : 560.0;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                child: Material(
                  borderRadius: BorderRadius.circular(24),
                  color: _LC.card,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── Gradient header ───
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_LC.purple, _LC.violet],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.add_home_work_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                "Yangi xona qo'shish",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(dialogContext),
                            ),
                          ],
                        ),
                      ),
                      // ─── Scrollable form body ───
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Xona raqami + Qavat — yonma-yon
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: roomNumberController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Xona raqami",
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          prefixIcon:
                                              const Icon(Icons.meeting_room),
                                        ),
                                        validator: (value) => (value == null ||
                                                value.trim().isEmpty)
                                            ? "Kiriting"
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: floorController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Qavat",
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          prefixIcon: const Icon(Icons.layers),
                                        ),
                                        validator: (value) => (value == null ||
                                                value.trim().isEmpty)
                                            ? "Kiriting"
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Sig'im + Narx — yonma-yon
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: capacityController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Sig'imi",
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          prefixIcon: const Icon(Icons.group),
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return "Kiriting";
                                          }
                                          if (int.tryParse(value) == null) {
                                            return "Son kiriting";
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: priceController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Oylik to'lov (so'm)",
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          prefixIcon:
                                              const Icon(Icons.payments),
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return "Kiriting";
                                          }
                                          if (double.tryParse(value) == null) {
                                            return "Raqam kiriting";
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),

                                // 📶 QULAYLIKLAR QISMI — 2 ustunli chip grid
                                Text(
                                  "Xona qulayliklari",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: _LC.ink),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: availableFacilities.map((facility) {
                                    final bool selected =
                                        facility['isChecked'] as bool? ?? false;
                                    return GestureDetector(
                                      onTap: () {
                                        setDialogState(() {
                                          facility['isChecked'] = !selected;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? _LC.purple.withOpacity(0.12)
                                              : _LC.faint,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selected
                                                ? _LC.purple
                                                : Colors.transparent,
                                            width: 1.4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _facilityIcon(
                                                  facility['name'] as String),
                                              size: 17,
                                              color: selected
                                                  ? _LC.purple
                                                  : _LC.muted,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              facility['name'] as String,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: selected
                                                    ? _LC.purple
                                                    : _LC.ink,
                                              ),
                                            ),
                                            if (selected) ...[
                                              const SizedBox(width: 6),
                                              Icon(Icons.check_circle_rounded,
                                                  size: 15, color: _LC.purple),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // ─── Actions ───
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                        decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: _LC.faint, width: 1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: _LC.faint),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text("Bekor qilish",
                                    style: TextStyle(
                                        color: _LC.ink,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;

                                  final int roomNum = int.parse(
                                      roomNumberController.text.trim());
                                  final int floorNum =
                                      int.parse(floorController.text.trim());
                                  final int cap =
                                      int.parse(capacityController.text.trim());
                                  final double price =
                                      double.parse(priceController.text.trim());

                                  // Tanlangan barcha qulayliklarni yig'ib olamiz
                                  final List<String> selectedAmenities =
                                      availableFacilities
                                          .where((f) => f['isChecked'] == true)
                                          .map((f) => f['name'] as String)
                                          .toList();

                                  try {
                                    // Takroriy xona raqamini tekshirish —
                                    // FAQAT tanlangan yotoqxona ("O'g'il
                                    // bolalar" / "Qiz bolalar") doirasida.
                                    // Avval bu tekshiruv butun 'xonalar'
                                    // kolleksiyasi bo'yicha (hostel'dan
                                    // qat'i nazar) olib borilardi — shu
                                    // sabab o'g'il bolalar tomonida 101-xona
                                    // mavjud bo'lsa, qizlar tomonida ham
                                    // xuddi shu raqamli xona qo'shib
                                    // bo'lmas edi. "hostel" maydoni yo'q/
                                    // bo'sh eski hujjatlar ekrandagi kabi
                                    // "boys" deb hisoblanadi.
                                    final checkRoom = await FirebaseFirestore
                                        .instance
                                        .collection('xonalar')
                                        .where('roomNumber', isEqualTo: roomNum)
                                        .get();

                                    final duplicateInSameHostel =
                                        checkRoom.docs.any((doc) {
                                      final data =
                                          doc.data();
                                      final docHostel = (data['hostel'] ?? '')
                                          .toString()
                                          .trim()
                                          .toLowerCase();
                                      final normalized = docHostel.isEmpty
                                          ? 'boys'
                                          : docHostel;
                                      return normalized == _selectedHostel;
                                    });

                                    if (duplicateInSameHostel) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Bu xona raqami allaqachon mavjud!"),
                                            backgroundColor: Colors.orange),
                                      );
                                      return;
                                    }

                                    // Firestore uchun yangi unikal ID yaratish
                                    final docRef = FirebaseFirestore.instance
                                        .collection('xonalar')
                                        .doc();

                                    // Yangi modelimizga mos obyekt tuzish
                                    final newRoom = RoomModel(
                                      id: docRef.id,
                                      roomNumber: roomNum,
                                      floor: floorNum,
                                      capacity: cap,
                                      currentOccupants: 0,
                                      status: RoomStatus.empty,
                                      // ⚠️ widget.hostel emas, _selectedHostel —
                                      // xona hozir ekranda qaysi bo'lim
                                      // ("O'g'il bolalar" / "Qiz bolalar")
                                      // tanlangan bo'lsa, o'sha bo'limga
                                      // qo'shiladi.
                                      hostel: _selectedHostel,
                                      amenities: selectedAmenities,
                                      studentIds: [],
                                      pricePerMonth: price,
                                      createdAt: DateTime.now(),
                                    );

                                    // Firebase'ga saqlash (toJson ichida amenities va facilities qo'shaloq yozilgan)
                                    await docRef.set(newRoom.toJson());

                                    if (context.mounted) {
                                      Navigator.pop(dialogContext);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                "Yangi xona barcha qulayliklari bilan qo'shildi!"),
                                            backgroundColor: Colors.green),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text("Xatolik: $e"),
                                          backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _LC.purple,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text("Qo'shish",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.isAdmin ? "Xonalar boshqaruvi" : "Xonalar ro'yxati",
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_LC.purple, _LC.violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(122),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // 🚻 Yotoqxona turini tanlash — Talabalar va Hodimlar
                // bo'limidagi kabi, xonalar ham "O'g'il bolalar" va
                // "Qiz bolalar" uchun alohida-alohida ko'rsatiladi.
                SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _selectedHostel == "boys"
                                ? Colors.white
                                : Colors.white.withOpacity(0.16),
                            foregroundColor: _selectedHostel == "boys"
                                ? _LC.purple
                                : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                                ? Colors.white
                                : Colors.white.withOpacity(0.16),
                            foregroundColor: _selectedHostel == "girls"
                                ? _LC.purple
                                : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
                const SizedBox(height: 10),
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText:
                          "Xona raqami, qavat yoki holat bo'yicha qidirish...",
                      hintStyle:
                          const TextStyle(color: _LC.muted, fontSize: 13.5),
                      prefixIcon:
                          const Icon(Icons.search_rounded, color: _LC.purple),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: _LC.muted, size: 20),
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
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _StatusFilterChip(
                        label: 'Barchasi',
                        selected: _statusFilter == null,
                        onTap: () => setState(() => _statusFilter = null),
                      ),
                      for (final s in RoomStatus.values)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _StatusFilterChip(
                            label: s.displayName,
                            selected: _statusFilter == s,
                            onTap: () => setState(() => _statusFilter = s),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // ➕ Floating Action Button
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showAddRoomDialog(context),
              backgroundColor: _LC.purple,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text("Xona qo'shish",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        // ⚠️ widget.hostel emas, _selectedHostel — shu orqali "O'g'il
        // bolalar" va "Qiz bolalar" tugmalari xonalar ro'yxatini ham
        // xuddi Talabalar va Hodimlar bo'limidagi kabi alohida-alohida
        // filtrlaydi.
        stream: FirebaseFirestore.instance
            .collection('xonalar')
            .orderBy('roomNumber')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Xatolik yuz berdi: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _LC.purple));
          }

          // 🚻 Kolleksiyaning barcha hujjatlarini olib, "hostel" maydoni
          // bo'yicha mijoz tomonida filtrlaymiz. "hostel" maydoni yo'q
          // yoki bo'sh bo'lgan eski hujjatlar "boys" ga tegishli deb
          // hisoblanadi — aks holda ular hech qaysi bo'limda ko'rinmay
          // "yo'qolib" qolar edi.
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final hostel =
                (data['hostel'] ?? '').toString().trim().toLowerCase();
            final normalizedHostel = hostel.isEmpty ? 'boys' : hostel;
            return normalizedHostel == _selectedHostel;
          }).toList();

          // 🔎 Har bir hujjatni RoomModel'ga o'girib, (room, docId) juftliklarini yig'amiz
          final allRooms = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['id'] == null || (data['id'] as String).isEmpty) {
              data['id'] = doc.id;
            }
            return MapEntry(doc.id, RoomModel.fromJson(data));
          }).toList();

          // Qidiruv so'roviga va tanlangan holat filtriga mos xonalarni
          // filtrlaymiz
          final filteredRooms = allRooms.where((entry) {
            if (!_matchesSearch(entry.value)) return false;
            if (_statusFilter != null && entry.value.status != _statusFilter) {
              return false;
            }
            return true;
          }).toList();

          if (docs.isEmpty) {
            final hostelLabel =
                _selectedHostel == "boys" ? "O'g'il bolalar" : "Qiz bolalar";
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.apartment_rounded,
                      size: 56, color: _LC.muted),
                  const SizedBox(height: 12),
                  Text("$hostelLabel yotoqxonasida hozircha xona yo'q.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: _LC.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          if (filteredRooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 56, color: _LC.muted),
                  const SizedBox(height: 12),
                  const Text("Qidiruvga mos xona topilmadi.",
                      style: TextStyle(
                          color: _LC.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount;
              if (width >= 1100) {
                crossAxisCount = 4;
              } else if (width >= 800) {
                crossAxisCount = 3;
              } else if (width >= 520) {
                crossAxisCount = 2;
              } else {
                crossAxisCount = 2;
              }

              // ✅ Oldin balandlik "childAspectRatio" orqali kenglikka nisbatan
              // hisoblanardi — oyna/ekran kattalashtirilsa yoki
              // kichiklashtirilsa, kartaning balandligi ham o'zgarib,
              // ichidagi icon+matnlar sig'may "BOTTOM OVERFLOWED" xatosini
              // berardi. Endi balandlik ekran kengligidan mustaqil, doimiy
              // piksel (mainAxisExtent) qilib belgilangan — kontent uchun
              // har doim yetarli joy bo'ladi va resize paytida xatolik
              // chiqmaydi.
              const double cardHeight = 250;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1300),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: cardHeight,
                    ),
                    itemCount: filteredRooms.length,
                    itemBuilder: (context, index) {
                      final docId = filteredRooms[index].key;
                      final room = filteredRooms[index].value;

                      return _buildRoomCard(
                          context, room, widget.isAdmin, docId);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRoomCard(
      BuildContext context, RoomModel room, bool isAdmin, String docId) {
    // Model getterlari yoki o'zgaruvchilari orqali xavfsiz hisoblash
    final int currentOccupants = room.studentIds.isNotEmpty
        ? room.studentIds.length
        : room.currentOccupants;

    final int capacity = room.capacity;
    final bool isRoomFull = currentOccupants >= capacity && capacity > 0;
    final bool isRoomClosedByAdmin = room.status == RoomStatus.occupied;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: _LC.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _LC.faint),
              boxShadow: [
                BoxShadow(
                  color: _LC.purple.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onLongPress: isAdmin
                    ? () => _showStatusEditMenu(
                        context, docId, room.status, room.roomNumber)
                    : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoomDetailsScreen(
                        roomDocId: docId,
                        room: room,
                        hostel: room.hostel,
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isRoomFull
                              ? [_LC.coral, const Color(0xFFC0392B)]
                              : _getStatusGradient(room.status),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isRoomFull
                                    ? _LC.coral
                                    : _getStatusColor(room.status))
                                .withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "${room.roomNumber}",
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "${room.floor}-qavat",
                      style: const TextStyle(
                          fontSize: 12,
                          color: _LC.muted,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _LC.faint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "$currentOccupants/$capacity kishi",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _LC.ink),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(room.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isRoomFull ? "To'lgan" : room.status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _getStatusColor(room.status),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isRoomFull)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _LC.coral.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "Xona to'lgan",
                          style: TextStyle(
                              color: _LC.coral.withOpacity(0.9),
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
                        ),
                      )
                    else if (isRoomClosedByAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _LC.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Xona yopilgan",
                          style: TextStyle(
                              color: _LC.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
                        ),
                      )
                    else if (isAdmin)
                      IconButton(
                        icon: const Icon(Icons.person_add_rounded,
                            size: 20, color: _LC.teal),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RoomDetailsScreen(
                                roomDocId: docId,
                                room: room,
                                hostel: room.hostel,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 🗑️ Admin uchun o'chirish tugmasi (o'ng yuqori burchak)
        if (isAdmin)
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () =>
                    _confirmDeleteRoom(context, docId, room.roomNumber),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _LC.coral.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: _LC.coral),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty:
        return _LC.teal;
      case RoomStatus.occupied:
        return _LC.purple;
      case RoomStatus.renovation:
        return _LC.coral;
      case RoomStatus.paymentPending:
        return _LC.orange;
    }
  }

  List<Color> _getStatusGradient(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty:
        return [_LC.teal, const Color(0xFF00A39E)];
      case RoomStatus.occupied:
        return [_LC.purple, _LC.violet];
      case RoomStatus.renovation:
        return [_LC.coral, const Color(0xFFC0392B)];
      case RoomStatus.paymentPending:
        return [_LC.orange, const Color(0xFFE2A93B)];
    }
  }
}

// ✅ "Xonalar" ro'yxatini holat bo'yicha filtrlash uchun chip tugma
// (qizlar bo'limidagi _FilterChip bilan bir xil mantiq/ko'rinish).
class _StatusFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_LC.pink, _LC.purple])
              : null,
          color: selected ? null : _LC.faint,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _LC.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
