import 'package:flutter/material.dart';

import '../../../models/user_model.dart';
import '../../services/girls_report_service.dart';
import '../../theme/girls_theme.dart';

// ─── GirlsDashboard: Qizlar yotoqxonasi boshqaruv panelining bosh
// sahifasi — umumiy statistika va tezkor havolalar.
// Statistika 'girls_students', 'xonalar' (hostel: girls), 'girls_complaints',
// 'girls_payments' to'plamlarini JONLI (real-time) kuzatadi: talaba
// o'zi ro'yxatdan o'tsa ham, admin/mudira tomonidan qo'shilsa/
// o'zgartirilsa ham — raqamlar sahifani qayta ochmasdan avtomatik
// yangilanadi.
class GirlsDashboard extends StatefulWidget {
  final UserModel? user;
  final void Function(int tabIndex)? onNavigate;

  const GirlsDashboard({super.key, this.user, this.onNavigate});

  @override
  State<GirlsDashboard> createState() => _GirlsDashboardState();
}

class _GirlsDashboardState extends State<GirlsDashboard> {
  final _reportService = GirlsReportService();
  late final Stream<GirlsReportStats> _statsStream;

  @override
  void initState() {
    super.initState();
    _statsStream = _reportService.watchStats();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Xayrli tong'
        : hour < 18
            ? 'Xayrli kun'
            : 'Xayrli kech';

    return Scaffold(
      backgroundColor: GTheme.bgBase,
      body: SafeArea(
        child: StreamBuilder<GirlsReportStats>(
          stream: _statsStream,
          builder: (context, snapshot) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: GTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '$greeting${widget.user != null ? ", ${widget.user!.fullName}" : ""}!',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Qiz bolalar yotoqxonasi boshqaruv paneli',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Builder(builder: (context) {
                  if (!snapshot.hasData && !snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                          child: CircularProgressIndicator(color: GTheme.pink)),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ErrorRetry(
                      message: "Ma'lumotlarni yuklab bo'lmadi",
                      onRetry: () => setState(() {}),
                    );
                  }
                  final stats = snapshot.data;
                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    // ✅ "childAspectRatio" o'rniga doimiy piksel balandlik
                    // (mainAxisExtent) ishlatilmoqda — ekran torayganda
                    // balandlik qisqarib "BOTTOM OVERFLOWED" xatosi
                    // chiqmasligi uchun.
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 104,
                    ),
                    children: [
                      _DashStat(
                        icon: Icons.groups_2_rounded,
                        label: 'Talabalar',
                        value: '${stats?.totalStudents ?? 0}',
                        color: GTheme.pink,
                        onTap: () => widget.onNavigate?.call(1),
                      ),
                      _DashStat(
                        icon: Icons.meeting_room_rounded,
                        label: 'Xonalar',
                        value: '${stats?.totalRooms ?? 0}',
                        color: GTheme.violet,
                        onTap: () => widget.onNavigate?.call(2),
                      ),
                      _DashStat(
                        icon: Icons.forum_rounded,
                        label: 'Murojaatlar',
                        value: '${stats?.pendingComplaints ?? 0}',
                        color: GTheme.orange,
                        onTap: () => widget.onNavigate?.call(3),
                      ),
                      _DashStat(
                        icon: Icons.payments_rounded,
                        label: "Kutilayotgan to'lov",
                        value: GTheme.formatMoney(stats?.totalPending ?? 0),
                        color: GTheme.teal,
                        onTap: () => widget.onNavigate?.call(5),
                        small: true,
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                const Text('Yangi talabalar',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text("O'zi ro'yxatdan o'tganlar + admin qo'shganlar birgalikda",
                    style: TextStyle(
                        color: GTheme.white.withOpacity(0.4), fontSize: 11)),
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  if (!snapshot.hasData && !snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child: CircularProgressIndicator(color: GTheme.pink)),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ErrorRetry(
                      message: "Talabalar statistikasini yuklab bo'lmadi",
                      onRetry: () => setState(() {}),
                    );
                  }
                  final stats = snapshot.data;
                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    // ✅ "childAspectRatio" o'rniga doimiy piksel balandlik
                    // (mainAxisExtent) ishlatilmoqda — ekran torayganda
                    // balandlik qisqarib "BOTTOM OVERFLOWED" xatosi
                    // chiqmasligi uchun.
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 104,
                    ),
                    children: [
                      _DashStat(
                        icon: Icons.today_rounded,
                        label: 'Bugun',
                        value: '${stats?.studentsToday ?? 0}',
                        color: GTheme.pink,
                        onTap: () => widget.onNavigate?.call(1),
                      ),
                      _DashStat(
                        icon: Icons.view_week_rounded,
                        label: 'Shu hafta',
                        value: '${stats?.studentsThisWeek ?? 0}',
                        color: GTheme.violet,
                        onTap: () => widget.onNavigate?.call(1),
                      ),
                      _DashStat(
                        icon: Icons.calendar_month_rounded,
                        label: 'Shu oy',
                        value: '${stats?.studentsThisMonth ?? 0}',
                        color: GTheme.orange,
                        onTap: () => widget.onNavigate?.call(1),
                      ),
                      _DashStat(
                        icon: Icons.groups_2_rounded,
                        label: 'Barchasi',
                        value: '${stats?.studentsAllTime ?? 0}',
                        color: GTheme.teal,
                        onTap: () => widget.onNavigate?.call(1),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                const Text('Tezkor amallar',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 12),
                _QuickAction(
                  icon: Icons.person_add_alt_1_rounded,
                  label: "Talaba qo'shish",
                  color: GTheme.pink,
                  onTap: () => widget.onNavigate?.call(1),
                ),
                _QuickAction(
                  icon: Icons.add_home_work_rounded,
                  label: "Xona qo'shish",
                  color: GTheme.violet,
                  onTap: () => widget.onNavigate?.call(2),
                ),
                _QuickAction(
                  icon: Icons.campaign_rounded,
                  label: 'Bildirishnoma yuborish',
                  color: GTheme.teal,
                  onTap: () => widget.onNavigate?.call(4),
                ),
                _QuickAction(
                  icon: Icons.add_card_rounded,
                  label: "To'lov qo'shish",
                  color: GTheme.orange,
                  onTap: () => widget.onNavigate?.call(5),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: GTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: Colors.redAccent, size: 28),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: GTheme.white.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon:
                const Icon(Icons.refresh_rounded, size: 16, color: GTheme.pink),
            label: const Text('Qayta urinish',
                style: TextStyle(color: GTheme.pink, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _DashStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final bool small;

  const _DashStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: GTheme.cardDecoration(),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: small ? 15 : 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: GTheme.white.withOpacity(0.5), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: GTheme.cardDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: GTheme.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
