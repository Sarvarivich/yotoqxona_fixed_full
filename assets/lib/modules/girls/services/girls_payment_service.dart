import 'package:cloud_firestore/cloud_firestore.dart';
import 'girls_payment_model.dart';

// ─── GirlsPaymentService: Qizlar yotoqxonasi to'lovlari uchun
// mustaqil Firestore to'plami ('girls_payments').
class GirlsPaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('girls_payments');

  Stream<List<GirlsPaymentModel>> getPayments() {
    return _collection.orderBy('createdAt', descending: true).snapshots().map(
      (snap) => snap.docs
          .map((doc) => GirlsPaymentModel.fromJson(doc.id, doc.data()))
          .toList(),
    );
  }

  Stream<List<GirlsPaymentModel>> getPaymentsForStudent(String studentId) {
    return _collection
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GirlsPaymentModel.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> addPayment(GirlsPaymentModel payment) async {
    await _collection.add(payment.toJson());
  }

  Future<void> markAsPaid(String id) async {
    await _collection.doc(id).update({
      'status': GirlsPaymentStatus.paid.name,
      'paidAt': Timestamp.now(),
    });
  }

  Future<void> updatePayment(GirlsPaymentModel payment) async {
    await _collection.doc(payment.id).update(payment.toJson());
  }

  Future<void> deletePayment(String id) async {
    await _collection.doc(id).delete();
  }
}
