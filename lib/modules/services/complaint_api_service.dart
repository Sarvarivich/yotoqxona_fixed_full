import 'api_service.dart';
import '../models/complaint_model.dart';

class ComplaintApiService {
  final ApiService _api = ApiService();

  Future<List<ComplaintModel>> list({
    String? status,
    String? category,
  }) async {
    final items = await _api.getComplaints(
      status: status,
      category: category,
    );

    return items
        .whereType<Map>()
        .map(
          (item) => ComplaintModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<ComplaintModel?> get(String id) async {
    final result = await _api.getComplaint(id);

    final data = result['data'] ?? result;

    if (data is Map) {
      return ComplaintModel.fromJson(
        Map<String, dynamic>.from(data),
      );
    }

    return null;
  }

  Future<Map<String, dynamic>> create(
    ComplaintModel complaint,
  ) {
    return _api.createComplaint(
      complaint.toJson(),
    );
  }

  Future<Map<String, dynamic>> update(
    String id, {
    String? response,
    ComplaintStatus? status,
  }) {
    final body = <String, dynamic>{};

    if (response != null) {
      body['response'] = response;
    }

    if (status != null) {
      body['status'] = status.name;
    }

    return _api.updateComplaint(
      id,
      body,
    );
  }

  // murojaat_javob.dart bilan mos versiya
  Future<Map<String, dynamic>> updateComplaint(
    String id,
    Map<String, dynamic> body,
  ) {
    return _api.updateComplaint(
      id,
      body,
    );
  }

  Future<void> delete(String id) async {
    await _api.deleteComplaint(id);
  }
}