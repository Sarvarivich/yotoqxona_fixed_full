import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomStatus {
  empty('Boʻsh'),
  occupied('Band'),
  paymentPending('Toʻlov kutilmoqda'),
  renovation('Taʼmirlashda');

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

  /// Jins bo'yicha bo'lim: boys / girls.
  final String hostel;

  /// Yotoqxona turi bo'yicha mustaqil bo'lim:
  /// university / medical / avto_yol / navoi_object / rental.
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

  // Getterlar
  int get floorNumber => floor;
  int get currentOccupancy => currentOccupants;
  double get monthlyRate => pricePerMonth;
  List<String> get occupants => studentIds;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomNumber': roomNumber,
      'floor': floor,
      'capacity': capacity,
      'currentOccupants': currentOccupants,
      'status': status.name,

      // Yangi maydon
      'hostel': hostel,
      'hostelType': hostelType,

      'amenities': amenities,
      'facilities': amenities,

      'studentIds': studentIds,

      'pricePerMonth': pricePerMonth,

      'lastPaymentDate':
          lastPaymentDate != null ? Timestamp.fromDate(lastPaymentDate!) : null,

      'notes': notes,

      'createdAt': Timestamp.fromDate(createdAt),

      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String? ?? '',

      roomNumber: json['roomNumber'] is int
          ? json['roomNumber']
          : int.tryParse(json['roomNumber']?.toString() ?? '') ?? 0,

      floor: json['floor'] is int
          ? json['floor']
          : json['floorNumber'] is int
              ? json['floorNumber']
              : int.tryParse(json['floor']?.toString() ?? '') ?? 0,

      capacity: json['capacity'] as int? ?? 0,

      currentOccupants: json['currentOccupants'] as int? ??
          json['currentOccupancy'] as int? ??
          0,

      status: _getRoomStatus(json['status'] as String?),

      // Jins bo'yicha bo'lim.
      hostel: json['hostel'] as String? ?? 'boys',

      // Eski xonalarda hostelType bo'lmasa, ularni universitet
      // yotoqxonasiga tegishli deb qabul qilamiz.
      hostelType: _normalizeHostelType(json['hostelType'] as String?),

      amenities: List<String>.from(
        json['amenities'] ?? json['facilities'] ?? [],
      ),

      studentIds: List<String>.from(
        json['studentIds'] ?? json['occupants'] ?? [],
      ),

      pricePerMonth:
          (json['pricePerMonth'] ?? json['monthlyRate'] ?? 0).toDouble(),

      lastPaymentDate: json['lastPaymentDate'] != null
          ? (json['lastPaymentDate'] as Timestamp).toDate()
          : null,

      notes: json['notes'] as String?,

      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),

      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
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
      currentOccupants: currentOccupants ?? this.currentOccupants,
      status: status ?? this.status,
      hostel: hostel ?? this.hostel,
      hostelType: hostelType ?? this.hostelType,
      amenities: amenities ?? this.amenities,
      studentIds: studentIds ?? this.studentIds,
      pricePerMonth: pricePerMonth ?? this.pricePerMonth,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }


  static String _normalizeHostelType(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
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

  static RoomStatus _getRoomStatus(String? status) {
    if (status == null) return RoomStatus.empty;

    try {
      return RoomStatus.values.firstWhere(
        (e) => e.name == status,
      );
    } catch (_) {
      return RoomStatus.empty;
    }
  }
}
