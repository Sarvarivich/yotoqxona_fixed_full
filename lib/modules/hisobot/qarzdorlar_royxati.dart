import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Moliya bo'limi — Qarzdorlar ro'yxati ──────────────────────────
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

  /// 'boys' | 'girls' — talaba qaysi yotoqxonaga tegishli ekanini
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
/// (approved) to'lovlari yig'indisi. Oyga bog'liq emas — talaba
/// ro'yxatga olingandan beri to'lagan har qanday tasdiqlangan summa
/// hisobga olinadi.
Future<List<DebtorInfo>> fetchDebtors() async {
  final fs = FirebaseFirestore.instance;

  // 1) Barcha xonalarni olish -> roomId -> (narx, xona raqami)
  // Diqqat: ilovada xonaga talaba biriktirishning ikki xil ekrani bor —
  // biri talabaning roomId'siga xonaning Firestore hujjat ID'sini
  // yozadi (xona_taqsimlash.dart), ikkinchisi esa xona RAQAMINI
  // (masalan "204") yozadi (room_assignment_screen.dart). Shuning
  // uchun narxlar jadvalini ikkala kalit bo'yicha ham to'ldiramiz,
  // toifasidan qat'iy nazar talabaning xonasi to'g'ri topilsin.
  final roomsSnap = await fs.collection('xonalar').get();
  final Map<String, double> roomPrice = {};
  final Map<String, String> roomLabel = {};
  for (final doc in roomsSnap.docs) {
    final d = doc.data();
    final price = (d['pricePerMonth'] as num? ?? d['monthlyRate'] as num? ?? 0)
        .toDouble();
    final roomNum = d['roomNumber'];
    final label = roomNum != null ? '$roomNum-xona' : 'Xona';

    roomPrice[doc.id] = price;
    roomLabel[doc.id] = label;
    if (roomNum != null) {
      final numKey = roomNum.toString();
      roomPrice[numKey] = price;
      roomLabel[numKey] = label;
    }
  }

  // 2) Barcha talabalarni olish — IKKI manbadan:
  //    a) O'zi ro'yxatdan o'tganlar: 'foydalanuvchilar' (role == 'talaba').
  //       Bu yerda hostel bo'yicha filtr YO'Q, shuning uchun bu so'rov
  //       o'g'il bolalar VA qiz bolalar yotoqxonasida o'zi ro'yxatdan
  //       o'tgan barcha talabalarni avtomatik qamrab oladi.
  //    b) Admin/mudira QO'LDA qo'shgan qiz bolalar talabalari:
  //       'girls_students' kolleksiyasi. Bunday talabalarning Firebase
  //       Auth hisobi yo'q, shuning uchun ular 'foydalanuvchilar'da
  //       umuman ko'rinmaydi — shu sabab alohida so'rov qilinadi.
  final studentsSnap = await fs
      .collection('foydalanuvchilar')
      .where('role', isEqualTo: 'talaba')
      .get();
  final girlsStudentsSnap = await fs.collection('girls_students').get();

  // 3) Har bir talabaning BARCHA tasdiqlangan to'lovlarini yig'ib
  //    chiqamiz — sana bo'yicha cheklov yo'q. Bu ham IKKI manbadan:
  //    a) 'tolov_cheklari' (status == 'approved') — talaba o'zi yuborib,
  //       moliyachi tasdiqlagan cheklar (ikkala hostel uchun ham).
  //    b) 'girls_payments' (status == 'paid') — admin/mudira tomonidan
  //       qo'lda kiritilgan qiz bolalar to'lovlari (odatda 'girls_students'
  //       orqali qo'shilgan, o'zi chek yubora olmaydigan talabalar uchun).
  final totalPaid = <String, double>{};
  try {
    final checksSnap = await fs
        .collection('tolov_cheklari')
        .where('status', isEqualTo: 'approved')
        .get();
    for (final doc in checksSnap.docs) {
      final d = doc.data();
      final studentId = d['studentId'] as String?;
      if (studentId == null) continue;

      final amount = (d['amount'] as num? ?? 0).toDouble();
      totalPaid[studentId] = (totalPaid[studentId] ?? 0) + amount;
    }
  } catch (_) {}
  try {
    final girlsPaymentsSnap = await fs
        .collection('girls_payments')
        .where('status', isEqualTo: 'paid')
        .get();
    for (final doc in girlsPaymentsSnap.docs) {
      final d = doc.data();
      final studentId = d['studentId'] as String?;
      if (studentId == null || studentId.isEmpty) continue;

      final amount = (d['amount'] as num? ?? 0).toDouble();
      totalPaid[studentId] = (totalPaid[studentId] ?? 0) + amount;
    }
  } catch (_) {}

  final List<DebtorInfo> debtors = [];

  // Ikkala manbadan kelgan talabani bir xil qoidalar bilan qarzdorlar
  // ro'yxatiga qo'shuvchi yordamchi funksiya (kod takrorlanmasligi uchun).
  void addIfHasRoom({
    required String id,
    required String fullName,
    required String? phoneNumber,
    required String? roomId,
    String hostel = 'boys',
  }) {
    if (roomId == null || roomId.isEmpty) return; // xonasi yo'q talaba
    final expected = roomPrice[roomId];
    if (expected == null || expected <= 0) return;

    final paid = totalPaid[id] ?? 0;
    debtors.add(DebtorInfo(
      studentId: id,
      fullName: fullName.isNotEmpty ? fullName : 'Noma\'lum talaba',
      phoneNumber: phoneNumber,
      roomLabel: roomLabel[roomId] ?? 'Xona',
      expected: expected,
      paid: paid,
      hostel: hostel,
    ));
  }

  // Endi BARCHA xonaga biriktirilgan talabalar ro'yxatga kiradi —
  // to'liq to'lagan talabalar ham ko'rinadi, ularning qarzi 0 so'm
  // bo'lib chiqadi (DebtorInfo.debt getter shuni ta'minlaydi).
  for (final doc in studentsSnap.docs) {
    final d = doc.data();
    final rawHostel = (d['hostel'] as String?)?.trim().toLowerCase();
    addIfHasRoom(
      id: doc.id,
      fullName: (d['fullName'] as String?) ?? '',
      phoneNumber: d['phoneNumber'] as String?,
      roomId: d['roomId'] as String?,
      hostel: (rawHostel == null || rawHostel.isEmpty) ? 'boys' : rawHostel,
    );
  }
  for (final doc in girlsStudentsSnap.docs) {
    final d = doc.data();
    addIfHasRoom(
      id: doc.id,
      fullName: (d['fullName'] as String?) ?? '',
      // ⚠️ 'girls_students' hujjatlarida telefon maydoni 'phone' deb
      // nomlangan (foydalanuvchilar'dagi 'phoneNumber' emas).
      phoneNumber: d['phone'] as String?,
      roomId: d['roomId'] as String?,
      // Bu kolleksiyadagi barcha talabalar qiz bolalar yotoqxonasiga
      // tegishli — hujjatda alohida 'hostel' maydoni bo'lmasa ham.
      hostel: 'girls',
    );
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
      await FirebaseFirestore.instance.collection('bildirishnomalar').add({
        'userId': d.studentId,
        'title': "To'lov bo'yicha eslatma",
        'body': "Hurmatli talaba, bu oy uchun ${d.roomLabel} to'lovingizdan "
            "${d.debt.toStringAsFixed(0)} so'm qarzdorligingiz mavjud. "
            "Iltimos, to'lovni amalga oshiring.",
        'type': 'payment_reminder',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
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
                                  ? "Bu oy uchun qarzdorlar yo'q 🎉"
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

/// 🚻 "O'g'il bolalar" / "Qiz bolalar" belgisi — moliyachi ro'yxatda
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
