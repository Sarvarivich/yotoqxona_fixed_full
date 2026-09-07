import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/girls_student_provider.dart';
import '../../services/girl_student_model.dart';
import '../../theme/girls_theme.dart';
import 'add_girl_student_screen.dart';
import 'edit_girl_student_screen.dart';
import 'girl_student_profile_screen.dart';

// ─── GirlsStudentsScreen: Qizlar yotoqxonasi talabalari ro'yxati.
// Qidiruv, qo'shish, tahrirlash, o'chirish va profilga o'tish.
class GirlsStudentsScreen extends StatefulWidget {
  const GirlsStudentsScreen({super.key});

  @override
  State<GirlsStudentsScreen> createState() => _GirlsStudentsScreenState();
}

class _GirlsStudentsScreenState extends State<GirlsStudentsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GirlsStudentProvider>();

    return Scaffold(
      backgroundColor: GTheme.bgBase,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GTheme.pink,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text("Talaba qo'shish",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddGirlStudentScreen()),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: GTheme.inputDecoration(
                  "Ism, guruh yoki telefon bo'yicha qidirish",
                  icon: Icons.search_rounded,
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<GirlStudentModel>>(
                stream: provider.students,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: GTheme.pink));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Xatolik: ${snapshot.error}',
                          style: const TextStyle(color: GTheme.soft)),
                    );
                  }
                  var students = snapshot.data ?? [];
                  if (_query.isNotEmpty) {
                    students = students.where((s) {
                      return s.fullName.toLowerCase().contains(_query) ||
                          s.group.toLowerCase().contains(_query) ||
                          s.phone.toLowerCase().contains(_query);
                    }).toList();
                  }

                  if (students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_2_outlined,
                              size: 56, color: GTheme.white.withOpacity(0.2)),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? 'Hozircha talabalar yoq'
                                : 'Hech narsa topilmadi',
                            style: TextStyle(color: GTheme.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final s = students[index];
                      return _StudentTile(
                        student: s,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GirlStudentProfileScreen(student: s),
                          ),
                        ),
                        onEdit: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditGirlStudentScreen(student: s),
                          ),
                        ),
                        onDelete: () => _confirmDelete(context, provider, s),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, GirlsStudentProvider provider, GirlStudentModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GTheme.bgCard,
        title: const Text('Ochirish', style: TextStyle(color: Colors.white)),
        content: Text("${s.fullName} ma'lumotlari o'chirilsinmi?",
            style: const TextStyle(color: GTheme.soft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.delete(s.id);
            },
            child: const Text("O'chirish", style: TextStyle(color: GTheme.red)),
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final GirlStudentModel student;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StudentTile({
    required this.student,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: GTheme.cardDecoration(),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: GTheme.pink.withOpacity(0.15),
          backgroundImage:
              student.imageUrl.isNotEmpty ? NetworkImage(student.imageUrl) : null,
          child: student.imageUrl.isEmpty
              ? Text(
                  student.fullName.isNotEmpty
                      ? student.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: GTheme.pink, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Text(student.fullName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${student.faculty} • ${student.course}-kurs • ${student.group}',
            style: TextStyle(color: GTheme.white.withOpacity(0.5), fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: GTheme.white.withOpacity(0.6)),
          color: GTheme.bgCard2,
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: 'edit',
              child: Text('Tahrirlash', style: TextStyle(color: Colors.white)),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text("O'chirish", style: TextStyle(color: GTheme.red)),
            ),
          ],
        ),
      ),
    );
  }
}
