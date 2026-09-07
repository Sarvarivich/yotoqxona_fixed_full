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
      'student_id': studentId,
      'studentName': studentName,
      'title': title,
      'description': description,
      'category': category,
      'status': status.name,
      'priority': priority.name,
      'targetRole': targetRole.value,
      'target_role': targetRole.value,
      'assignedTo': assignedTo,
      'response': response,
      'respondedByName': respondedByName,
      'respondedByRole': respondedByRole,
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'attachments': attachments,
      'isAnonymous': isAnonymous,
      'is_anonymous': isAnonymous,
    };
  }

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    String studentName = _parseString(json['studentName'] ?? json['student_name']);
    if (studentName.isEmpty && json['student'] is Map) {
      studentName = _parseString(json['student']['full_name'] ?? json['student']['fullName']);
    }

    List<String> attachmentsList = [];
    final rawAttachments = json['attachments'];
    if (rawAttachments is List) {
      for (final att in rawAttachments) {
        if (att is String) {
          attachmentsList.add(att);
        } else if (att is Map && att['storage_path'] != null) {
          attachmentsList.add(att['storage_path'].toString());
        }
      }
    }

    return ComplaintModel(
      id: _parseString(json['id']),
      studentId: _parseString(json['studentId'] ?? json['student_id']),
      studentName: studentName,
      title: _parseString(json['title']),
      description: _parseString(json['description']),
      category: _parseString(json['category'], fallback: 'Umumiy'),
      status: _getComplaintStatus(_parseString(json['status'])),
      priority: _getComplaintPriority(_parseString(json['priority'])),
      targetRole: ComplaintTarget.fromString(
        _parseString(json['targetRole'] ?? json['target_role']),
      ),
      assignedTo: json['assignedTo']?.toString() ?? json['assigned_to']?.toString(),
      response: json['response']?.toString(),
      respondedByName: json['respondedByName']?.toString() ??
          (json['responded_by'] is Map ? json['responded_by']['full_name']?.toString() : null),
      respondedByRole: json['respondedByRole']?.toString() ?? json['responded_by_role']?.toString(),
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
      resolvedAt: _parseDate(json['resolvedAt'] ?? json['resolved_at']),
      attachments: attachmentsList,
      isAnonymous: json['isAnonymous'] == true ||
          json['is_anonymous'] == true ||
          json['is_anonymous'] == 1 ||
          json['is_anonymous'] == '1',
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

  static String _parseString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final str = value.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      // Firebase Timestamp handling
      return (value as dynamic).toDate();
    } catch (_) {
      return null;
    }
  }

  static ComplaintStatus _getComplaintStatus(String? status) {
    if (status == null || status.isEmpty) return ComplaintStatus.pending;
    final s = status.toLowerCase();
    if (s == 'open' || s == 'submitted') return ComplaintStatus.pending;
    if (s == 'in_progress' || s == 'reviewing') return ComplaintStatus.reviewing;
    if (s == 'resolved' || s == 'approved') return ComplaintStatus.resolved;
    if (s == 'closed' || s == 'rejected') return ComplaintStatus.closed;

    try {
      return ComplaintStatus.values.firstWhere((e) => e.name.toLowerCase() == s);
    } catch (_) {
      return ComplaintStatus.pending;
    }
  }

  static ComplaintPriority _getComplaintPriority(String? priority) {
    if (priority == null || priority.isEmpty) return ComplaintPriority.medium;
    final p = priority.toLowerCase();
    try {
      return ComplaintPriority.values.firstWhere((e) => e.name.toLowerCase() == p);
    } catch (_) {
      return ComplaintPriority.medium;
    }
  }
}
