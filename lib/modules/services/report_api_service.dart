import 'api_service.dart';

class ReportApiService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> expenses({
    String? category,
  }) {
    return _api.getExpenses(
      category: category,
    );
  }

  Future<List<dynamic>> budgets() {
    return _api.getBudgets();
  }

  Future<Map<String, dynamic>> dashboard() {
    return _api.getDashboard();
  }

  Future<List<dynamic>> payments() {
    return _api.getPayments();
  }
}