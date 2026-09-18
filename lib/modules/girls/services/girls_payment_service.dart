import '../../services/api_service.dart';
import 'girls_payment_model.dart';

// ─── GirlsPaymentService: Qizlar yotoqxonasi to'lovlari ────────────
//
// Ma'lumot Laravel API'dan olinadi: GET /api/payments
//
// Ilgari alohida 'girls_payments' to'plami bor edi. Laravel'da
// hamma to'lov `payments` jadvalida, bino esa xonaning
// `hostel_type` maydonidan yoki talabaning `hostel` maydonidan
// aniqlanadi.
//
// DIQQAT: metodlar hamon `Stream` qaytaradi — ekranlar
// `StreamBuilder` bilan yozilgan.
class GirlsPaymentService {
  final ApiService _api = ApiService();

  String _bino(Map<String, dynamic> d) {
    final xona = d['room'];
    if (xona is Map) {
      final t = (xona['hostel_type'] ?? '').toString().toLowerCase();
      if (t.isNotEmpty) return t;
    }

    final talaba = d['student'];
    if (talaba is Map) {
      final t = (talaba['hostel'] ?? '').toString().toLowerCase();
      if (t.isNotEmpty) return t;
    }

    return 'boys';
  }

  /// Laravel holatini ekran kutayotgan holatga o'giradi.
  GirlsPaymentStatus _holat(Map<String, dynamic> d) {
    final xom = (d['status'] ?? '').toString().toLowerCase();

    if (xom == 'approved' || xom == 'paid') return GirlsPaymentStatus.paid;
    if (xom == 'rejected') return GirlsPaymentStatus.overdue;
    return GirlsPaymentStatus.pending;
  }

  GirlsPaymentMethod _usul(Map<String, dynamic> d) {
    final xom = (d['method'] ?? '').toString().toLowerCase();

    if (xom == 'karta' || xom == 'card' || xom == 'payme') {
      return GirlsPaymentMethod.karta;
    }
    if (xom == 'otkazma' || xom == 'bank' || xom == 'transfer') {
      return GirlsPaymentMethod.otkazma;
    }
    return GirlsPaymentMethod.naqd;
  }

  GirlsPaymentModel _model(Map<String, dynamic> d) {
    final talaba = d['student'];
    final xona = d['room'];

    return GirlsPaymentModel(
      id: (d['id'] ?? '').toString(),
      studentId: (d['student_id'] ?? '').toString(),
      studentName: talaba is Map
          ? (talaba['full_name'] ?? '').toString()
          : (d['student_name'] ?? '').toString(),
      roomId: xona is Map
          ? (xona['room_number'] ?? xona['id'])?.toString()
          : (d['room_id'])?.toString(),
      amount: double.tryParse((d['amount'] ?? 0).toString()) ?? 0,
      month: (d['period'] ?? d['month'] ?? '').toString(),
      status: _holat(d),
      method: _usul(d),
      note: (d['note'])?.toString(),
      receiptUrl: (d['receipt_url'] ?? d['receiptUrl'])?.toString(),
      receiptPath: (d['receipt_path'])?.toString(),
      createdBy: (d['reviewed_by'] ?? '').toString(),
      createdAt: DateTime.tryParse((d['created_at'] ?? '').toString()) ??
          DateTime.now(),
      paidAt: DateTime.tryParse((d['paid_at'] ?? '').toString()),
    );
  }

  Future<List<GirlsPaymentModel>> _yukla({String? studentId}) async {
    final natija = <GirlsPaymentModel>[];

    try {
      final javob = await _api.get('payments');
      final royxat = javob['data'];
      if (royxat is! List) return natija;

      for (final e in royxat) {
        if (e is! Map) continue;
        final d = Map<String, dynamic>.from(e);

        if (_bino(d) != 'girls') continue;

        if (studentId != null &&
            (d['student_id'] ?? '').toString() != studentId) {
          continue;
        }

        natija.add(_model(d));
      }
    } catch (_) {
      // Xato bo'lsa bo'sh ro'yxat qaytadi.
    }

    natija.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return natija;
  }

  Stream<List<GirlsPaymentModel>> getPayments() =>
      Stream.fromFuture(_yukla());

  Stream<List<GirlsPaymentModel>> getPaymentsForStudent(String studentId) =>
      Stream.fromFuture(_yukla(studentId: studentId));

  Future<void> addPayment(GirlsPaymentModel payment) async {
    await _api.post('payments', body: {
      'student_id': payment.studentId,
      'amount': payment.amount,
      'period': payment.month,
      'method': payment.method.name,
      if (payment.note != null) 'note': payment.note,
    });
  }

  /// To'lovni tasdiqlaydi.
  ///
  /// Backend `paid_at` ni va tasdiqlagan xodimni o'zi yozadi.
  Future<void> markAsPaid(String id) async {
    await _api.put('payments/$id', body: {
      'status': 'approved',
    });
  }

  Future<void> updatePayment(GirlsPaymentModel payment) async {
    await _api.put('payments/${payment.id}', body: {
      'amount': payment.amount,
      'period': payment.month,
      'method': payment.method.name,
      if (payment.note != null) 'note': payment.note,
    });
  }

  Future<void> deletePayment(String id) async {
    await _api.deletePayment(id);
  }
}
