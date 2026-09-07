class GirlStudentModel {
  final String id;
  final String fullName;
  final String faculty;
  final String course;
  final String group;
  final String phone;
  final String roomId;
  final String imageUrl;
  final bool isActive;
  final DateTime createdAt;

  GirlStudentModel({
    required this.id,
    required this.fullName,
    required this.faculty,
    required this.course,
    required this.group,
    required this.phone,
    required this.roomId,
    required this.imageUrl,
    required this.isActive,
    required this.createdAt,
  });

  factory GirlStudentModel.fromMap(Map<String, dynamic> map, String id) {
    return GirlStudentModel(
      id: id,
      fullName: map['fullName'] ?? '',
      faculty: map['faculty'] ?? '',
      course: map['course'] ?? '',
      group: map['group'] ?? '',
      phone: map['phone'] ?? '',
      roomId: map['roomId'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'faculty': faculty,
      'course': course,
      'group': group,
      'phone': phone,
      'roomId': roomId,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'hostelType': 'girls',
    };
  }
}
