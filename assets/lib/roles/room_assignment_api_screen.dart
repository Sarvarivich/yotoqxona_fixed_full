import 'package:flutter/material.dart';
import '../modules/services/api_service.dart';

// ─── Xonaga biriktirish (Laravel API) ─────────────────────────────
// Bu ekran Laravel backend (yotoqxona_backend) bilan ishlaydi:
//   GET  /api/rooms              — barcha xonalar
//   GET  /api/students           — barcha talabalar (superadmin/admin/
//                                   warden ko'radi)
//   GET  /api/room-assignments   — hozirgi faol biriktirishlar
//   POST /api/room-assignments   — talabani xonaga biriktirish
//   DELETE /api/room-assignments/{id} — talabani xonadan chiqarish
//
// Faqat superadmin/admin/warden kira oladi (routes/api.php'da shunday
// cheklangan — backend 403 qaytaradi, agar boshqa rol urinsa).

class _C {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFa29bfe);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFfd79a8);
  static const orange = Color(0xFFfdcb6e);
  static const white = Colors.white;
  static const muted = Color(0x66FFFFFF);
  static const faint = Color(0x0FFFFFFF);
}

class RoomAssignmentApiScreen extends StatefulWidget {
  const RoomAssignmentApiScreen({super.key});

  @override
  State<RoomAssignmentApiScreen> createState() =>
      _RoomAssignmentApiScreenState();
}

class _RoomAssignmentApiScreenState extends State<RoomAssignmentApiScreen> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _assignments = [];

  // studentId -> assignment map (faqat 'active' bo'lganlar)
  Map<String, Map<String, dynamic>> get _assignmentByStudent {
    final map = <String, Map<String, dynamic>>{};
    for (final a in _assignments) {
      final sid = a['student_id']?.toString();
      if (sid != null) map[sid] = a;
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.get('rooms'),
        _api.get('students'),
        _api.get('room-assignments'),
      ]);

      final roomsData = results[0]['data'];
      final studentsData = results[1]['data'];
      final assignmentsData = results[2]['data'];

      setState(() {
        _rooms = roomsData is List
            ? roomsData.map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _students = studentsData is List
            ? studentsData.map((e) => Map<String, dynamic>.from(e)).toList()
            : [];
        _assignments = assignmentsData is List
            ? assignmentsData
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ma\'lumotlarni yuklashda xatolik: $e';
        _loading = false;
      });
    }
  }

  Future<void> _assignStudent(String studentId, String roomId) async {
    try {
      await _api.post('room-assignments', body: {
        'student_id': studentId,
        'room_id': roomId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Talaba xonaga muvaffaqiyatli biriktirildi"),
          backgroundColor: Colors.green,
        ),
      );
      await _loadAll();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _unassign(String assignmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bgCard,
        title: const Text("Talabani xonadan chiqarish",
            style: TextStyle(color: _C.white)),
        content: const Text(
          "Haqiqatan ham bu talabani xonadan chiqarmoqchimisiz?",
          style: TextStyle(color: _C.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Bekor qilish"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ha, chiqarish",
                style: TextStyle(color: _C.pink)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.delete('room-assignments/$assignmentId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Talaba xonadan chiqarildi"),
          backgroundColor: Colors.green,
        ),
      );
      await _loadAll();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openAssignDialog(Map<String, dynamic> student) {
    final availableRooms = _rooms.where((r) {
      final capacity = (r['capacity'] as num?)?.toInt() ?? 0;
      final occupants = (r['current_occupants'] as num?)?.toInt() ?? 0;
      return occupants < capacity;
    }).toList();

    if (availableRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bo'sh xona topilmadi"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _C.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${student['name'] ?? ''} — xona tanlang",
                style: const TextStyle(
                  color: _C.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: availableRooms.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: _C.faint, height: 1),
                  itemBuilder: (_, i) {
                    final r = availableRooms[i];
                    final capacity = (r['capacity'] as num?)?.toInt() ?? 0;
                    final occupants =
                        (r['current_occupants'] as num?)?.toInt() ?? 0;
                    return ListTile(
                      leading: const Icon(Icons.meeting_room_rounded,
                          color: _C.violet),
                      title: Text(
                        "Xona ${r['room_number'] ?? ''}",
                        style: const TextStyle(color: _C.white),
                      ),
                      subtitle: Text(
                        "$occupants / $capacity band",
                        style: const TextStyle(color: _C.muted),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _assignStudent(
                          student['id'].toString(),
                          r['id'].toString(),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bgBase,
      appBar: AppBar(
        backgroundColor: _C.bgBase,
        elevation: 0,
        title: const Text(
          "Talabani xonaga biriktirish",
          style: TextStyle(color: _C.white, fontWeight: FontWeight.w800),
        ),
        iconTheme: const IconThemeData(color: _C.white),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded, color: _C.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _C.violet))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style: const TextStyle(color: _C.pink),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadAll,
                          child: const Text("Qayta urinish"),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _SectionTitle(
                          "Talabalar (${_students.length})", _C.teal),
                      const SizedBox(height: 8),
                      ..._students.map((s) {
                        final assignment =
                            _assignmentByStudent[s['id'].toString()];
                        final hasRoom = assignment != null;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _C.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _C.faint),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    _C.purple.withOpacity(0.18),
                                child: Text(
                                  (s['name']?.toString().isNotEmpty == true)
                                      ? s['name'][0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: _C.violet,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s['name']?.toString() ?? '',
                                      style: const TextStyle(
                                          color: _C.white,
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      hasRoom
                                          ? "Xona: ${assignment['room_number'] ?? '—'}"
                                          : s['email']?.toString() ?? '',
                                      style: TextStyle(
                                          color: hasRoom
                                              ? _C.mint
                                              : _C.muted,
                                          fontSize: 12.5),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasRoom)
                                TextButton(
                                  onPressed: () => _unassign(
                                      assignment['id'].toString()),
                                  child: const Text("Chiqarish",
                                      style: TextStyle(color: _C.pink)),
                                )
                              else
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _C.purple,
                                  ),
                                  onPressed: () => _openAssignDialog(s),
                                  child: const Text("Biriktirish"),
                                ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      _SectionTitle("Xonalar (${_rooms.length})", _C.orange),
                      const SizedBox(height: 8),
                      ..._rooms.map((r) {
                        final capacity =
                            (r['capacity'] as num?)?.toInt() ?? 0;
                        final occupants =
                            (r['current_occupants'] as num?)?.toInt() ?? 0;
                        final full = capacity > 0 && occupants >= capacity;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _C.bgCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _C.faint),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.meeting_room_rounded,
                                  color: full ? _C.pink : _C.mint),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Xona ${r['room_number'] ?? ''}",
                                  style: const TextStyle(
                                      color: _C.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                "$occupants / $capacity",
                                style: TextStyle(
                                  color: full ? _C.pink : _C.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: _C.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
