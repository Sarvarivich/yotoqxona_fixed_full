import '../../models/complaint_model.dart';
import '../../services/api_service.dart';

// ─── GirlsComplaintService: Qizlar yotoqxonasi murojaatlari ────────
//
// Ma'lumot Laravel API'dan olinadi: GET /api/complaints
//
// Talabalar murojaat yozganda u umumiy `complaints` jadvaliga
// tushadi. Bino talabaning yoki xonasining `hostel` maydonidan
// aniqlanadi — alohida "girls_complaints" jadvali yo'q.
//
// DIQQAT: metodlar hamon `Stream` qaytaradi, chunki ekranlar
// `StreamBuilder` bilan yozilgan. Lekin bu bir martalik oqim —
// real vaqtda yangilanish yo'q.
class GirlsComplaintService {
  final ApiService _api = ApiService();
  static const String _hostel = 'girls';

  /// Murojaat qaysi binoga tegishli ekanini aniqlaydi.
  String _bino(Map<String, dynamic> d) {
    var bino = (d['hostel'] ?? '').toString().trim().toLowerCase();

    if (bino.isEmpty || bino.length > 10) {
      final xona = d['room'];
      if (xona is Map) {
        bino = (xona['hostel_type'] ?? '').toString().toLowerCase();
      }
    }
    if (bino.isEmpty) {
      final talaba = d['student'];
      if (talaba is Map) {
        bino = (talaba['hostel'] ?? '').toString().toLowerCase();
      }
    }

    return bino.isEmpty ? 'boys' : bino;
  }

  Future<List<ComplaintModel>> _yukla({String? studentId}) async {
    final natija = <ComplaintModel>[];

    try {
      final javob = await _api.get('complaints');
      final royxat = javob['data'];
      if (royxat is! List) return natija;

      for (final e in royxat) {
        if (e is! Map) continue;
        final d = Map<String, dynamic>.from(e);

        if (_bino(d) != _hostel) continue;

        if (studentId != null &&
            (d['student_id'] ?? '').toString() != studentId) {
          continue;
        }

        try {
          natija.add(ComplaintModel.fromJson(d));
        } catch (_) {
          // Buzuq yozuv ro'yxatni to'xtatmasin.
        }
      }
    } catch (_) {
      // Xato bo'lsa bo'sh ro'yxat qaytadi — ekran "murojaat yo'q"
      // deb ko'rsatadi.
    }

    natija.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return natija;
  }

  Stream<List<ComplaintModel>> getComplaints() =>
      Stream.fromFuture(_yukla());

  Stream<List<ComplaintModel>> getComplaintsForStudent(String studentId) =>
      Stream.fromFuture(_yukla(studentId: studentId));

  Future<void> addComplaint(ComplaintModel complaint) async {
    await _api.post('complaints', body: {
      'title': complaint.title,
      'description': complaint.description,
      'category': complaint.category,
      'priority': 'medium',
    });
  }

  /// Murojaatga javob berish.
  ///
  /// Backend javob bergan xodimni (responded_by) tokendan o'zi
  /// aniqlaydi va resolved_at ni qo'yadi — shuning uchun bu yerda
  /// respondedByName/Role yuborilmaydi.
  Future<void> respond({
    required String id,
    required String response,
    required String respondedByName,
    required String respondedByRole,
  }) async {
    await _api.put('complaints/$id', body: {
      'response': response,
      'status': ComplaintStatus.resolved.name,
    });
  }

  Future<void> updateStatus(String id, ComplaintStatus status) async {
    await _api.put('complaints/$id', body: {
      'status': status.name,
    });
  }

  Future<void> deleteComplaint(String id) async {
    await _api.deleteComplaint(id);
  }
}
