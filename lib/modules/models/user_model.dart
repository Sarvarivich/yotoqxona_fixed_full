// Talaba ro'yxatdan o'tishda va profilida tanlaydigan fakultetlar ro'yxati
const List<String> kFaculties = [
  'Turizm va Iqtisodiyot fakulteti',
  "Ta'lim fakulteti",
];

// Talaba ro'yxatdan o'tishda tanlaydigan joriy kurs
const List<String> kCourses = ['1', '2', '3', '4'];

enum UserRole {
  talaba('talaba'),
  mudir('mudir'),
  moliyachi('moliyachi'),
  admin('admin'),
  superAdmin('superAdmin');

  final String name;

  const UserRole(this.name);

  factory UserRole.fromString(dynamic value) {
    final raw = value?.toString().trim() ?? '';

    final normalized = raw
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');

    switch (normalized) {
      case 'talaba':
      case 'student':
        return UserRole.talaba;

      case 'mudir':
      case 'director':
        return UserRole.mudir;

      case 'moliyachi':
      case 'finance':
      case 'accountant':
        return UserRole.moliyachi;

      case 'admin':
      case 'administrator':
        return UserRole.admin;

      case 'superadmin':
      case 'superadministrator':
      case 'superuser':
        return UserRole.superAdmin;

      default:
        return UserRole.talaba;
    }
  }
}

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final UserRole role;

  final String? hostel;
  final String? fcmToken;
  final String? studentId;
  final String? roomId;

  final String? faculty;
  final String? course;

  final String? passportId;
  final String? jshshir;

  final DateTime? birthDate;
  final String? region;
  final String? district;

  final DateTime? createdAt;
  final String? registeredBy;

  final Map<String, dynamic>? additionalData;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.hostel,
    this.fcmToken,
    this.studentId,
    this.roomId,
    this.faculty,
    this.course,
    this.passportId,
    this.jshshir,
    this.birthDate,
    this.region,
    this.district,
    this.createdAt,
    this.registeredBy,
    this.additionalData,
  });

  // =========================
  // QULAY GETTERLAR
  // =========================

  String get name => fullName;

  String get phone => phoneNumber;

  bool get hasRoom =>
      roomId != null && roomId!.trim().isNotEmpty;

  bool get isStudent => role == UserRole.talaba;

  bool get isMudir => role == UserRole.mudir;

  bool get isMoliyachi => role == UserRole.moliyachi;

  bool get isAdmin => role == UserRole.admin;

  bool get isSuperAdmin => role == UserRole.superAdmin;

  bool get isSelfRegistered =>
      registeredBy?.toLowerCase() == 'self';

  bool get isAddedByAdmin =>
      registeredBy?.toLowerCase() == 'admin';

  // =========================
  // ARIZA
  // =========================

  int get applicationStep {
    final raw = additionalData?['applicationStep'] ??
        additionalData?['application_step'];

    if (raw is num) {
      final value = raw.toInt();
      if (value < 1) return 1;
      if (value > 5) return 5;
      return value;
    }

    if (raw is String) {
      final value = int.tryParse(raw);

      if (value != null) {
        if (value < 1) return 1;
        if (value > 5) return 5;
        return value;
      }
    }

    return hasRoom ? 3 : 2;
  }

  String get applicationStatus =>
      (additionalData?['applicationStatus'] ??
              additionalData?['application_status'] ??
              'submitted')
          .toString();

  String? get assignmentType =>
      (additionalData?['hostelAssignmentType'] ??
              additionalData?['hostel_assignment_type'])
          ?.toString();

  String? get assignmentMessage =>
      (additionalData?['assignmentMessage'] ??
              additionalData?['assignment_message'])
          ?.toString();

  bool get isRentalAssignment =>
      assignmentType?.toLowerCase() == 'rental';

  bool get hasPhysicalHostelAssignment =>
      assignmentType != null &&
      assignmentType!.trim().isNotEmpty &&
      !isRentalAssignment;

  String get hostelDisplayName {
    switch (assignmentType?.toLowerCase()) {
      case 'university':
        return 'Universitet yotoqxonasi';

      case 'avto_yol':
        return 'Avto yo‘l yotoqxonasi';

      case 'med_college':
        return 'Med kollej yotoqxonasi';

      case 'navoi_object':
        return 'Navoiydagi obyekt yotoqxonasi';

      case 'rental':
        return 'Ijara uchun ajratilgan yotoqxona';

      default:
        if (hostel?.toLowerCase() == 'girls') {
          return 'Qizlar yotoqxonasi';
        }

        return 'O‘g‘il bolalar yotoqxonasi';
    }
  }

  // =========================
  // HUQUQLAR
  // =========================

  Map<String, bool> get permissions {
    final raw = additionalData?['permissions'];

    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(
          key.toString(),
          value == true ||
              value?.toString().toLowerCase() == 'true' ||
              value == 1 ||
              value?.toString() == '1',
        ),
      );
    }

    return const {};
  }

  bool hasPermission(String key) {
    final perms = permissions;

    if (perms.containsKey(key)) {
      return perms[key] == true;
    }

    return role == UserRole.superAdmin;
  }

  // =========================
  // JSON
  // =========================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phoneNumber,
      'role': role.name,
      'hostel': hostel,
      'fcm_token': fcmToken,
      'student_id': studentId,
      'room_id': roomId,
      'faculty': faculty,
      'course': course,
      'passport_id': passportId,
      'jshshir': jshshir,
      'birth_date': birthDate?.toIso8601String(),
      'region': region,
      'district': district,
      'created_at': createdAt?.toIso8601String(),
      'registered_by': registeredBy,
      ...?additionalData,
    };
  }

  // =========================
  // JSON -> USER MODEL
  // Laravel + eski Firebase formatlari
  // =========================

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final parsed = Map<String, dynamic>.from(json);

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        return DateTime.tryParse(value);
      }

      // Eski Firestore Timestamp uchun
      try {
        return (value as dynamic).toDate();
      } catch (_) {
        return null;
      }
    }

    String? readString(dynamic value) {
      if (value == null) return null;

      final result = value.toString().trim();

      if (result.isEmpty || result.toLowerCase() == 'null') {
        return null;
      }

      return result;
    }

    // =========================
    // ROOM ID
    // =========================

    String? activeRoomId = readString(
      parsed['room_id'] ?? parsed['roomId'],
    );

    final activeAssignment =
        parsed['active_room_assignment'] ??
            parsed['activeRoomAssignment'];

    if (activeRoomId == null && activeAssignment is Map) {
      activeRoomId = readString(
        activeAssignment['room_id'] ??
            activeAssignment['roomId'] ??
            activeAssignment['room']?['id'],
      );
    }

    // =========================
    // METADATA
    // =========================

    final metadata = Map<String, dynamic>.from(parsed);

    const knownKeys = [
      'id',
      'uid',

      'full_name',
      'fullName',
      'name',

      'email',

      'phone',
      'phone_number',
      'phoneNumber',

      'role',

      'hostel',

      'fcm_token',
      'fcmToken',

      'student_id',
      'studentId',

      'room_id',
      'roomId',

      'faculty',
      'course',

      'passport_id',
      'passportId',

      'jshshir',

      'birth_date',
      'birthDate',

      'region',
      'district',

      'created_at',
      'createdAt',

      'updated_at',
      'updatedAt',

      'registered_by',
      'registeredBy',

      'active_room_assignment',
      'activeRoomAssignment',
    ];

    metadata.removeWhere(
      (key, value) => knownKeys.contains(key),
    );

    return UserModel(
      id: readString(
            parsed['id'] ?? parsed['uid'],
          ) ??
          '',

      fullName: readString(
            parsed['full_name'] ??
                parsed['fullName'] ??
                parsed['name'],
          ) ??
          '',

      email: readString(parsed['email']) ?? '',

      phoneNumber: readString(
            parsed['phone'] ??
                parsed['phone_number'] ??
                parsed['phoneNumber'],
          ) ??
          '',

      role: UserRole.fromString(parsed['role']),

      hostel: readString(parsed['hostel']),

      fcmToken: readString(
        parsed['fcm_token'] ?? parsed['fcmToken'],
      ),

      studentId: readString(
        parsed['student_id'] ?? parsed['studentId'],
      ),

      roomId: activeRoomId,

      faculty: readString(parsed['faculty']),

      course: readString(parsed['course']),

      passportId: readString(
        parsed['passport_id'] ?? parsed['passportId'],
      ),

      jshshir: readString(parsed['jshshir']),

      birthDate: parseDate(
        parsed['birth_date'] ?? parsed['birthDate'],
      ),

      region: readString(parsed['region']),

      district: readString(parsed['district']),

      createdAt: parseDate(
        parsed['created_at'] ?? parsed['createdAt'],
      ),

      registeredBy: readString(
        parsed['registered_by'] ?? parsed['registeredBy'],
      ),

      additionalData:
          metadata.isEmpty ? null : metadata,
    );
  }

  // =========================
  // COPY WITH
  // =========================

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    UserRole? role,
    String? hostel,
    String? fcmToken,
    String? studentId,
    String? roomId,
    String? faculty,
    String? course,
    String? passportId,
    String? jshshir,
    DateTime? birthDate,
    String? region,
    String? district,
    DateTime? createdAt,
    String? registeredBy,
    Map<String, dynamic>? additionalData,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      hostel: hostel ?? this.hostel,
      fcmToken: fcmToken ?? this.fcmToken,
      studentId: studentId ?? this.studentId,
      roomId: roomId ?? this.roomId,
      faculty: faculty ?? this.faculty,
      course: course ?? this.course,
      passportId: passportId ?? this.passportId,
      jshshir: jshshir ?? this.jshshir,
      birthDate: birthDate ?? this.birthDate,
      region: region ?? this.region,
      district: district ?? this.district,
      createdAt: createdAt ?? this.createdAt,
      registeredBy: registeredBy ?? this.registeredBy,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}