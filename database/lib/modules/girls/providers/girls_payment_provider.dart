import 'package:flutter/material.dart';
import '../services/girls_payment_model.dart';
import '../services/girls_payment_service.dart';

class GirlsPaymentProvider extends ChangeNotifier {
  final GirlsPaymentService _service = GirlsPaymentService();

  Stream<List<GirlsPaymentModel>> get payments => _service.getPayments();

  Stream<List<GirlsPaymentModel>> forStudent(String studentId) =>
      _service.getPaymentsForStudent(studentId);

  Future<void> add(GirlsPaymentModel payment) => _service.addPayment(payment);

  Future<void> markAsPaid(String id) => _service.markAsPaid(id);

  Future<void> update(GirlsPaymentModel payment) =>
      _service.updatePayment(payment);

  Future<void> delete(String id) => _service.deletePayment(id);
}
