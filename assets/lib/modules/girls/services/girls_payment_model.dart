import 'package:cloud_firestore/cloud_firestore.dart';

enum GirlsPaymentStatus {
  paid("To'landi"),
  pending('Kutilmoqda'),
  overdue("Muddati o'tgan");

  final String displayName;
  const GirlsPaymentStatus(this.displayName);
}

enum GirlsPaymentMethod {
  naqd('Naqd'),
  karta('Plastik karta'),
  otkazma("Bank o'tkazmasi");

  final String displayName;
  const GirlsPaymentMethod(this.displayName);
}

class GirlsPaymentModel {
  final String id;
  final String studentId;
  final String studentName;
  final String? roomId;
  final double amount;
  final String month; // masalan: "2026-07"
  final GirlsPaymentStatus status;
  final GirlsPaymentMethod method;
  final String? note;
  final String? receiptUrl;
  final String? receiptPath;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? paidAt;

  GirlsPaymentModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.roomId,
    required this.amount,
    required this.month,
    required this.status,
    required this.method,
    this.note,
    this.receiptUrl,
    this.receiptPath,
    required this.createdBy,
    required this.createdAt,
    this.paidAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'roomId': roomId,
      'amount': amount,
      'month': month,
      'status': status.name,
      'method': method.name,
      'note': note,
      'receiptUrl': receiptUrl,
      'receiptPath': receiptPath,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
    };
  }

  factory GirlsPaymentModel.fromJson(String id, Map<String, dynamic> json) {
    return GirlsPaymentModel(
      id: id,
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      roomId: json['roomId'] as String?,
      amount: (json['amount'] ?? 0).toDouble(),
      month: json['month'] as String? ?? '',
      status: GirlsPaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GirlsPaymentStatus.pending,
      ),
      method: GirlsPaymentMethod.values.firstWhere(
        (e) => e.name == json['method'],
        orElse: () => GirlsPaymentMethod.naqd,
      ),
      note: json['note'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
      receiptPath: json['receiptPath'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      paidAt: json['paidAt'] != null
          ? (json['paidAt'] as Timestamp).toDate()
          : null,
    );
  }

  GirlsPaymentModel copyWith({
    GirlsPaymentStatus? status,
    DateTime? paidAt,
    String? receiptUrl,
    String? receiptPath,
  }) {
    return GirlsPaymentModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      roomId: roomId,
      amount: amount,
      month: month,
      status: status ?? this.status,
      method: method,
      note: note,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptPath: receiptPath ?? this.receiptPath,
      createdBy: createdBy,
      createdAt: createdAt,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
