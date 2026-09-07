import 'api_service.dart';

class NotificationApiService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> list() {
    return _api.getNotifications();
  }

  Future<void> markRead(String id) {
    return _api.markNotificationRead(id);
  }

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> body,
  ) {
    return _api.createNotification(body);
  }
}