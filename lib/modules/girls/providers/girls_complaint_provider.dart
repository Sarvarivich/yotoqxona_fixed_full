import 'package:flutter/material.dart';
import '../../models/complaint_model.dart';
import '../services/girls_complaint_service.dart';

class GirlsComplaintProvider extends ChangeNotifier {
  final GirlsComplaintService _service = GirlsComplaintService();

  Stream<List<ComplaintModel>> get complaints => _service.getComplaints();

  Stream<List<ComplaintModel>> forStudent(String studentId) =>
      _service.getComplaintsForStudent(studentId);

  Future<void> add(ComplaintModel complaint) => _service.addComplaint(complaint);

  Future<void> respond({
    required String id,
    required String response,
    required String respondedByName,
    required String respondedByRole,
  }) =>
      _service.respond(
        id: id,
        response: response,
        respondedByName: respondedByName,
        respondedByRole: respondedByRole,
      );

  Future<void> updateStatus(String id, ComplaintStatus status) =>
      _service.updateStatus(id, status);

  Future<void> delete(String id) => _service.deleteComplaint(id);
}
