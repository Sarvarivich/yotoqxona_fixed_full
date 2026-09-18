import '../../../services/api_service.dart';
import '../../services/girl_student_model.dart';

// ─── GirlsStudentService: Qizlar yotoqxonasi talabalari ────────────
//
// Ma'lumot Laravel API'dan olinadi: GET /api/students?hostel=girls
//
// Ilgari alohida 'girls_students' to'plami bor edi va u yerdagi
// talabalar Firebase Auth hisobisiz edi. Laravel'da hamma talaba
// `users` jadvalida, bino esa `hostel` ustunida.
//
// DIQQAT: getStudents() hamon `Stream` qaytaradi — ekranlar
// `StreamBuilder` bilan yozilgan.
class GirlsStudentService {
  final ApiService _api = ApiService();

  GirlStudentModel _model(Map<String, dynamic> d) {
    // Xona raqami biriktirish ichida keladi.
    var roomId = '';
    final b = d['active_room_assignment'] ?? d['activeRoomAssignment'];
    if (b is Map) {
      final xona = b['room'];
      if (xona is Map) {
        roomId = (xona['room_number'] ?? xona['id'] ?? '').toString();
      }
    }

    return GirlStudentModel(
      id: (d['id'] ?? '').toString(),
      fullName: (d['full_name'] ?? d['fullName'] ?? '').toString(),
      faculty: (d['faculty'] ?? '').toString(),
      course: (d['course'] ?? '').toString(),
      group: (d['group_name'] ?? d['group'] ?? '').toString(),
      phone: (d['phone'] ?? d['phoneNumber'] ?? '').toString(),
      roomId: roomId,
      imageUrl: (d['image_url'] ?? d['imageUrl'] ?? '').toString(),
      isActive: d['is_active'] != false,
      createdAt: DateTime.tryParse((d['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Future<List<GirlStudentModel>> _yukla() async {
    final natija = <GirlStudentModel>[];

    try {
      // Backend bir so'rovda 100 tadan ko'p bermaydi.
      int sahifa = 1;
      int oxirgi = 1;

      do {
        final javob = await _api.get(
          'students?role=talaba&hostel=girls&per_page=100&page=$sahifa',
        );

        final royxat = javob['data'];
        if (royxat is List) {
          for (final e in royxat) {
            if (e is Map) {
              natija.add(_model(Map<String, dynamic>.from(e)));
            }
          }
        }

        final meta = javob['meta'];
        oxirgi = meta is Map
            ? ((meta['last_page'] as num?)?.toInt() ?? sahifa)
            : sahifa;
        sahifa++;
      } while (sahifa <= oxirgi && sahifa <= 100);
    } catch (_) {
      // Xato bo'lsa bo'sh ro'yxat qaytadi.
    }

    natija.sort((a, b) => a.fullName.compareTo(b.fullName));
    return natija;
  }

  Stream<List<GirlStudentModel>> getStudents() =>
      Stream.fromFuture(_yukla());

  /// Yangi talaba qo'shadi.
  ///
  /// Laravel har bir talabaga email va parol talab qiladi (u tizimga
  /// kira olishi kerak). Ilgari girls_students da bular yo'q edi,
  /// shuning uchun vaqtinchalik qiymatlar yaratiladi — keyin
  /// xodim ularni tahrirlaydi.
  Future<String> addStudent(GirlStudentModel student) async {
    final taxallus = student.fullName
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]"), '')
        .padRight(4, 'x');

    final javob = await _api.createStudent({
      'full_name': student.fullName,
      'email': '$taxallus${DateTime.now().millisecondsSinceEpoch}@ku.uz',
      'password': 'Yotoqxona${DateTime.now().year}',
      'role': 'talaba',
      'hostel': 'girls',
      if (student.phone.isNotEmpty) 'phone': student.phone,
      if (student.faculty.isNotEmpty) 'faculty': student.faculty,
      if (student.course.isNotEmpty)
        'course': int.tryParse(student.course.replaceAll(RegExp(r'[^0-9]'), '')),
      if (student.group.isNotEmpty) 'group_name': student.group,
    });

    final d = javob['data'];
    return d is Map ? (d['id'] ?? '').toString() : '';
  }

  Future<void> updateStudent(String id, GirlStudentModel student) async {
    await _api.updateStudent(id, {
      'full_name': student.fullName,
      if (student.phone.isNotEmpty) 'phone': student.phone,
      if (student.faculty.isNotEmpty) 'faculty': student.faculty,
      if (student.course.isNotEmpty)
        'course': int.tryParse(student.course.replaceAll(RegExp(r'[^0-9]'), '')),
      if (student.group.isNotEmpty) 'group_name': student.group,
      'is_active': student.isActive,
    });
  }

  Future<void> deleteStudent(String id) async {
    await _api.deleteStudent(id);
  }

  /// Talabani xonaga biriktiradi yoki xonadan chiqaradi.
  ///
  /// Bo'sh [roomId] — xonadan chiqarish.
  Future<void> setRoomId(String studentId, String roomId) async {
    if (roomId.isEmpty) {
      // Joriy biriktirishni topib bekor qilamiz.
      final biriktirishlar = await _api.getRoomAssignments();
      for (final b in biriktirishlar) {
        if (b is! Map) continue;
        final d = Map<String, dynamic>.from(b);
        if ((d['student_id'] ?? '').toString() != studentId) continue;

        final id = (d['id'] ?? '').toString();
        if (id.isNotEmpty) await _api.unassignRoomStudent(id);
        return;
      }
      return;
    }

    await _api.assignStudentToRoom(studentId: studentId, roomId: roomId);
  }
}
