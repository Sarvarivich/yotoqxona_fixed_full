import 'package:cloud_firestore/cloud_firestore.dart';
import 'girls_notification_model.dart';

// ─── GirlsNotificationService: Qizlar yotoqxonasi bildirishnomalari
// uchun mustaqil Firestore to'plami ('girls_notifications').
class GirlsNotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('girls_notifications');

  Stream<List<GirlsNotificationModel>> getNotifications() {
    return _collection.orderBy('createdAt', descending: true).snapshots().map(
      (snap) => snap.docs
          .map((doc) => GirlsNotificationModel.fromJson(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> send(GirlsNotificationModel notification) async {
    await _collection.add(notification.toJson());
  }

  Future<void> delete(String id) async {
    await _collection.doc(id).delete();
  }
}
