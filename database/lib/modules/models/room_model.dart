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

  /// Yangi maydon
  final String hostel;

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

      // Yangi maydon
      hostel: json['hostel'] as String? ?? 'boys',

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
      amenities: amenities ?? this.amenities,
      studentIds: studentIds ?? this.studentIds,
      pricePerMonth: pricePerMonth ?? this.pricePerMonth,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
