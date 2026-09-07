import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/room_model.dart';
import '../../providers/girls_room_provider.dart';
import '../../providers/girls_student_provider.dart';
import '../../services/girl_student_model.dart';
import '../../theme/girls_theme.dart';

// ─── GirlsRoomAssignScreen: tanlangan xonaga talaba (qiz) biriktirish.
// Dizayni "bolalar" (xona_taqsimlash.dart) ekrani bilan bir xil g'oyaga
// asoslangan, lekin Qizlar moduli rang palitrasi (GTheme) va o'z
// provayderlari (GirlsRoomProvider / GirlsStudentProvider) orqali ishlaydi.
class GirlsRoomAssignScreen extends StatefulWidget {
  final RoomModel room;
  const GirlsRoomAssignScreen({super.key, required this.room});

  @override
  State<GirlsRoomAssignScreen> createState() => _GirlsRoomAssignScreenState();
}

class _GirlsRoomAssignScreenState extends State<GirlsRoomAssignScreen> {
  GirlStudentModel? _selectedStudent;
  bool _isAssigning = false;

  @override
  Widget build(BuildContext context) {
    final availableSpaces = widget.room.capacity - widget.room.currentOccupants;

    return Scaffold(
      backgroundColor: GTheme.bgBase,
      appBar: AppBar(
        backgroundColor: GTheme.bgBase,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Xonaga talaba biriktirish",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<GirlStudentModel>>(
          stream: context.read<GirlsStudentProvider>().students,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: GTheme.pink),
              );
            }

            final availableStudents = snapshot.data!
                .where((s) => s.roomId.isEmpty)
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Room info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: GTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "${widget.room.roomNumber}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: GTheme.pink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Xona ${widget.room.roomNumber}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "${widget.room.floor}-qavat",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "Bo'sh joy: $availableSpaces/${widget.room.capacity}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: GTheme.pink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (availableSpaces <= 0)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: GTheme.cardDecoration(),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded,
                            size: 56, color: GTheme.white.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          "Xonada bo'sh joy qolmagan",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  )
                else if (availableStudents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: GTheme.cardDecoration(),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 64, color: GTheme.white.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        const Text(
                          "Biriktirish uchun talabalar yo'q",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Barcha talabalar allaqachon xonalarga biriktirilgan",
                          style: TextStyle(color: GTheme.white.withOpacity(0.5)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Student selection
                  Container(
                    decoration: GTheme.cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Talabani tanlang",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<GirlStudentModel>(
                          initialValue: _selectedStudent,
                          dropdownColor: GTheme.bgCard,
                          decoration: GTheme.inputDecoration(
                            "Talaba",
                            icon: Icons.person_search_rounded,
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: availableStudents.map((student) {
                            return DropdownMenuItem(
                              value: student,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white),
                                  ),
                                  Text(
                                    "${student.faculty} • ${student.group}",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: GTheme.white.withOpacity(0.5)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedStudent = value),
                          validator: (value) =>
                              value == null ? "Talabani tanlang" : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_selectedStudent != null)
                    Container(
                      decoration: GTheme.cardDecoration(
                          color: GTheme.mint.withOpacity(0.08)),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: GTheme.mint.withOpacity(0.18),
                            child: Text(
                              _selectedStudent!.fullName.isNotEmpty
                                  ? _selectedStudent!.fullName[0].toUpperCase()
                                  : "?",
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: GTheme.mint),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Tanlangan talaba",
                                    style: TextStyle(
                                        fontSize: 12, color: GTheme.mint)),
                                Text(
                                  _selectedStudent!.fullName,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                                Text(
                                  _selectedStudent!.phone,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: GTheme.white.withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAssigning ? null : _assignStudent,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: GTheme.pink,
                      ),
                      child: _isAssigning
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_add_alt_1_rounded,
                                    color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  "Biriktirish",
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GTheme.violet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 20, color: GTheme.violet),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Talaba biriktirilgandan so'ng, u xona ma'lumotlarini ko'ra oladi",
                          style: TextStyle(
                              fontSize: 12,
                              color: GTheme.white.withOpacity(0.7)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _assignStudent() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Talabani tanlang"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isAssigning = true);

    try {
      final roomProvider = context.read<GirlsRoomProvider>();
      final studentProvider = context.read<GirlsStudentProvider>();

      // Xonaga talabani qo'shish (studentIds + currentOccupants yangilanadi)
      await roomProvider.assignStudent(widget.room.id, _selectedStudent!.id);

      // Talabaning roomId maydonini yangilash
      await studentProvider.setRoomId(_selectedStudent!.id, widget.room.id);

      if (!mounted) return;
      setState(() => _isAssigning = false);

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Talaba muvaffaqiyatli biriktirildi"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAssigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
      );
    }
  }
}
