import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/complaint_model.dart';

// ─── GirlsComplaintService: Qizlar yotoqxonasi murojaatlari.
//
// ⚠️ MUHIM: talabalar (qizlar ham, o'g'il bolalar ham) murojaat
// yozganda ariza HAR DOIM umumiy 'murojaatlar' to'plamiga ('hostel'
// maydoni bilan) yoziladi (modules/murojaat/murojaat_yozish.dart
// orqali). Shuning uchun bu servis ham aynan o'sha 'murojaatlar'
// to'plamidan, 'hostel' == 'girls' filtri bilan o'qiydi/yozadi —
// avvalgi alohida 'girls_complaints' to'plami hech qachon talabalar
// tomonidan to'ldirilmagani uchun ishlatilmaydi.
class GirlsComplaintService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _hostel = 'girls';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('murojaatlar');

  Stream<List<ComplaintModel>> getComplaints() {
    return _collection
        .where('hostel', isEqualTo: _hostel)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return ComplaintModel.fromJson(data);
      }).toList();
    });
  }

  Stream<List<ComplaintModel>> getComplaintsForStudent(String studentId) {
    return _collection
        .where('hostel', isEqualTo: _hostel)
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return ComplaintModel.fromJson(data);
      }).toList();
    });
  }

  Future<void> addComplaint(ComplaintModel complaint) async {
    final data = complaint.toJson();
    data.remove('id');
    data['createdAt'] = Timestamp.fromDate(complaint.createdAt);
    data['hostel'] = _hostel;
    await _collection.add(data);
  }

  Future<void> respond({
    required String id,
    required String response,
    required String respondedByName,
    required String respondedByRole,
  }) async {
    await _collection.doc(id).update({
      'response': response,
      'respondedByName': respondedByName,
      'respondedByRole': respondedByRole,
      'status': ComplaintStatus.resolved.name,
      'resolvedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> updateStatus(String id, ComplaintStatus status) async {
    await _collection.doc(id).update({
      'status': status.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteComplaint(String id) async {
    await _collection.doc(id).delete();
  }
}
