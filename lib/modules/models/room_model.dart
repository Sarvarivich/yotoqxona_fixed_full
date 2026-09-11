enum RoomStatus {
  empty('Bo‘sh'),
  occupied('Band'),
  paymentPending('To‘lov kutilmoqda'),
  renovation('Ta’mirlashda');

  final String displayName;

  const RoomStatus(this.displayName);
}

class RoomModel {
  final String id;
  final int roomNumber;
  final int floor;
  final int capacity;
  final int currentOccupants;
  final RoomStatus status;

  final String hostel;
  final String hostelType;

  final List<String> amenities;
  final List<String> studentIds;

  final double pricePerMonth;

  final DateTime? lastPaymentDate;
  final String? notes;

  final DateTime createdAt;
  final DateTime? updatedAt;

  RoomModel({
    required this.id,
    required this.roomNumber,
    required this.floor,
    required this.capacity,
    required this.currentOccupants,
    required this.status,
    required this.hostel,
    this.hostelType = 'university',
    required this.amenities,
    required this.studentIds,
    required this.pricePerMonth,
    this.lastPaymentDate,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  int get floorNumber => floor;

  int get currentOccupancy => currentOccupants;

  double get monthlyRate => pricePerMonth;

  List<String> get occupants => studentIds;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_number': roomNumber,
      'roomNumber': roomNumber,

      'floor': floor,

      'capacity': capacity,

      'current_occupants': currentOccupants,
      'currentOccupants': currentOccupants,

      'status': status.name,

      'hostel': hostel,
      'hostel_type': hostelType,
      'hostelType': hostelType,

      'amenities': amenities,
      'facilities': amenities,

      'student_ids': studentIds,
      'studentIds': studentIds,

      'price_per_month': pricePerMonth,
      'pricePerMonth': pricePerMonth,

      'last_payment_date':
          lastPaymentDate?.toIso8601String(),

      'lastPaymentDate':
          lastPaymentDate?.toIso8601String(),

      'notes': notes,

      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),

      'updated_at': updatedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Xonaning binosini ('boys' / 'girls') aniqlaydi.
  ///
  /// Laravel hostel maydonida bog'langan obyekt qaytaradi:
  ///   "hostel": { "id": "...", "code": "boys", "name": "1-bino ..." }
  /// Eski Firestore esa oddiy matn yozardi: "hostel": "boys".
  ///
  /// Ikkala holatni ham qo'llab-quvvatlaymiz. Hech biri bo'lmasa
  /// hostel_type dan olamiz (u ham 'boys'/'girls' bo'lishi mumkin).
  static String _hostelCode(Map<String, dynamic> json) {
    final xom = json['hostel'];

    if (xom is Map) {
      final kod = (xom['code'] ?? '').toString().trim().toLowerCase();
      if (kod.isNotEmpty) return kod;

      // code bo'lmasa nomidan aniqlaymiz
      final nom = (xom['name'] ?? '').toString().toLowerCase();
      if (nom.contains('qiz')) return 'girls';
      if (nom.isNotEmpty) return 'boys';
    }

    if (xom is String) {
      final kod = xom.trim().toLowerCase();
      if (kod == 'boys' || kod == 'girls') return kod;
    }

    final turi =
        (json['hostel_type'] ?? json['hostelType'] ?? '').toString().trim().toLowerCase();
    if (turi == 'girls') return 'girls';

    return 'boys';
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: _stringValue(
        json['id'],
      ),

      roomNumber: _intValue(
        json['room_number'] ??
            json['roomNumber'],
      ),

      floor: _intValue(
        json['floor'] ??
            json['floor_number'] ??
            json['floorNumber'],
      ),

      capacity: _intValue(
        json['capacity'],
      ),

      currentOccupants: _intValue(
        json['current_occupants'] ??
            json['currentOccupants'] ??
            json['current_occupancy'] ??
            json['currentOccupancy'],
      ),

      status: _getRoomStatus(
        json['status']?.toString(),
      ),

      hostel: _hostelCode(json),

      hostelType: _normalizeHostelType(
        json['hostel_type'] ??
            json['hostelType'],
      ),

      amenities: _stringList(
        json['amenities'] ??
            json['facilities'],
      ),

      studentIds: _stringList(
        json['student_ids'] ??
            json['studentIds'] ??
            json['occupants'],
      ),

      pricePerMonth: _doubleValue(
        json['price_per_month'] ??
            json['pricePerMonth'] ??
            json['monthly_rate'] ??
            json['monthlyRate'],
      ),

      lastPaymentDate: _dateValue(
        json['last_payment_date'] ??
            json['lastPaymentDate'],
      ),

      notes: json['notes']?.toString(),

      createdAt: _dateValue(
            json['created_at'] ??
                json['createdAt'],
          ) ??
          DateTime.now(),

      updatedAt: _dateValue(
        json['updated_at'] ??
            json['updatedAt'],
      ),
    );
  }

  RoomModel copyWith({
    String? id,
    int? roomNumber,
    int? floor,
    int? capacity,
    int? currentOccupants,
    RoomStatus? status,
    String? hostel,
    String? hostelType,
    List<String>? amenities,
    List<String>? studentIds,
    double? pricePerMonth,
    DateTime? lastPaymentDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoomModel(
      id: id ?? this.id,
      roomNumber: roomNumber ?? this.roomNumber,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      currentOccupants:
          currentOccupants ?? this.currentOccupants,
      status: status ?? this.status,
      hostel: hostel ?? this.hostel,
      hostelType: hostelType ?? this.hostelType,
      amenities: amenities ?? this.amenities,
      studentIds: studentIds ?? this.studentIds,
      pricePerMonth: pricePerMonth ?? this.pricePerMonth,
      lastPaymentDate:
          lastPaymentDate ?? this.lastPaymentDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) return fallback;

    return value.toString();
  }

  static int _intValue(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  static double _doubleValue(dynamic value) {
    if (value == null) return 0;

    if (value is double) return value;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  static List<String> _stringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((item) => item.toString())
          .toList();
    }

    return [];
  }

  static DateTime? _dateValue(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    return DateTime.tryParse(
      value.toString(),
    );
  }

  static String _normalizeHostelType(dynamic raw) {
    final value =
        (raw ?? '').toString().trim().toLowerCase();

    switch (value) {
      case 'medical':
      case 'med_college':
      case 'med_kollej':
        return 'medical';

      case 'avto_yol':
      case 'avtoyol':
      case 'avto':
        return 'avto_yol';

      case 'navoi_object':
      case 'navoiy_object':
      case 'navoi':
        return 'navoi_object';

      case 'rental':
      case 'ijara':
        return 'rental';

      case 'university':
      case 'universitet':
      case '':
        return 'university';

      default:
        return value;
    }
  }

  static RoomStatus _getRoomStatus(
    String? status,
  ) {
    if (status == null) {
      return RoomStatus.empty;
    }

    final normalized =
        status.trim().toLowerCase();

    switch (normalized) {
      case 'empty':
      case 'available':
      case 'bo\'sh':
      case 'bosh':
        return RoomStatus.empty;

      case 'occupied':
      case 'full':
      case 'band':
        return RoomStatus.occupied;

      case 'paymentpending':
      case 'payment_pending':
      case 'pending':
        return RoomStatus.paymentPending;

      case 'renovation':
      case 'maintenance':
        return RoomStatus.renovation;

      default:
        return RoomStatus.empty;
    }
  }
}