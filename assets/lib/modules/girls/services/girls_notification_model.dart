import 'package:cloud_firestore/cloud_firestore.dart';

enum GirlsNotificationTarget {
  all('all', 'Barcha talabalar'),
  room('room', 'Bitta xona'),
  student('student', 'Bitta talaba');

  final String value;
  final String displayName;
  const GirlsNotificationTarget(this.value, this.displayName);

  factory GirlsNotificationTarget.fromString(String? value) {
    return GirlsNotificationTarget.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GirlsNotificationTarget.all,
    );
  }
}

class GirlsNotificationModel {
  final String id;
  final String title;
  final String message;
  final GirlsNotificationTarget target;
  final String? targetId; // roomId yoki studentId (target != all bo'lsa)
  final String? targetLabel; // ko'rsatish uchun (masalan "205-xona")
  final String createdBy;
  final DateTime createdAt;

  GirlsNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.target,
    this.targetId,
    this.targetLabel,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'target': target.value,
      'targetId': targetId,
      'targetLabel': targetLabel,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GirlsNotificationModel.fromJson(String id, Map<String, dynamic> json) {
    return GirlsNotificationModel(
      id: id,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      target: GirlsNotificationTarget.fromString(json['target'] as String?),
      targetId: json['targetId'] as String?,
      targetLabel: json['targetLabel'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
