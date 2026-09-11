import 'package:flutter/material.dart';

import '../models/room_model.dart';
import '../services/api_service.dart';
import 'xona_talabalari_sheet.dart';

// ─────────────────────────────────────────────────────────────
// CREATIVE LIGHT PALETTE
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// XONALAR LIST
// ─────────────────────────────────────────────────────────────

class XonalarList extends StatefulWidget {
  final bool isAdmin;
  final String hostel;
  final bool? canEdit;
  final String hostelType;

  const XonalarList({
    super.key,
    required this.isAdmin,
    this.hostel = 'boys',
    this.canEdit,
    this.hostelType = 'university',
  });

  @override
  State<XonalarList> createState() => _XonalarListState();
}

class _XonalarListState extends State<XonalarList> {
  final ApiService _api = ApiService();

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  RoomStatus? _statusFilter;

  late String _selectedHostel;

  bool _isLoading = true;
  bool _isRefreshing = false;

  String? _error;

  List<RoomModel> _rooms = [];

  bool get _canEdit => widget.canEdit ?? widget.isAdmin;

  String get _hostelType => _normalizeHostelType(widget.hostelType);

  // ───────────────────────────────────────────────────────────
  // HOSTEL TYPE NORMALIZATION
  // ───────────────────────────────────────────────────────────

