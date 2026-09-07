import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bandlik_grafik.dart';
import 'daromat_hisoboti.dart';
import 'talabalar_statistikasi.dart';
import 'hisobot_eksport.dart';

// ─── Creative dark palette (admin_screen bilan bir xil til) ───
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

class Dashboard extends StatefulWidget {
  final bool showFinancials;
  final String hostel;

  const Dashboard({
    super.key,
    this.showFinancials = true,
    this.hostel = 'boys',
  });
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _announcementController = TextEditingController();

  int _totalStudents = 0;
  int _occupiedRooms = 0;
  int _totalRooms = 0;
  double _occupancyRate = 0;
  double _totalIncome = 0;
  int _pendingComplaints = 0;
  int _resolvedComplaints = 0;
  // ─── "Tushgan arizalar": yangi talaba yotoqxonaga qabul qilinishi —
  // talaba o'zi ro'yxatdan o'tganda ham, admin uni qo'lda qo'shganda
  // ham 'foydalanuvchilar' to'plamiga (role=talaba, hostel=boys)
  // yoziladi, shu sababli davr bo'yicha sanash shu bitta manbadan olinadi.
  int _studentsToday = 0;
  int _studentsThisWeek = 0;
  int _studentsThisMonth = 0;
  bool _isLoading = true;
  String _selectedPeriod = 'month';
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _statsError = null;
    });

    try {
      var students = await _firestore
          .collection('foydalanuvchilar')
          .where('role', isEqualTo: 'talaba')
          .where('hostel', isEqualTo: widget.hostel)
          .get();
      _totalStudents = students.docs.length;

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfWeek =
          startOfToday.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);
      int studentsToday = 0;
      int studentsThisWeek = 0;
      int studentsThisMonth = 0;
      for (final doc in students.docs) {
        final raw = doc.data()['createdAt'];
        DateTime? createdAt;
        if (raw is Timestamp) {
          createdAt = raw.toDate();
        } else if (raw is String) {
          createdAt = DateTime.tryParse(raw);
        }
        if (createdAt == null) continue;
        if (!createdAt.isBefore(startOfMonth)) studentsThisMonth++;
        if (!createdAt.isBefore(startOfWeek)) studentsThisWeek++;
        if (!createdAt.isBefore(startOfToday)) studentsToday++;
      }
      _studentsToday = studentsToday;
      _studentsThisWeek = studentsThisWeek;
      _studentsThisMonth = studentsThisMonth;

      var rooms = await _firestore
          .collection('xonalar')
          .where('hostel', isEqualTo: widget.hostel)
          .get();
      _totalRooms = rooms.docs.length;

      _occupiedRooms = rooms.docs.where((doc) {
        final data = doc.data();

        if (data.containsKey('status') && data['status'] == 'occupied') {
          return true;
        }

        // 🛠️ Eski/moslashmagan yozuvlar uchun himoya: 'status' maydoni
        // hali "empty" bo'lib qolgan bo'lsa ham, agar xona haqiqatda
        // sig'imigacha to'lgan bo'lsa — uni "band" deb hisoblaymiz.
        final int capacity = (data['capacity'] as num?)?.toInt() ?? 0;
        final List studentIdsList = (data['studentIds'] as List?) ?? [];
        final int occupantsCount = studentIdsList.isNotEmpty
            ? studentIdsList.length
            : ((data['currentOccupants'] as num?)?.toInt() ?? 0);
        if (capacity > 0 && occupantsCount >= capacity) {
          return true;
        }

        if (data.containsKey('students')) {
          return (data['students'] as List).isNotEmpty;
        }
        return false;
      }).length;

      _occupancyRate =
          _totalRooms > 0 ? (_occupiedRooms / _totalRooms) * 100 : 0;

      // ⚠️ MUHIM: qizlar yotoqxonasi to'lovlari umumiy 'tolovlar'
      // to'plamiga EMAS, alohida 'girls_payments' to'plamiga yoziladi
      // (qarang: girls_payment_service.dart). Shu sababli bu yerda
      // "Jami daromad" har doim 0.0M so'm bo'lib ko'rinar edi — chunki
      // 'tolovlar'da hostel == 'girls' bo'lgan hech qanday hujjat yo'q.
      // Endi yotoqxona turiga qarab to'g'ri manbadan o'qiymiz.
      if (widget.hostel == 'girls') {
        var girlsPayments = await _firestore.collection('girls_payments').get();
        _totalIncome = girlsPayments.docs.fold(0.0, (sum, doc) {
          final data = doc.data();
          // Faqat haqiqatda TO'LANGAN cheklar "daromad" hisoblanadi —
          // "kutilmoqda"/"muddati o'tgan" holatidagilar hali kelib
          // tushmagan pul, shuning uchun jami daromadga qo'shilmaydi.
          if (data['status'] != 'paid') return sum;
          final amt = data['amount'];
          if (amt is num) return sum + amt.toDouble();
          if (amt is String) return sum + (double.tryParse(amt) ?? 0.0);
          return sum;
        });
      } else {
        var payments = await _firestore
            .collection('tolovlar')
            .where('hostel', isEqualTo: widget.hostel)
            .get();
        _totalIncome = payments.docs.fold(0.0, (sum, doc) {
          final amt = doc.data()['amount'];
          if (amt is num) return sum + amt.toDouble();
          if (amt is String) return sum + (double.tryParse(amt) ?? 0.0);
          return sum;
        });
      }

      var complaints = await _firestore
          .collection('murojaatlar')
          .where('hostel', isEqualTo: widget.hostel)
          .get();
      _pendingComplaints = complaints.docs.where((doc) {
        final data = doc.data();
        return data.containsKey('status') && data['status'] == 'pending';
      }).length;

      _resolvedComplaints = complaints.docs.where((doc) {
        final data = doc.data();
        return data.containsKey('status') && data['status'] == 'resolved';
      }).length;
    } catch (e) {
      debugPrint("Error loading stats: $e");
      _statsError = e.toString();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendAnnouncement() async {
    final String text = _announcementController.text.trim();
    if (text.isEmpty) return;

    try {
      await _firestore.collection('elonlar').add({
        'title': "Mudir e'loni",
        'message': text,
        'hostel': widget.hostel,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _announcementController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _C.bgCard2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.celebration_rounded, color: _C.mint, size: 18),
              SizedBox(width: 10),
              Text("E'lon barcha talabalarga yuborildi!",
                  style: TextStyle(color: _C.white)),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik yuz berdi: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bgBase,
      child: RefreshIndicator(
        onRefresh: _loadStats,
        color: _C.violet,
        backgroundColor: _C.bgCard,
        child: Stack(
          children: [
            // ambient glow decorations
            Positioned(
              top: -60,
              right: -40,
              child: _GlowOrb(color: _C.purple, size: 180),
            ),
            Positioned(
              top: 220,
              left: -60,
              child: _GlowOrb(color: _C.teal, size: 140),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      isWide ? 32 : 16, 20, isWide ? 32 : 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 18),
                          _buildPeriodSelector(),
                          const SizedBox(height: 20),
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.all(48),
                              child: Center(
                                child:
                                    CircularProgressIndicator(color: _C.violet),
                              ),
                            )
                          else ...[
                            if (_statsError != null) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _C.pink.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: _C.pink.withOpacity(0.4)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: _C.pink, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Statistikani yuklab bo'lmadi",
                                            style: TextStyle(
                                                color: _C.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _statsError!,
                                            style: const TextStyle(
                                                color: _C.muted,
                                                fontSize: 11.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            _buildStatsGrid(constraints.maxWidth),
                            const SizedBox(height: 22),
                            _sectionLabel("Tushgan arizalar",
                                Icons.person_add_alt_1_rounded, _C.mint),
                            const SizedBox(height: 4),
                            const Text(
                              "O'zi ro'yxatdan o'tganlar + admin qo'shganlar birgalikda",
                              style: TextStyle(color: _C.muted, fontSize: 11.5),
                            ),
                            const SizedBox(height: 10),
                            _buildNewStudentsGrid(constraints.maxWidth),
                            const SizedBox(height: 24),
                            _buildAnnouncementCard(),
                            const SizedBox(height: 22),
                            _sectionLabel("Bandlik dinamikasi",
                                Icons.donut_large_rounded, _C.orange),
                            const SizedBox(height: 10),
                            _darkFrame(
                                child: BandlikGrafik(
                              hostel: widget.hostel,
                            )),
                            const SizedBox(height: 18),
                            if (widget.showFinancials) ...[
                              _sectionLabel("Daromad hisoboti",
                                  Icons.trending_up_rounded, _C.teal),
                              const SizedBox(height: 10),
                              _darkFrame(
                                  child: DaromadHisobot(
                                period: _selectedPeriod,
                                hostel: widget.hostel,
                              )),
                              const SizedBox(height: 18),
                            ],
                            _sectionLabel("Talabalar statistikasi",
                                Icons.bar_chart_rounded, _C.pink),
                            const SizedBox(height: 10),
                            _darkFrame(
                                child: TalabalarStatistikasi(
                              hostel: widget.hostel,
                            )),
                            if (widget.showFinancials) ...[
                              const SizedBox(height: 18),
                              _sectionLabel("Hisobotni eksport qilish",
                                  Icons.ios_share_rounded, _C.violet),
                              const SizedBox(height: 10),
                              _darkFrame(
                                  child: HisobotEksport(
                                hostel: widget.hostel,
                              )),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Greeting header ──────────────────────────────────────────
  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? "Xayrli tong"
        : hour < 18
            ? "Kun yaxshi o'tsinmi"
            : "Xayrli kech";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [_C.purple, Color(0xFF4A3FA0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _C.purple.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text(
                  "Yotoqxona nazorat paneli",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${_occupancyRate.toStringAsFixed(0)}% bandlik · $_totalStudents talaba",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(Icons.insights_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  // ─── Period selector pill ─────────────────────────────────────
  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.faint),
      ),
      child: Row(
        children: [
          _buildPeriodButton('week', 'Haftalik'),
          _buildPeriodButton('month', 'Oylik'),
          _buildPeriodButton('year', 'Yillik'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String period, String label) {
    bool isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = period);
          _loadStats();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: [_C.purple, _C.violet])
                : null,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : _C.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Stats grid ────────────────────────────────────────────────
  Widget _buildStatsGrid(double maxWidth) {
    final stats = [
      _StatData(
          "Talabalar", "$_totalStudents ta", Icons.groups_rounded, _C.teal),
      _StatData("Band xonalar", "$_occupiedRooms/$_totalRooms",
          Icons.meeting_room_rounded, _C.orange),
      _StatData("Bandlik foizi", "${_occupancyRate.toStringAsFixed(1)}%",
          Icons.donut_small_rounded, _C.pink),
      _StatData(
          "Jami daromad",
          "${(_totalIncome / 1000000).toStringAsFixed(1)}M so'm",
          Icons.payments_rounded,
          _C.mint),
      _StatData("Kutilayotgan", "$_pendingComplaints ta",
          Icons.pending_actions_rounded, _C.coral),
      _StatData("Hal qilingan", "$_resolvedComplaints ta",
          Icons.check_circle_rounded, _C.violet),
    ];

    // Ekran kengayganda kartalar cheksiz katta bo'lib ketmasligi uchun
    // ustunlar sonini moslashuvchan qilamiz.
    final crossAxisCount = maxWidth >= 980 ? 3 : (maxWidth >= 600 ? 3 : 2);

    // ✅ Oldin balandlik "childAspectRatio" orqali kenglikka nisbatan
    // hisoblanardi — oyna/ekran torayganda balandlik ham qisqarib,
    // ichidagi icon+matn sig'may "BOTTOM OVERFLOWED" xatosini berardi.
    // Endi balandlik ekran kengligidan mustaqil, doimiy piksel
    // (mainAxisExtent) qilib belgilangan — kontent uchun har doim
    // yetarli joy bo'ladi.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 114,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) => _DarkStatCard(data: stats[i]),
    );
  }

  // ─── "Tushgan arizalar" grid: kunlik/haftalik/oylik/umumiy yangi
  // talaba soni (o'zi ro'yxatdan o'tganlar + admin qo'shganlar) ────
  Widget _buildNewStudentsGrid(double maxWidth) {
    final stats = [
      _StatData("Bugun", "$_studentsToday ta", Icons.today_rounded, _C.pink),
      _StatData("Shu hafta", "$_studentsThisWeek ta", Icons.view_week_rounded,
          _C.violet),
      _StatData("Shu oy", "$_studentsThisMonth ta",
          Icons.calendar_month_rounded, _C.orange),
      _StatData(
          "Barchasi", "$_totalStudents ta", Icons.all_inbox_rounded, _C.teal),
    ];

    final crossAxisCount = maxWidth >= 980 ? 4 : (maxWidth >= 600 ? 4 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 104,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) => _DarkStatCard(data: stats[i]),
    );
  }

  // ─── Announcement card ─────────────────────────────────────────
  Widget _buildAnnouncementCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.faint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _C.mint.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded,
                    size: 16, color: _C.mint),
              ),
              const SizedBox(width: 10),
              const Text(
                "Talabalarga e'lon yuborish",
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: _C.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: _C.bgCard2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.faint),
            ),
            child: TextField(
              controller: _announcementController,
              maxLines: 3,
              style: const TextStyle(color: _C.white, fontSize: 13.5),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(14),
                hintText:
                    "Navbatchiliklar yoki ichki tartib qoidalarni shu yerga yozib tarqating...",
                border: InputBorder.none,
                hintStyle: TextStyle(color: _C.muted, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _sendAnnouncement,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: [_C.purple, _C.violet]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _C.purple.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.send_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text("E'lonni tarqatish",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
              color: _C.white, fontSize: 14.5, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  // Wraps legacy light-themed chart widgets in a dark, rounded frame so
  // they sit consistently within the creative dashboard shell.
  Widget _darkFrame({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.faint),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          cardColor: _C.bgCard2,
          scaffoldBackgroundColor: _C.bgCard,
          colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: _C.bgCard2,
                primary: _C.violet,
              ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: child,
        ),
      ),
    );
  }
}

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  _StatData(this.title, this.value, this.icon, this.color);
}

class _DarkStatCard extends StatelessWidget {
  final _StatData data;
  const _DarkStatCard({required this.data});

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
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, size: 17, color: data.color),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: data.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: data.color.withOpacity(0.6), blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: const TextStyle(
                color: _C.white, fontSize: 17, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            data.title,
            style: const TextStyle(color: _C.muted, fontSize: 11.5),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.14),
              blurRadius: size * 0.8,
              spreadRadius: size * 0.18,
            ),
          ],
        ),
      ),
    );
  }
}
