import 'package:flutter/material.dart';
import 'package:yotoqxona/modules/services/api_service.dart';

// ─── Talabani xonaga biriktirish (Laravel API asosida) ───
// Superadmin / Admin / Mudir (warden) uchun. Ro'yxatdan talaba va
// xonani tanlab, "Biriktirish" tugmasi bosiladi -> POST /room-assignments.
// Pastda joriy faol biriktirishlar ro'yxati ham ko'rsatiladi, har
// birini "Chiqarish" tugmasi bilan bekor qilish mumkin.
class RoomAssignmentApiScreen extends StatefulWidget {
  const RoomAssignmentApiScreen({super.key});

  @override
  State<RoomAssignmentApiScreen> createState() =>
      _RoomAssignmentApiScreenState();
}

class _RoomAssignmentApiScreenState extends State<RoomAssignmentApiScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;

  List<dynamic> _students = [];
  List<dynamic> _rooms = [];
  List<dynamic> _assignments = [];

  String? _selectedStudentId;
  String? _selectedRoomId;
  bool _assigning = false;

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
        _api.getStudents(),
        _api.getRooms(),
        _api.getRoomAssignments(),
      ]);

      if (!mounted) return;
      setState(() {
        _students = results[0];
        _rooms = results[1];
        _assignments = results[2];
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Ma'lumotlarni yuklashda xatolik: $e";
        _loading = false;
      });
    }
  }

  // Xona hali to'lmagan (bo'sh joyi bor) xonalarni ajratib beradi.
  List<dynamic> get _availableRooms {
    return _rooms.where((room) {
      final capacity = _toInt(room['capacity']);
      final occupants = _toInt(room['current_occupants']);
      return occupants < capacity;
    }).toList();
  }

  // Hozircha faol biriktirilmagan talabalar.
  List<dynamic> get _unassignedStudents {
    final assignedIds =
        _assignments.map((a) => a['student_id']?.toString()).toSet();
    return _students
        .where((s) => !assignedIds.contains(s['id']?.toString()))
        .toList();
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _assign() async {
    if (_selectedStudentId == null || _selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Talaba va xonani tanlang."),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _assigning = true);

    try {
      await _api.assignStudentToRoom(
        studentId: _selectedStudentId!,
        roomId: _selectedRoomId!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Talaba xonaga muvaffaqiyatli biriktirildi!"),
            backgroundColor: Colors.green),
      );

      setState(() {
        _selectedStudentId = null;
        _selectedRoomId = null;
      });

      await _loadAll();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  Future<void> _unassign(String assignmentId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tasdiqlang"),
        content: Text("$studentName ni xonadan chiqarmoqchimisiz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Bekor qilish"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Chiqarish", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.unassignRoomStudent(assignmentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Talaba xonadan chiqarildi."),
            backgroundColor: Colors.green),
      );
      await _loadAll();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Talabani xonaga biriktirish"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAll,
              child: const Text("Qayta urinish"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Yangi biriktirish",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Talaba (biriktirilmagan)",
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedStudentId,
                    items: _unassignedStudents.map((s) {
                      return DropdownMenuItem<String>(
                        value: s['id']?.toString(),
                        child: Text("${s['name'] ?? ''} (${s['email'] ?? ''})"),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedStudentId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Xona (bo'sh joyi bor)",
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedRoomId,
                    items: _availableRooms.map((r) {
                      final capacity = r['capacity'] ?? 0;
                      final occ = r['current_occupants'] ?? 0;
                      return DropdownMenuItem<String>(
                        value: r['id']?.toString(),
                        child:
                            Text("${r['room_number']}-xona ($occ/$capacity)"),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedRoomId = v),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _assigning ? null : _assign,
                      icon: _assigning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check),
                      label: Text(_assigning
                          ? "Biriktirilmoqda..."
                          : "Xonaga biriktirish"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Joriy biriktirishlar",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_assignments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text("Hozircha biriktirishlar yo'q")),
            )
          else
            ..._assignments.map((a) {
              final studentName = a['student_name']?.toString() ?? '';
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(studentName),
                  subtitle: Text(
                      "${a['room_number'] ?? ''}-xona • ${a['student_email'] ?? ''}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red),
                    tooltip: "Xonadan chiqarish",
                    onPressed: () => _unassign(a['id'].toString(), studentName),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
