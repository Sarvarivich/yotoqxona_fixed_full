import 'package:flutter/material.dart';
import '../services/girls_notification_model.dart';
import '../services/girls_notification_service.dart';

class GirlsNotificationProvider extends ChangeNotifier {
  final GirlsNotificationService _service = GirlsNotificationService();

  Stream<List<GirlsNotificationModel>> get notifications =>
      _service.getNotifications();

  Future<void> send(GirlsNotificationModel notification) =>
      _service.send(notification);

  Future<void> delete(String id) => _service.delete(id);
}
