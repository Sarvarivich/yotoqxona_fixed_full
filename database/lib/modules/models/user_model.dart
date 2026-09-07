// Talaba ro'yxatdan o'tishda va profilida tanlaydigan fakultetlar ro'yxati
const List<String> kFaculties = [
  'Turizm va Iqtisodiyot fakulteti',
  "Ta'lim fakulteti",
];

// Talaba ro'yxatdan o'tishda tanlaydigan joriy kurs (1—4)
const List<String> kCourses = ['1', '2', '3', '4'];

enum UserRole {
  talaba('talaba'),
  mudir('mudir'),
  moliyachi('moliyachi'),
  admin('admin'),
  superAdmin('superAdmin');

  final String name;
  const UserRole(this.name);

  factory UserRole.fromString(String value) {
    // ⚠️ Diagnostika: agar Firestore'dagi "role" maydoni
    // enum qiymatlaridan ('talaba', 'mudir', 'moliyachi', 'superAdmin')
    // birortasiga ANIQ mos kelmasa (masalan bo'sh, boshqa yozilishda,
    // katta-kichik harf xato bo'lsa), tizim JIMgina "talaba"ga
    // tushirib yuboradi. Shu sabab admin login qilganda oddiy
    // profil bo'lib kirib qolishi mumkin. Shuning uchun bu holatni
    // konsolga chiqaramiz — Firestore'dagi haqiqiy qiymatni tekshirish
    // uchun.
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () {
        // ignore: avoid_print
        print(
            '⚠️ UserRole.fromString: Noma\'lum rol qiymati topildi: "$value". '
            'Firestore\'dagi "foydalanuvchilar/{uid}" hujjatida "role" '
            'maydoni aniq "superAdmin" / "mudir" / "moliyachi" / "talaba" '
            'so\'zlaridan biriga teng ekanini tekshiring (katta-kichik harf, '
            'bo\'shliq va yozilishiga e\'tibor bering). Vaqtincha "talaba" '
            'sifatida kirilmoqda.');
        return UserRole.talaba;
      },
    );
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
  final String? course; // Joriy kurs: '1', '2', '3' yoki '4'
  final String? passportId;
  // JSHSHIR — Jismoniy shaxsning shaxsiy identifikatsiya raqami
  // (14 xonali, O'zbekiston fuqarolari uchun yagona identifikatsiya raqami).
  final String? jshshir;
  final DateTime? birthDate;
  final String? region; // Viloyat
  final String? district; // Tuman/Shahar
  final DateTime? createdAt;
  // Talaba/foydalanuvchi qanday yaratilgani: 'self' — o'zi ro'yxatdan
  // o'tgan, 'admin' — Admin/Mudir tomonidan qo'lda qo'shilgan. Eski
  // (bu maydon yozilishidan oldingi) hisoblar uchun bu null bo'ladi.
  final String? registeredBy;
  final Map<String, dynamic>? additionalData;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.fcmToken,
    this.hostel,
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

  // O'qish uchun qulay: talaba o'zi ro'yxatdan o'tganmi yoki
  // Admin/Mudir tomonidan qo'shilganmi.
  bool get isSelfRegistered => registeredBy == 'self';
  bool get isAddedByAdmin => registeredBy == 'admin';

  String get name => fullName;
  String get phone => phoneNumber;

  // Convert UserModel to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'hostel': hostel,
      'fcmToken': fcmToken,
      'studentId': studentId,
      'roomId': roomId,
      'faculty': faculty,
      'course': course,
      'passportId': passportId,
      'jshshir': jshshir,
      'birthDate': birthDate,
      'region': region,
      'district': district,
      'createdAt': createdAt,
      'registeredBy': registeredBy,
      ...?additionalData,
    };
  }

  // Create UserModel from JSON from Firestore
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final parsed = Map<String, dynamic>.from(json);
    final metadata = Map<String, dynamic>.from(parsed);
    metadata.removeWhere((key, value) => [
          'id',
          'fullName',
          'name',
          'email',
          'phoneNumber',
          'phone',
          'role',
          'fcmToken',
          'studentId',
          'roomId',
          'faculty',
          'course',
          'passportId',
          'jshshir',
          'birthDate',
          'region',
          'district',
          'createdAt',
          'registeredBy',
        ].contains(key));

    return UserModel(
      id: parsed['id'] as String? ?? '',
      fullName:
          (parsed['fullName'] as String?) ?? (parsed['name'] as String?) ?? '',
      email: parsed['email'] as String? ?? '',
      phoneNumber: (parsed['phoneNumber'] as String?) ??
          (parsed['phone'] as String?) ??
          '',
      role: UserRole.fromString(parsed['role'] as String? ?? 'talaba'),
      hostel: parsed['hostel'] as String?,
      fcmToken: parsed['fcmToken'] as String?,
      studentId: parsed['studentId'] as String?,
      roomId: parsed['roomId'] as String?,
      faculty: parsed['faculty'] as String?,
      course: parsed['course'] as String?,
      passportId: parsed['passportId'] as String?,
      jshshir: parsed['jshshir'] as String?,
      birthDate: parsed['birthDate'] != null
          ? (parsed['birthDate'] as dynamic).toDate()
          : null,
      region: parsed['region'] as String?,
      district: parsed['district'] as String?,
      createdAt: parsed['createdAt'] != null
          ? (parsed['createdAt'] as dynamic).toDate()
          : null,
      registeredBy: parsed['registeredBy'] as String?,
      additionalData: metadata.isNotEmpty ? metadata : null,
    );
  }

  // Create a copy with modified fields
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
