import 'package:flutter/material.dart';
import '../screens/students/girls_student_service.dart';
import '../services/girl_student_model.dart';

class GirlsStudentProvider extends ChangeNotifier {
  final GirlsStudentService _service = GirlsStudentService();

  Stream<List<GirlStudentModel>> get students => _service.getStudents();

  Future<String> add(GirlStudentModel student) async {
    return _service.addStudent(student);
  }

  Future<void> update(GirlStudentModel student) async {
    await _service.updateStudent(
      student.id,
      student,
    );
  }

  Future<void> delete(String id) async {
    await _service.deleteStudent(id);
  }

  /// Talabaning xonasini belgilaydi (yoki bo'shatadi, roomId: '').
  Future<void> setRoomId(String studentId, String roomId) async {
    await _service.setRoomId(studentId, roomId);
    notifyListeners();
  }
}