  String _normalizeHostelType(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'medical':
      case 'med_college':
      case 'med_kollej':
        return 'medical';

      case 'avto_yol':
      case 'avtoyol':
      case 'avto':
        return 'avto_yol';

      case 'navoi_object':
      case 'navoiy_object':
      case 'navoi':
        return 'navoi_object';

      case 'rental':
      case 'ijara':
        return 'rental';

      default:
        return 'university';
    }
  }

  String get _hostelTypeTitle {
    switch (_hostelType) {
      case 'medical':
        return 'Tibbiyot kolleji yotoqxonasi';

      case 'avto_yol':
        return 'Avto yo‘l yotoqxonasi';

      case 'navoi_object':
        return 'Navoiy obyekti';

      case 'rental':
        return 'Ijara uchun ajratilgan';

      default:
        return 'Universitet yotoqxonasi';
    }
  }

  // ───────────────────────────────────────────────────────────
  // INIT
  // ───────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _selectedHostel = widget.hostel.trim().isEmpty
        ? 'boys'
        : widget.hostel.trim().toLowerCase();

    _loadRooms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────
  // LOAD ROOMS FROM LARAVEL API
  // ───────────────────────────────────────────────────────────

  Future<void> _loadRooms({
    bool refresh = false,
  }) async {
    if (!mounted) return;

    setState(() {
      if (refresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }

      _error = null;
    });

    try {
      final rawRooms = await _api.getRooms();

      final rooms = <RoomModel>[];

      for (final item in rawRooms) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);

          try {
            rooms.add(RoomModel.fromJson(map));
          } catch (e) {
            // Ilgari bu xato jimgina yutilardi (catch (_) {}) va
            // shuning uchun ro'yxat bo'sh chiqqanda sababi
            // ko'rinmasdi. Endi konsolda yoziladi.
            debugPrint('Xonani o\'qib bo\'lmadi: $e | $map');
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  // ───────────────────────────────────────────────────────────
  // FILTER ROOMS
  // ───────────────────────────────────────────────────────────

  // Xonadagi talabalar ro'yxatini ochadi.
  //
  // Bu yerda talabalarni biriktirish va chiqarish mumkin. Sig'im
  // tekshiruvi ikki joyda: oynada tugma yashiriladi, backend esa
  // RoomAssignmentController da qayta tekshiradi.
  Future<void> _showRoomStudents(RoomModel room) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => XonaTalabalariSheet(
        roomId: room.id,
        roomNumber: room.roomNumber.toString(),
        capacity: room.capacity,
        hostel: room.hostel,
        canEdit: _canEdit,
      ),
    );

    // Oynadan qaytgach ro'yxatni yangilaymiz вЂ” bandlik o'zgargan
    // bo'lishi mumkin.
    if (mounted) await _loadRooms();
  }

  List<RoomModel> get _filteredRooms {
    return _rooms.where((room) {
      final roomHostel = room.hostel.trim().toLowerCase();

      final normalizedHostel = roomHostel.isEmpty ? 'boys' : roomHostel;

      final roomType = _normalizeHostelType(room.hostelType);

      // Hostel filter
      if (normalizedHostel != _selectedHostel) {
        return false;
      }

      // Hostel type filter
      if (roomType != _hostelType) {
        return false;
      }

      // Status filter
      if (_statusFilter != null && room.status != _statusFilter) {
        return false;
      }

      // Search filter
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.trim().toLowerCase();

        final matches = room.roomNumber.toString().contains(query) ||
            room.floor.toString().contains(query) ||
            room.status.displayName.toLowerCase().contains(query);

        if (!matches) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort(
        (a, b) => a.roomNumber.compareTo(b.roomNumber),
      );
  }

  // ───────────────────────────────────────────────────────────
  // DELETE ROOM
  // ───────────────────────────────────────────────────────────

  Future<void> _deleteRoom(
    RoomModel room,
  ) async {
    try {
      await _api.deleteRoom(room.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${room.roomNumber}-xona muvaffaqiyatli o‘chirildi!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _loadRooms(refresh: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Xatolik yuz berdi: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ───────────────────────────────────────────────────────────
  // CONFIRM DELETE
  // ───────────────────────────────────────────────────────────

  void _confirmDeleteRoom(RoomModel room) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            "Xonani o‘chirish",
          ),
          content: Text(
            "${room.roomNumber}-xonani butunlay o‘chirmoqchimisiz?\n\n"
            "Bu amalni ortga qaytarib bo‘lmaydi.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                "Bekor qilish",
                style: TextStyle(
                  color: _LC.muted,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _LC.coral,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                await _deleteRoom(room);
              },
              child: const Text(
                "O‘chirish",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────
  // UPDATE STATUS
  // ───────────────────────────────────────────────────────────

  Future<void> _updateRoomStatus(
    RoomModel room,
    RoomStatus newStatus,
  ) async {
    try {
      await _api.updateRoom(
        room.id,
        {
          'room_number': room.roomNumber,
          'floor': room.floor,
          'capacity': room.capacity,
          'current_occupants': room.currentOccupants,
          'status': newStatus.name,
          'hostel': room.hostel,
          'hostel_type': room.hostelType,
          'amenities': room.amenities,
          'student_ids': room.studentIds,
          'price_per_month': room.pricePerMonth,
          'notes': room.notes,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Xona holati yangilandi!",
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _loadRooms(refresh: true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Xatolik yuz berdi: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ───────────────────────────────────────────────────────────
  // STATUS MENU
  // ───────────────────────────────────────────────────────────

  void _showStatusEditMenu(RoomModel room) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Xona holatini o‘zgartirish",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              ...RoomStatus.values.map(
                (status) {
                  return ListTile(
                    leading: Icon(
                      _statusIcon(status),
                      color: _getStatusColor(status),
                    ),
                    title: Text(
                      status.displayName,
                    ),
                    trailing: room.status == status
                        ? const Icon(
                            Icons.check,
                            color: Colors.blue,
                          )
                        : null,
                    onTap: () async {
                      Navigator.pop(sheetContext);

                      if (room.status != status) {
                        await _updateRoomStatus(
                          room,
                          status,
                        );
                      }
                    },
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: _LC.coral,
                ),
                title: const Text(
                  "Xonani o‘chirish",
                  style: TextStyle(
                    color: _LC.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteRoom(room);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────
  // ADD ROOM DIALOG
  // ───────────────────────────────────────────────────────────

  void _showAddRoomDialog() {
    final roomNumberController = TextEditingController();

    final floorController = TextEditingController();

    final capacityController = TextEditingController(text: '4');

    final priceController = TextEditingController(text: '250000');

    final formKey = GlobalKey<FormState>();

    bool isSaving = false;

    final facilities = <Map<String, dynamic>>[
      {
        'name': 'Wi-Fi',
        'checked': false,
      },
      {
        'name': 'Konditsioner',
        'checked': false,
      },
      {
        'name': 'Sanuzel',
        'checked': false,
      },
      {
        'name': 'Muzlatgich',
        'checked': false,
      },
      {
        'name': 'Televizor',
        'checked': false,
      },
      {
        'name': 'Krovat',
        'checked': false,
      },
      {
        'name': "To‘shak",
        'checked': false,
      },
      {
        'name': 'Kiyim javoni',
        'checked': false,
      },
      {
        'name': 'Tortma',
        'checked': false,
      },
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 750,
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _LC.purple,
                            _LC.violet,
                          ],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_home_work_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              "Yangi xona qo‘shish",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                              );
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(
                          20,
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: roomNumberController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration(
                                        "Xona raqami",
                                        Icons.meeting_room,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Xona raqamini kiriting';
                                        }

                                        if (int.tryParse(value) == null) {
                                          return 'Son kiriting';
                                        }

                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: floorController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration(
                                        "Qavat",
                                        Icons.layers,
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Qavatni kiriting';
                                        }

                                        if (int.tryParse(value) == null) {
                                          return 'Son kiriting';
                                        }

                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: capacityController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration(
                                        "Sig‘imi",
                                        Icons.people,
                                      ),
                                      validator: (value) {
                                        final number = int.tryParse(
                                          value ?? '',
                                        );

                                        if (number == null || number <= 0) {
                                          return 'To‘g‘ri sig‘im kiriting';
                                        }

                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: priceController,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration(
                                        "Oylik to‘lov",
                                        Icons.payments,
                                      ),
                                      validator: (value) {
                                        if (double.tryParse(value ?? '') ==
                                            null) {
                                          return 'To‘g‘ri summa kiriting';
                                        }

                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Qulayliklar",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _LC.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...facilities.map(
                                (facility) {
                                  final name = facility['name'].toString();

                                  final checked = facility['checked'] as bool;

                                  return CheckboxListTile(
                                    value: checked,
                                    activeColor: _LC.purple,
                                    title: Text(name),
                                    secondary: Icon(
                                      _facilityIcon(
                                        name,
                                      ),
                                      color: _LC.purple,
                                    ),
                                    onChanged: (value) {
                                      setDialogState(
                                        () {
                                          facility['checked'] = value ?? false;
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: _LC.faint,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      Navigator.pop(
                                        dialogContext,
                                      );
                                    },
                              child: const Text(
                                "Bekor qilish",
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _LC.purple,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (!formKey.currentState!.validate()) {
                                        return;
                                      }

                                      final roomNumber = int.parse(
                                        roomNumberController.text.trim(),
                                      );

                                      final floor = int.parse(
                                        floorController.text.trim(),
                                      );

                                      final capacity = int.parse(
                                        capacityController.text.trim(),
                                      );

                                      final price = double.parse(
                                        priceController.text.trim(),
                                      );

                                      final duplicate = _rooms.any(
                                        (room) =>
                                            room.roomNumber == roomNumber &&
                                            room.hostel.toLowerCase() ==
                                                _selectedHostel &&
                                            _normalizeHostelType(
                                                  room.hostelType,
                                                ) ==
                                                _hostelType,
                                      );

                                      if (duplicate) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Bu xona raqami allaqachon mavjud!",
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );

                                        return;
                                      }

                                      final amenities = facilities
                                          .where(
                                            (item) => item['checked'] == true,
                                          )
                                          .map(
                                            (item) => item['name'].toString(),
                                          )
                                          .toList();

                                      setDialogState(() {
                                        isSaving = true;
                                      });

                                      try {
                                        await _api.createRoom(
                                          {
                                            'room_number':
                                                roomNumber.toString(),
                                            'floor': floor,
                                            'capacity': capacity,
                                            'current_occupants': 0,
                                            'status': 'empty',
                                            'hostel': _selectedHostel,
                                            'hostel_type': _hostelType,
                                            'amenities': amenities,
                                            'student_ids': [],
                                            'price_per_month': price,
                                          },
                                        );

                                        if (!context.mounted) {
                                          return;
                                        }

                                        Navigator.pop(
                                          dialogContext,
                                        );

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Yangi xona muvaffaqiyatli qo‘shildi!",
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );

                                        await _loadRooms(
                                          refresh: true,
                                        );
                                      } catch (e) {
                                        if (!context.mounted) {
                                          return;
                                        }

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              "Xatolik: $e",
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );

                                        setDialogState(() {
                                          isSaving = false;
                                        });
                                      }
                                    },
                              child: isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Qo‘shish",
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────
  // INPUT DECORATION
  // ───────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: _LC.purple,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: _LC.purple,
          width: 2,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // FACILITY ICON
  // ───────────────────────────────────────────────────────────

  IconData _facilityIcon(String name) {
    switch (name) {
      case 'Wi-Fi':
        return Icons.wifi_rounded;

      case 'Konditsioner':
        return Icons.ac_unit_rounded;

      case 'Sanuzel':
        return Icons.bathroom_rounded;

      case 'Muzlatgich':
        return Icons.kitchen_rounded;

      case 'Televizor':
        return Icons.tv_rounded;

      case 'Krovat':
        return Icons.bed_rounded;

      case "To‘shak":
        return Icons.king_bed_rounded;

      case 'Kiyim javoni':
        return Icons.checkroom_rounded;

      case 'Tortma':
        return Icons.inventory_2_rounded;

      default:
        return Icons.check_circle_outline;
    }
  }

  // ───────────────────────────────────────────────────────────
  // STATUS COLOR
  // ───────────────────────────────────────────────────────────

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

  IconData _statusIcon(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty:
        return Icons.check_circle_rounded;

      case RoomStatus.occupied:
        return Icons.people_rounded;

      case RoomStatus.renovation:
        return Icons.build_rounded;

      case RoomStatus.paymentPending:
        return Icons.payments_rounded;
    }
  }

  // ───────────────────────────────────────────────────────────
  // ROOM CARD
  // ───────────────────────────────────────────────────────────

  Widget _buildRoomCard(RoomModel room) {
    final available = room.capacity - room.currentOccupants;

    final statusColor = _getStatusColor(room.status);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: _LC.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: _LC.faint,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        // Bosish - talabalar ro'yxati.
        // Uzoq bosish - status o'zgartirish menyusi.
        onTap: () => _showRoomStudents(room),
        onLongPress: _canEdit ? () => _showStatusEditMenu(room) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _LC.purple.withOpacity(.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        room.roomNumber.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _LC.purple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${room.roomNumber}-xona',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _LC.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${room.floor}-qavat',
                          style: const TextStyle(
                            color: _LC.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_canEdit)
                    IconButton(
                      icon: const Icon(
                        Icons.more_vert,
                      ),
                      onPressed: () => _showStatusEditMenu(
                        room,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _statusIcon(room.status),
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      room.status.displayName,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _infoBox(
                      Icons.people,
                      'Bandlik',
                      '${room.currentOccupants}/${room.capacity}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _infoBox(
                      Icons.event_available,
                      'Bo‘sh joy',
                      '$available',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _infoBox(
                Icons.payments_rounded,
                'Oylik to‘lov',
                '${room.pricePerMonth.toStringAsFixed(0)} so‘m',
              ),
              if (room.amenities.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Qulayliklar',
                  style: TextStyle(
                    color: _LC.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: room.amenities
                      .map(
                        (amenity) => Chip(
                          avatar: Icon(
                            _facilityIcon(amenity),
                            size: 15,
                            color: _LC.purple,
                          ),
                          label: Text(
                            amenity,
                            style: const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                          backgroundColor: _LC.faint,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _LC.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _LC.purple,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _LC.muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _LC.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // LOADING
  // ───────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: _LC.purple,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // ERROR
  // ───────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 70,
              color: _LC.coral,
            ),
            const SizedBox(height: 16),
            const Text(
              'Xonalarni yuklab bo‘lmadi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _LC.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Noma‘lum xatolik',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _LC.muted,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadRooms,
              icon: const Icon(Icons.refresh),
              label: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // EMPTY
  // ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _LC.faint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              size: 55,
              color: _LC.purple,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Hozircha xonalar mavjud emas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _LC.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _canEdit
                ? 'Yangi xona qo‘shish tugmasidan foydalaning.'
                : 'Bu bo‘limda hozircha xona topilmadi.',
            style: const TextStyle(
              color: _LC.muted,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // BUILD
  // ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rooms = _filteredRooms;

    return Scaffold(
      backgroundColor: _LC.bg,
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xonalar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              _hostelTypeTitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _LC.purple,
                _LC.violet,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            onPressed: _isRefreshing ? null : () => _loadRooms(refresh: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.refresh,
                  ),
          ),
        ],
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              backgroundColor: _LC.purple,
              foregroundColor: Colors.white,
              onPressed: _showAddRoomDialog,
              icon: const Icon(Icons.add),
              label: const Text(
                'Xona qo‘shish',
              ),
            )
          : null,
      body: Column(
        children: [
          // SEARCH
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              10,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Xona raqami yoki qavat bo‘yicha qidirish...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();

                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // BOYS / GIRLS
          if (_hostelType != 'rental')
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _hostelButton(
                      title: "O‘g‘il bolalar",
                      icon: Icons.male,
                      value: 'boys',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _hostelButton(
                      title: "Qiz bolalar",
                      icon: Icons.female,
                      value: 'girls',
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // STATUS FILTER
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              children: [
                _filterChip(
                  title: 'Barchasi',
                  status: null,
                ),
                const SizedBox(width: 8),
                ...RoomStatus.values.map(
                  (status) => Padding(
                    padding: const EdgeInsets.only(
                      right: 8,
                    ),
                    child: _filterChip(
                      title: status.displayName,
                      status: status,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // COUNT
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${rooms.length} ta xona',
                style: const TextStyle(
                  color: _LC.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // CONTENT
          Expanded(
            child: _isLoading
                ? _buildLoading()
                : _error != null
                    ? _buildError()
                    : rooms.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            onRefresh: () => _loadRooms(
                              refresh: true,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final width = constraints.maxWidth;

                                int columns = 1;

                                if (width >= 1100) {
                                  columns = 3;
                                } else if (width >= 700) {
                                  columns = 2;
                                }

                                return GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    100,
                                  ),
                                  itemCount: rooms.length,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio:
                                        columns == 1 ? 1.45 : 0.95,
                                  ),
                                  itemBuilder: (context, index) {
                                    return _buildRoomCard(
                                      rooms[index],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // HOSTEL BUTTON
  // ───────────────────────────────────────────────────────────

  Widget _hostelButton({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final selected = _selectedHostel == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _selectedHostel = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected ? _LC.purple : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _LC.purple : _LC.faint,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : _LC.purple,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : _LC.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  // FILTER CHIP
  // ───────────────────────────────────────────────────────────

  Widget _filterChip({
    required String title,
    required RoomStatus? status,
  }) {
    final selected = _statusFilter == status;

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      selectedColor: _LC.purple.withOpacity(.18),
      labelStyle: TextStyle(
        color: selected ? _LC.purple : _LC.muted,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
      onSelected: (_) {
        setState(() {
          _statusFilter = status;
        });
      },
    );
  }
}
