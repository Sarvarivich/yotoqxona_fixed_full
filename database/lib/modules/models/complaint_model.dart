enum ComplaintStatus {
  pending('Kutilmoqda'),
  reviewing('Ko\'rib chiqilmoqda'),
  resolved('Hal qilindi'),
  closed('Yopilgan');

  final String displayName;
  const ComplaintStatus(this.displayName);
}

enum ComplaintPriority {
  low('Past'),
  medium('O\'rtacha'),
  high('Muhim');

  final String displayName;
  const ComplaintPriority(this.displayName);
}

// Murojaat kimga yuborilganini bildiradi: yotoqxona mudiriga yoki adminga
enum ComplaintTarget {
  mudir('mudir', 'Yotoqxona mudiri'),
  admin('admin', 'Administrator');

  final String value;
  final String displayName;
  const ComplaintTarget(this.value, this.displayName);

  factory ComplaintTarget.fromString(String? value) {
    return ComplaintTarget.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ComplaintTarget.admin,
    );
  }
}

class ComplaintModel {
  final String id;
  final String studentId;
  // Murojaatni kim yuborganini ko'rsatish uchun ("kimdan")
  final String studentName;
  final String title;
  final String description;
  final String category;
  final ComplaintStatus status;
  final ComplaintPriority priority;
  // Murojaat kimga yuborilgani ("kimga"): mudir yoki admin
  final ComplaintTarget targetRole;
  final String? assignedTo;
  String? response;
  // Javobni kim (F.I.Sh. va lavozimi) yozganini ko'rsatish uchun
  final String? respondedByName;
  final String? respondedByRole;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final List<String> attachments;
  // Talaba "Anonim yuborish"ni tanlaganini bildiradi. E'tibor bering:
  // studentId/studentName har doim HAQIQIY talabaga tegishli bo'lib qoladi —
  // bu faqat ko'rsatish (masalan boshqa talabalarga) uchun ishlatiladigan
  // belgi. Admin/mudir kim yuborganini har doim ko'ra oladi.
  final bool isAnonymous;

  ComplaintModel({
    required this.id,
    required this.studentId,
    this.studentName = '',
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.priority,
    this.targetRole = ComplaintTarget.admin,
    this.assignedTo,
    this.response,
    this.respondedByName,
    this.respondedByRole,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    required this.attachments,
    this.isAnonymous = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'title': title,
      'description': description,
      'category': category,
      'status': status.name,
      'priority': priority.name,
      'targetRole': targetRole.value,
      'assignedTo': assignedTo,
      'response': response,
      'respondedByName': respondedByName,
      'respondedByRole': respondedByRole,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'resolvedAt': resolvedAt,
      'attachments': attachments,
      'isAnonymous': isAnonymous,
    };
  }

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Umumiy',
      status: _getComplaintStatus(json['status'] as String?),
      priority: _getComplaintPriority(json['priority'] as String?),
      targetRole: ComplaintTarget.fromString(json['targetRole'] as String?),
      assignedTo: json['assignedTo'] as String?,
      response: json['response'] as String?,
      respondedByName: json['respondedByName'] as String?,
      respondedByRole: json['respondedByRole'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as dynamic).toDate()
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? (json['resolvedAt'] as dynamic).toDate()
          : null,
      attachments: List<String>.from(json['attachments'] as List? ?? []),
      isAnonymous: json['isAnonymous'] as bool? ?? false,
    );
  }

  ComplaintModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? title,
    String? description,
    String? category,
    ComplaintStatus? status,
    ComplaintPriority? priority,
    ComplaintTarget? targetRole,
    String? assignedTo,
    String? response,
    String? respondedByName,
    String? respondedByRole,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    List<String>? attachments,
    bool? isAnonymous,
  }) {
    return ComplaintModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      targetRole: targetRole ?? this.targetRole,
      assignedTo: assignedTo ?? this.assignedTo,
      response: response ?? this.response,
      respondedByName: respondedByName ?? this.respondedByName,
      respondedByRole: respondedByRole ?? this.respondedByRole,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      attachments: attachments ?? this.attachments,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  static ComplaintStatus _getComplaintStatus(String? status) {
    if (status == null) return ComplaintStatus.pending;
    try {
      return ComplaintStatus.values.firstWhere((e) => e.name == status);
    } catch (e) {
      return ComplaintStatus.pending;
    }
  }

  static ComplaintPriority _getComplaintPriority(String? priority) {
    if (priority == null) return ComplaintPriority.medium;
    try {
      return ComplaintPriority.values.firstWhere((e) => e.name == priority);
    } catch (e) {
      return ComplaintPriority.medium;
    }
  }
}
