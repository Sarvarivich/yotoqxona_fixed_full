import '../../services/api_service.dart';
import 'girls_notification_model.dart';

// ─── GirlsNotificationService: Qizlar yotoqxonasi bildirishnomalari
//
// Ma'lumot Laravel API'dan olinadi: GET /api/notifications
//
// Ilgari alohida 'girls_notifications' to'plami bor edi. Laravel'da
// bildirishnomalar umumiy `notifications` jadvalida va har biri
// aniq foydalanuvchiga biriktiriladi.
//
// DIQQAT: metod hamon `Stream` qaytaradi — ekranlar `StreamBuilder`
// bilan yozilgan.
class GirlsNotificationService {
  final ApiService _api = ApiService();

  Future<List<GirlsNotificationModel>> _yukla() async {
    final natija = <GirlsNotificationModel>[];

    try {
      final javob = await _api.get('notifications');
      final royxat = javob['data'];
      if (royxat is! List) return natija;

      for (final e in royxat) {
        if (e is! Map) continue;
        final d = Map<String, dynamic>.from(e);

        natija.add(GirlsNotificationModel(
          id: (d['id'] ?? '').toString(),
          title: (d['title'] ?? '').toString(),
          // Laravel `message` yozadi, eski Firestore ham shunday edi.
          message: (d['message'] ?? d['body'] ?? '').toString(),
          target: GirlsNotificationTarget.fromString(
            (d['target'] ?? 'student').toString(),
          ),
          targetId: (d['user_id'] ?? d['targetId'])?.toString(),
          targetLabel: (d['targetLabel'])?.toString(),
          createdBy: (d['created_by'] ?? d['createdBy'] ?? '').toString(),
          createdAt: DateTime.tryParse(
                (d['created_at'] ?? d['createdAt'] ?? '').toString(),
              ) ??
              DateTime.now(),
        ));
      }
    } catch (_) {
      // Xato bo'lsa bo'sh ro'yxat qaytadi.
    }

    natija.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return natija;
  }

  Stream<List<GirlsNotificationModel>> getNotifications() =>
      Stream.fromFuture(_yukla());

  /// Bildirishnoma yuboradi.
  ///
  /// Laravel har bir bildirishnomani aniq foydalanuvchiga
  /// biriktiradi. "Barchaga" yuborish uchun backend'da alohida
  /// endpoint kerak — hozircha faqat bitta talabaga yuboriladi.
  Future<void> send(GirlsNotificationModel notification) async {
    final userId = notification.targetId;

    if (userId == null || userId.isEmpty) {
      throw Exception(
        "Bildirishnoma uchun talaba tanlanmagan. "
        "Hozircha faqat bitta talabaga yuborish mumkin.",
      );
    }

    await _api.post('notifications', body: {
      'user_id': userId,
      'title': notification.title,
      'message': notification.message,
      'type': 'general',
    });
  }

  Future<void> delete(String id) async {
    await _api.delete('notifications/$id');
  }
}
