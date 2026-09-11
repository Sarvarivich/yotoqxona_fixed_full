import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™ Moliya bo'limi Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎСљ Qarzdorlar ro'yxati Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™Р В Р вЂ Р Р†Р вЂљРЎСљР В РІР‚С™
// Xonaga biriktirilgan har bir talaba uchun uning BARCHA tasdiqlangan
// (approved) to'lovlari yig'indisi xona narxidan kam bo'lsa, u
// "qarzdor" deb hisoblanadi. Qarz miqdori = xona narxi - jami
// tasdiqlangan to'lov summasi (oyga bog'liq emas).

class _C {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
  static const bgCard2 = Color(0xFF16132B);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFa29bfe);
  static const teal = Color(0xFF00CEC9);
  static const mint = Color(0xFF55EFC4);
  static const pink = Color(0xFFfd79a8);
  static const orange = Color(0xFFfdcb6e);
  static const coral = Color(0xFFe17055);
  static const white = Color(0xFFFFFFFF);
  static const soft = Color(0xB3FFFFFF);
  static const muted = Color(0x66FFFFFF);
  static const faint = Color(0x0FFFFFFF);
}

class DebtorInfo {
  final String studentId;
  final String fullName;
  final String? phoneNumber;
  final String roomLabel;
  final double expected;
  final double paid;

  /// 'boys' | 'girls' Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎСљ talaba qaysi yotoqxonaga tegishli ekanini
  /// bildiradi, ro'yxatda belgi (badge) sifatida ko'rsatish uchun.
  final String hostel;
  double get debt => (expected - paid) < 0 ? 0 : (expected - paid);

  DebtorInfo({
    required this.studentId,
    required this.fullName,
    required this.phoneNumber,
    required this.roomLabel,
    required this.expected,
    required this.paid,
    this.hostel = 'boys',
  });
}

