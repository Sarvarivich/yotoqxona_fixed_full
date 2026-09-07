import 'package:flutter/material.dart';

import '../models/room_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class XonaTaqsimlash extends StatefulWidget {
  final RoomModel room;

  const XonaTaqsimlash({
    super.key,
    required this.room,
  });

  @override
  State<XonaTaqsimlash> createState() => _XonaTaqsimlashState();
}

class _XonaTaqsimlashState extends State<XonaTaqsimlash> {
  final ApiService _apiService = ApiService();

  List<UserModel> _availableStudents = [];
  UserModel? _selectedStudent;

  bool _isLoading = true;
  bool _isAssigning = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableStudents();
  }

  // ============================================================
  // TALABALARNI YUKLASH
  // ============================================================

  Future<void> _loadAvailableStudents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedStudent = null;
    });

    try {
      // Railway API dan barcha talabalarni olish
      final studentsData = await _apiService.getStudents();

      // Railway API dan xona biriktirishlarini olish
      final assignmentsData =
          await _apiService.getRoomAssignments();

      // Xonaga allaqachon biriktirilgan talabalar ID lari
      final assignedStudentIds = <String>{};

      for (final assignment in assignmentsData) {
        if (assignment is Map) {
          final map = Map<String, dynamic>.from(assignment);

          dynamic studentId =
              map['student_id'] ??
              map['studentId'];

          // Ba'zi backend javoblarida student obyekt sifatida kelishi mumkin
          if (studentId == null && map['student'] is Map) {
            final studentMap =
                Map<String, dynamic>.from(map['student']);

            studentId =
                studentMap['id'] ??
                studentMap['student_id'];
          }

          if (studentId != null) {
            assignedStudentIds.add(studentId.toString());
          }
        }
      }

      final students = <UserModel>[];

      for (final studentData in studentsData) {
        if (studentData is Map) {
          final map =
              Map<String, dynamic>.from(studentData);

          // Faqat talaba rolidagilar
          final role =
              map['role']?.toString().toLowerCase() ?? '';

          if (role.isNotEmpty && role != 'talaba') {
            continue;
          }

          try {
            final student = UserModel.fromJson(map);

            // Faqat hali xonaga biriktirilmagan talabalar
            if (!assignedStudentIds.contains(student.id)) {
              students.add(student);
            }
          } catch (_) {
            // Bitta noto'g'ri student butun sahifani buzmasligi uchun
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _availableStudents = students;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  // ============================================================
  // TALABANI XONAGA BIRIKTIRISH
  // ============================================================

  Future<void> _assignStudent() async {
    if (_selectedStudent == null) {
      _showSnackBar(
        'Talabani tanlang',
        Colors.orange,
      );
      return;
    }

    // Xonada joy borligini tekshirish
    final availableSpaces =
        widget.room.capacity - widget.room.currentOccupants;

    if (availableSpaces <= 0) {
      _showSnackBar(
        'Bu xonada bo‘sh joy qolmagan',
        Colors.red,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isAssigning = true;
    });

    try {
      await _apiService.assignStudentToRoom(
        studentId: _selectedStudent!.id,
        roomId: widget.room.id,
      );

      if (!mounted) return;

      setState(() {
        _isAssigning = false;
      });

      _showSnackBar(
        'Talaba muvaffaqiyatli xonaga biriktirildi',
        Colors.green,
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isAssigning = false;
      });

      _showSnackBar(
        _getErrorMessage(e),
        Colors.red,
      );
    }
  }

  // ============================================================
  // XATOLIK MATNI
  // ============================================================

  String _getErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }

    final text = error.toString();

    if (text.contains('401')) {
      return 'Sessiya tugagan. Qaytadan tizimga kiring.';
    }

    if (text.contains('403')) {
      return 'Bu amalni bajarishga ruxsatingiz yo‘q.';
    }

    if (text.contains('404')) {
      return 'Serverda kerakli ma’lumot topilmadi.';
    }

    if (text.contains('422')) {
      return 'Ma’lumotlarni tekshirib qaytadan urinib ko‘ring.';
    }

    return text.replaceFirst('Exception: ', '');
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message,
    Color color,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final availableSpaces =
        widget.room.capacity - widget.room.currentOccupants;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Xonaga talaba biriktirish',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _loadAvailableStudents,
              child: SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(16),

                child: Column(
                  children: [

                    // ====================================================
                    // XONA MA'LUMOTLARI
                    // ====================================================

                    _buildRoomCard(availableSpaces),

                    const SizedBox(height: 24),

                    // ====================================================
                    // ERROR
                    // ====================================================

                    if (_errorMessage != null)
                      _buildErrorCard(),

                    if (_errorMessage != null)
                      const SizedBox(height: 16),

                    // ====================================================
                    // XONA TO'LIQ
                    // ====================================================

                    if (availableSpaces <= 0)
                      _buildRoomFullCard()

                    // ====================================================
                    // TALABA YO'Q
                    // ====================================================

                    else if (_availableStudents.isEmpty)
                      _buildEmptyStudentsCard()

                    // ====================================================
                    // TALABALAR BOR
                    // ====================================================

                    else
                      _buildStudentSelection(),

                    const SizedBox(height: 16),

                    // ====================================================
                    // INFO
                    // ====================================================

                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // ROOM CARD
  // ============================================================

  Widget _buildRoomCard(int availableSpaces) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade400,
            Colors.purple.shade700,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        borderRadius: BorderRadius.circular(16),
      ),

      child: Row(
        children: [

          // ROOM NUMBER

          Container(
            width: 64,
            height: 64,

            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),

            child: Center(
              child: Text(
                widget.room.roomNumber.toString(),

                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // ROOM INFO

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  'Xona ${widget.room.roomNumber}',

                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${widget.room.floor}-qavat',

                  style: const TextStyle(
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),

                  child: Text(
                    'Bo‘sh joy: $availableSpaces/${widget.room.capacity}',

                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.red.shade50,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(
          color: Colors.red.shade200,
        ),
      ),

      child: Column(
        children: [

          Icon(
            Icons.error_outline,
            size: 40,
            color: Colors.red.shade700,
          ),

          const SizedBox(height: 10),

          Text(
            _errorMessage ?? 'Xatolik yuz berdi',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: Colors.red.shade700,
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _loadAvailableStudents,

            icon: const Icon(Icons.refresh),

            label: const Text('Qayta yuklash'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROOM FULL
  // ============================================================

  Widget _buildRoomFullCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(32),

      decoration: BoxDecoration(
        color: Colors.orange.shade50,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        children: [

          Icon(
            Icons.meeting_room,
            size: 64,
            color: Colors.orange.shade700,
          ),

          const SizedBox(height: 16),

          const Text(
            'Xona to‘liq band',

            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Bu xonaga boshqa talaba biriktirib bo‘lmaydi.',

            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STUDENTS
  // ============================================================

  Widget _buildEmptyStudentsCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(32),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,

        borderRadius: BorderRadius.circular(16),
      ),

      child: Column(
        children: [

          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey.shade600,
          ),

          const SizedBox(height: 16),

          const Text(
            'Biriktirish uchun talabalar yo‘q',

            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Barcha talabalar allaqachon xonalarga biriktirilgan.',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _loadAvailableStudents,

            icon: const Icon(Icons.refresh),

            label: const Text('Qayta yuklash'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENT SELECTION
  // ============================================================

  Widget _buildStudentSelection() {
    return Column(
      children: [

        Card(
          elevation: 4,

          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                const Text(
                  'Talabani tanlang',

                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<UserModel>(
                  initialValue: _selectedStudent,

                  isExpanded: true,

                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),

                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),

                  hint: const Text(
                    'Talabani tanlang',
                  ),

                  items: _availableStudents.map(
                    (student) {
                      return DropdownMenuItem<UserModel>(
                        value: student,

                        child: Text(
                          student.fullName,

                          overflow:
                              TextOverflow.ellipsis,

                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ).toList(),

                  onChanged: (value) {
                    setState(() {
                      _selectedStudent = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ========================================================
        // TANLANGAN TALABA
        // ========================================================

        if (_selectedStudent != null)
          _buildSelectedStudentCard(),

        if (_selectedStudent != null)
          const SizedBox(height: 20),

        // ========================================================
        // BIRIKTIRISH BUTTON
        // ========================================================

        SizedBox(
          width: double.infinity,

          child: ElevatedButton(
            onPressed:
                _isAssigning ? null : _assignStudent,

            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,

              foregroundColor: Colors.white,

              padding:
                  const EdgeInsets.symmetric(
                vertical: 16,
              ),

              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),

            child: _isAssigning
                ? const SizedBox(
                    height: 22,
                    width: 22,

                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )

                : const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [

                      Icon(Icons.person_add),

                      SizedBox(width: 8),

                      Text(
                        'Biriktirish',

                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SELECTED STUDENT
  // ============================================================

  Widget _buildSelectedStudentCard() {
    final student = _selectedStudent!;

    final firstLetter =
        student.fullName.isNotEmpty
            ? student.fullName[0].toUpperCase()
            : '?';

    return Card(
      elevation: 2,

      color: Colors.green.shade50,

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Row(
          children: [

            CircleAvatar(
              radius: 30,

              backgroundColor:
                  Colors.green.shade100,

              child: Text(
                firstLetter,

                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(
                    'Tanlangan talaba',

                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    student.fullName,

                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    student.phoneNumber.isNotEmpty
                        ? student.phoneNumber
                        : 'Telefon raqami mavjud emas',

                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.blue.shade50,

        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        children: [

          Icon(
            Icons.info_outline,
            color: Colors.blue.shade700,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Talaba biriktirilgandan so‘ng xona ma’lumotlari Railway serverida saqlanadi.',

              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}