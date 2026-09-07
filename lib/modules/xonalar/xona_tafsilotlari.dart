import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'xona_tahrirlash.dart';
import 'xona_taqsimlash.dart';

class XonaTafsilotlari extends StatefulWidget {
  final RoomModel room;
  final bool isAdmin;
  const XonaTafsilotlari({super.key, required this.room, required this.isAdmin});

  @override
  _XonaTafsilotlariState createState() => _XonaTafsilotlariState();
}

class _XonaTafsilotlariState extends State<XonaTafsilotlari> {
  final ApiService _apiService = ApiService();
  late RoomModel _room;
  List<UserModel> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getRoom(_room.id);
      final roomData = res['data'];
      if (roomData is Map<String, dynamic>) {
        final updatedRoom = RoomModel.fromJson(roomData);
        final activeStudents = roomData['active_students'] ?? roomData['activeStudents'];
        final List<UserModel> loadedStudents = [];

        if (activeStudents is List) {
          for (final s in activeStudents) {
            if (s is Map) {
              loadedStudents.add(UserModel.fromJson(Map<String, dynamic>.from(s)));
            }
          }
        } else {
          // Agar active_students alohida bo'lmasa, getRoomAssignments dan o'qiymiz
          final assignments = await _apiService.getRoomAssignments();
          for (final a in assignments) {
            if (a is Map) {
              final rId = (a['room_id'] ?? a['roomId'] ?? (a['room'] is Map ? a['room']['id'] : null))?.toString();
              if (rId == _room.id && a['student'] is Map) {
                loadedStudents.add(UserModel.fromJson(Map<String, dynamic>.from(a['student'])));
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _room = updatedRoom;
            _students = loadedStudents;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeStudent(UserModel student) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Talabani chiqarish"),
        content: Text("${student.fullName} ni xonadan chiqarmoqchimisiz?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isLoading = true);

              try {
                await _apiService.unassignRoomStudent(student.id);

                await _loadStudents();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Talaba xonadan chiqarildi"),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Xatolik: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Chiqarish"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Xona ${_room.roomNumber}",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            widget.isAdmin ? Colors.purple.shade700 : Colors.blue.shade700,
        actions: [
          if (widget.isAdmin) ...[
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () async {
                final updatedRoom = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => XonaTahrirlash(room: _room),
                  ),
                );
                if (updatedRoom != null) {
                  setState(() {
                    _room = updatedRoom;
                  });
                }
              },
              tooltip: "Tahrirlash",
            ),
            IconButton(
              icon: Icon(Icons.person_add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => XonaTaqsimlash(room: _room),
                  ),
                );
                if (result != null) {
                  _loadStudents();
                }
              },
              tooltip: "Talaba biriktirish",
            ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Room Header Card
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _getStatusGradient(_room.status),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${_room.roomNumber}",
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "${_room.floor}-qavat",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getStatusText(_room.status),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(_room.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Room Details Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Xona ma'lumotlari",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          _detailRow(
                            Icons.people,
                            "Sig'imi",
                            "${_room.capacity} kishi",
                            Colors.blue,
                          ),
                          _detailRow(
                            Icons.person,
                            "Hozirgi bandlik",
                            "${_room.currentOccupants}/${_room.capacity}",
                            _room.currentOccupants == _room.capacity
                                ? Colors.red
                                : Colors.green,
                          ),
                          _detailRow(
                            Icons.attach_money,
                            "Oylik to'lov",
                            "${_room.pricePerMonth.toStringAsFixed(0)} so'm",
                            Colors.orange,
                          ),
                          _detailRow(
                            Icons.checklist,
                            "Qulayliklar",
                            _room.amenities.join(', '),
                            Colors.purple,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Students List Card
                  if (_students.isNotEmpty) ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Yashovchi talabalar",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  "${_students.length} ta",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            ..._students.map((student) => Dismissible(
                                  key: Key(student.id),
                                  direction: widget.isAdmin
                                      ? DismissDirection.endToStart
                                      : DismissDirection.none,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.only(right: 20),
                                    color: Colors.red,
                                    child:
                                        Icon(Icons.delete, color: Colors.white),
                                  ),
                                  onDismissed: (direction) =>
                                      _removeStudent(student),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: Text(
                                        student.fullName.isNotEmpty
                                            ? student.fullName[0].toUpperCase()
                                            : "?",
                                      ),
                                    ),
                                    title: Text(
                                      student.fullName,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Text(
                                      student.studentId ?? "ID mavjud emas",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    trailing: widget.isAdmin
                                        ? IconButton(
                                            icon: Icon(Icons.exit_to_app,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _removeStudent(student),
                                          )
                                        : null,
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Bu xonada hali talabalar yo'q",
                              style: TextStyle(color: Colors.grey),
                            ),
                            if (widget.isAdmin) ...[
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          XonaTaqsimlash(room: _room),
                                    ),
                                  );
                                  if (result != null) {
                                    _loadStudents();
                                  }
                                },
                                icon: Icon(Icons.person_add),
                                label: Text("Talaba biriktirish"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty:
        return Colors.green;
      case RoomStatus.occupied:
        return Colors.blue;
      case RoomStatus.paymentPending:
        return Colors.orange;
      case RoomStatus.renovation:
        return Colors.red;
    }
  }

  List<Color> _getStatusGradient(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty:
        return [Colors.green.shade400, Colors.green.shade700];
      case RoomStatus.occupied:
        return [Colors.blue.shade400, Colors.blue.shade700];
      case RoomStatus.paymentPending:
        return [Colors.orange.shade400, Colors.orange.shade700];
      case RoomStatus.renovation:
        return [Colors.red.shade400, Colors.red.shade700];
    }
  }

  String _getStatusText(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty:
        return "Bo'sh";
      case RoomStatus.occupied:
        return "Band";
      case RoomStatus.paymentPending:
        return "To'lov kutilmoqda";
      case RoomStatus.renovation:
        return "Ta'mirlashda";
    }
  }
}