/// Barcha qarzdor talabalarni hisoblab beradi.
/// Qarz = xonaning (bir oylik) narxi - talabaning BARCHA tasdiqlangan
/// (approved) to'lovlari yig'indisi. Oyga bog'liq emas Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎСљ talaba
/// ro'yxatga olingandan beri to'lagan har qanday tasdiqlangan summa
/// hisobga olinadi.
/// Barcha qarzdor talabalarni hisoblab beradi.
///
/// Qarz = xonaning bir oylik narxi - talabaning BARCHA
/// tasdiqlangan to'lovlari yig'indisi. Oyga bog'liq emas.
///
/// Ilgari beshta Firestore so'rovi bor edi: xonalar,
/// foydalanuvchilar, girls_students, tolov_cheklari va
/// girls_payments. Laravel'da qizlar uchun alohida jadval
/// yo'q - hamma talaba users, hamma to'lov payments da.
/// Shuning uchun uchta so'rov yetarli.
Future<List<DebtorInfo>> fetchDebtors() async {
  final api = ApiService();

  double son(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  // --- 1) Xonalar: ID va raqam bo'yicha narx/nom xaritasi ---
  //
  // Ikkala kalit ham qo'shiladi, chunki talabaning xonasi
  // ba'zan UUID, ba'zan raqam ko'rinishida keladi.
  final Map<String, double> roomPrice = {};
  final Map<String, String> roomLabel = {};

  try {
    for (final x in await api.getRooms()) {
      if (x is! Map) continue;
      final d = Map<String, dynamic>.from(x);

      final price = son(d['price_per_month'] ?? d['pricePerMonth']);
      final roomNum = d['room_number'] ?? d['roomNumber'];
      final label = roomNum != null ? '$roomNum-xona' : 'Xona';

      final id = (d['id'] ?? '').toString();
      if (id.isNotEmpty) {
        roomPrice[id] = price;
        roomLabel[id] = label;
      }
      if (roomNum != null) {
        final numKey = roomNum.toString();
        roomPrice[numKey] = price;
        roomLabel[numKey] = label;
      }
    }
  } catch (e) {
    debugPrint('Xonalarni yuklashda xatolik: $e');
  }

  // --- 2) Tasdiqlangan to'lovlar: talaba -> jami summa ---
  final totalPaid = <String, double>{};
  try {
    final javob = await api.get('payments');
    final royxat = javob['data'];
    if (royxat is List) {
      for (final e in royxat) {
        if (e is! Map) continue;
        final d = Map<String, dynamic>.from(e);

        final holat = (d['status'] ?? '').toString().toLowerCase();
        if (holat != 'approved' && holat != 'paid') continue;

        final sid = (d['student_id'] ?? d['studentId'] ?? '').toString();
        if (sid.isEmpty) continue;

        totalPaid[sid] = (totalPaid[sid] ?? 0) + son(d['amount']);
      }
    }
  } catch (e) {
    debugPrint("To'lovlarni yuklashda xatolik: $e");
  }

  // --- 3) Talabalar (sahifama-sahifa) ---
  final List<DebtorInfo> debtors = [];

  try {
    int sahifa = 1;
    int oxirgi = 1;

    do {
      final javob = await api.get(
        'students?role=talaba&per_page=100&page=$sahifa',
      );

      final royxat = javob['data'];
      if (royxat is List) {
        for (final e in royxat) {
          if (e is! Map) continue;
          final d = Map<String, dynamic>.from(e);

          // Xonasi yo'q talaba ro'yxatga kirmaydi - unga hali
          // to'lov majburiyati yuklanmagan.
          final b =
              d['active_room_assignment'] ?? d['activeRoomAssignment'];
          if (b is! Map) continue;

          // Xona kaliti: avval raqam, keyin UUID.
          String? roomKey;
          final xona = b['room'];
          if (xona is Map) {
            final raqam = xona['room_number'] ?? xona['roomNumber'];
            if (raqam != null) roomKey = raqam.toString();
            roomKey ??= (xona['id'] ?? '').toString();
          }
          roomKey ??= (b['room_id'] ?? '').toString();
          if (roomKey.isEmpty) continue;

          final expected = roomPrice[roomKey];
          if (expected == null || expected <= 0) continue;

          final id = (d['id'] ?? '').toString();
          if (id.isEmpty) continue;

          final ism = (d['full_name'] ?? d['fullName'] ?? '').toString();
          final hostel =
              (d['hostel'] ?? 'boys').toString().trim().toLowerCase();

          debtors.add(DebtorInfo(
            studentId: id,
            fullName: ism.isNotEmpty ? ism : "Noma'lum talaba",
            phoneNumber: (d['phone'] ?? d['phoneNumber'])?.toString(),
            roomLabel: roomLabel[roomKey] ?? 'Xona',
            expected: expected,
            paid: totalPaid[id] ?? 0,
            hostel: hostel.isEmpty ? 'boys' : hostel,
          ));
        }
      }

      final meta = javob['meta'];
      oxirgi = meta is Map
          ? ((meta['last_page'] as num?)?.toInt() ?? sahifa)
          : sahifa;
      sahifa++;
    } while (sahifa <= oxirgi && sahifa <= 100);
  } catch (e) {
    debugPrint('Talabalarni yuklashda xatolik: $e');
  }

  debtors.sort((a, b) => b.debt.compareTo(a.debt));
  return debtors;
}

class QarzdorlarRoyxati extends StatefulWidget {
  const QarzdorlarRoyxati({super.key});

  @override
  State<QarzdorlarRoyxati> createState() => _QarzdorlarRoyxatiState();
}

class _QarzdorlarRoyxatiState extends State<QarzdorlarRoyxati> {
  late Future<List<DebtorInfo>> _future;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = fetchDebtors();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = fetchDebtors());
    await _future;
  }

  Future<void> _sendReminder(DebtorInfo d) async {
    try {
      // Bildirishnoma Laravel orqali yuboriladi. Backend uni
      // notifications jadvaliga yozadi. is_read va created_at
      // server tomonda avtomatik to'ldiriladi.
      await ApiService().post('notifications', body: {
        'user_id': d.studentId,
        'title': "To'lov bo'yicha eslatma",
        'message': "Hurmatli talaba, bu oy uchun ${d.roomLabel} " +
            "to'lovingizdan ${d.debt.toStringAsFixed(0)} so'm " +
            "qarzdorligingiz mavjud. Iltimos, to'lovni amalga oshiring.",
        'type': 'payment_reminder',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${d.fullName}ga eslatma yuborildi"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bgBase,
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: _C.violet,
        backgroundColor: _C.bgCard,
        child: FutureBuilder<List<DebtorInfo>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _C.violet),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Text('Xatolik: ${snap.error}',
                    style: const TextStyle(color: _C.muted)),
              );
            }
            final all = snap.data ?? [];
            final filtered = _query.isEmpty
                ? all
                : all
                    .where((d) => d.fullName.toLowerCase().contains(_query))
                    .toList();
            final totalDebt = all.fold<double>(0, (sum, d) => sum + d.debt);
            final realDebtorsCount = all.where((d) => d.debt > 0).length;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.groups_rounded,
                          color: _C.coral,
                          title: 'Qarzdorlar soni',
                          value: '$realDebtorsCount ta',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.account_balance_wallet_rounded,
                          color: _C.orange,
                          title: 'Umumiy qarz',
                          value: '${_fmt(totalDebt)} so\'m',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: _C.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.faint),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: _C.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Talaba ismi bo\'yicha qidirish...',
                        hintStyle: TextStyle(color: _C.muted, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: _C.muted),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.emoji_events_rounded,
                                size: 56, color: _C.mint.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              all.isEmpty
                                  ? "Bu oy uchun qarzdorlar yo'q Р РЋР вЂљР РЋРЎСџР В РІР‚в„–Р Р†Р вЂљР’В°"
                                  : "Qidiruv bo'yicha natija topilmadi",
                              style: TextStyle(color: _C.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filtered.map((d) => _DebtorCard(
                          data: d,
                          onRemind: () => _sendReminder(d),
                        )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.faint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  color: _C.white, fontSize: 16, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(color: _C.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DebtorCard extends StatelessWidget {
  final DebtorInfo data;
  final VoidCallback onRemind;
  const _DebtorCard({required this.data, required this.onRemind});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.faint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.coral, _C.pink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Text(
                  data.fullName.isNotEmpty
                      ? data.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(data.fullName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _C.white),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        _HostelBadge(hostel: data.hostel),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(data.roomLabel,
                        style: TextStyle(fontSize: 11.5, color: _C.muted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (data.debt > 0 ? _C.coral : _C.mint).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  data.debt > 0
                      ? "${data.debt.toStringAsFixed(0)} so'm"
                      : "To'liq to'langan",
                  style: TextStyle(
                      color: data.debt > 0 ? _C.coral : _C.mint,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniInfo(
                    label: "Kerakli summa",
                    value: "${data.expected.toStringAsFixed(0)} so'm"),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniInfo(
                    label: "To'langan",
                    value: "${data.paid.toStringAsFixed(0)} so'm"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.orange,
                side: BorderSide(color: _C.orange.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.notifications_active_rounded, size: 16),
              label: const Text("Eslatma yuborish"),
              onPressed: onRemind,
            ),
          ),
        ],
      ),
    );
  }
}

/// Р РЋР вЂљР РЋРЎСџР РЋРІвЂћСћР вЂ™Р’В» "O'g'il bolalar" / "Qiz bolalar" belgisi Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎСљ moliyachi ro'yxatda
/// qaysi yotoqxonaga tegishli talaba ekanini bir qarashda ko'rishi uchun.
class _HostelBadge extends StatelessWidget {
  final String hostel; // 'boys' | 'girls'
  const _HostelBadge({required this.hostel});

  @override
  Widget build(BuildContext context) {
    final isGirls = hostel == 'girls';
    final color = isGirls ? _C.pink : _C.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isGirls ? 'Qiz' : "O'g'il",
        style:
            TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  const _MiniInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.bgCard2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _C.muted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: _C.soft, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
