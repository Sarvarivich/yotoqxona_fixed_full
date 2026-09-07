import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/girl_student_model.dart';

class GirlsStudentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _collection => _db.collection('girls_students');

  Future<String> addStudent(GirlStudentModel student) async {
    final doc = await _collection.add(student.toMap());
    return doc.id;
  }

  Future<void> updateStudent(String id, GirlStudentModel student) async {
    await _collection.doc(id).update(student.toMap());
  }

  Future<void> deleteStudent(String id) async {
    await _collection.doc(id).delete();
  }

  Stream<List<GirlStudentModel>> getStudents() {
    return _collection.orderBy('fullName').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return GirlStudentModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  /// Talabaning `roomId` maydonini yangilaydi — xonaga biriktirish yoki
  /// xonadan chiqarish uchun ishlatiladi (bo'sh string = xonasiz).
  Future<void> setRoomId(String studentId, String roomId) async {
    await _collection.doc(studentId).update({'roomId': roomId});
  }
}
