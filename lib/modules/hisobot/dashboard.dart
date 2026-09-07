import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'bandlik_grafik.dart';
import 'daromat_hisoboti.dart';
import '../hisobot/daromad_tafsilotlarri.dart';
import 'talabalar_statistikasi.dart';
import 'hisobot_eksport.dart';

// ─── Creative dark palette ───
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
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final ApiService _apiService = ApiService();
  final TextEditingController _announcementController =
      TextEditingController();

  int _totalStudents = 0;

  int _boysStudents = 0;
  int _girlsStudents = 0;

  int _course1 = 0;
  int _course2 = 0;
  int _course3 = 0;
  int _course4 = 0;

  int _totalRooms = 0;
  int _emptyRooms = 0;
  int _partiallyFilledRooms = 0;
  int _fullRooms = 0;
  int _occupiedRooms = 0;

  int _totalCapacity = 0;
  int _occupiedBeds = 0;
  int _availableBeds = 0;

  double _occupancyRate = 0;

  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;

  int _totalPayments = 0;
  int _approvedPayments = 0;
  int _pendingPayments = 0;
  int _rejectedPayments = 0;

  int _totalApplications = 0;
  int _pendingApplications = 0;
  int _approvedApplications = 0;
  int _rejectedApplications = 0;

  int _totalComplaints = 0;
  int _pendingComplaints = 0;
  int _resolvedComplaints = 0;

  // Backend hozir kunlik/haftalik/oylik student statistikani qaytarmaydi.
  // Shu sababli vaqtincha applications ma'lumotlaridan foydalaniladi.
  int _studentsToday = 0;
  int _studentsThisWeek = 0;
  int _studentsThisMonth = 0;

  bool _isLoading = true;
  bool _isSendingAnnouncement = false;

  String _selectedPeriod = 'month';
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // LARAVEL API DAN DASHBOARD MA'LUMOTLARINI OLISH
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _statsError = null;
    });

    try {
      final result = await _apiService.getDashboard();

      final dynamic rawData =
          result['data'] ?? result;

      if (rawData is! Map) {
        throw Exception("Dashboard ma'lumotlari noto'g'ri formatda keldi");
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(rawData);

      final Map<String, dynamic> students =
          _map(data['students']);

      final Map<String, dynamic> rooms =
          _map(data['rooms']);

      final Map<String, dynamic> applications =
          _map(data['applications']);

      final Map<String, dynamic> payments =
          _map(data['payments']);

      final Map<String, dynamic> complaints =
          _map(data['complaints']);

      final Map<String, dynamic> finance =
          _map(data['finance']);

      if (!mounted) return;

      setState(() {
        // ─── STUDENTS ───
        _totalStudents = _toInt(students['total']);

        _boysStudents = _toInt(students['boys']);
        _girlsStudents = _toInt(students['girls']);

        _course1 = _toInt(students['course_1']);
        _course2 = _toInt(students['course_2']);
        _course3 = _toInt(students['course_3']);
        _course4 = _toInt(students['course_4']);

        // ─── ROOMS ───
        _totalRooms = _toInt(rooms['total']);

        _emptyRooms = _toInt(rooms['empty']);

        _partiallyFilledRooms =
            _toInt(rooms['partially_filled']);

        _fullRooms = _toInt(rooms['full']);

        _occupiedRooms =
            _partiallyFilledRooms + _fullRooms;

        _totalCapacity =
            _toInt(rooms['total_capacity']);

        _occupiedBeds =
            _toInt(rooms['occupied_beds']);

        _availableBeds =
            _toInt(rooms['available_beds']);

        _occupancyRate =
            _totalCapacity > 0
                ? (_occupiedBeds / _totalCapacity) * 100
                : 0;

        // ─── APPLICATIONS ───
        _totalApplications =
            _toInt(applications['total']);

        _pendingApplications =
            _toInt(applications['pending']);

        _approvedApplications =
            _toInt(applications['approved']);

        _rejectedApplications =
            _toInt(applications['rejected']);

        // ─── PAYMENTS ───
        _totalPayments =
            _toInt(payments['total_count']);

        _approvedPayments =
            _toInt(payments['approved_count']);

        _pendingPayments =
            _toInt(payments['pending_count']);

        _rejectedPayments =
            _toInt(payments['rejected_count']);

        _totalIncome =
            _toDouble(finance['income']);

        // Agar finance income bo'sh bo'lsa payments dan foydalanamiz
        if (_totalIncome == 0) {
          _totalIncome =
              _toDouble(payments['total_sum']);
        }

        // ─── FINANCE ───
        _totalExpense =
            _toDouble(finance['expense']);

        _balance =
            _toDouble(finance['balance']);

        // ─── COMPLAINTS ───
        _totalComplaints =
            _toInt(complaints['total']);

        _pendingComplaints =
            _toInt(complaints['open']);

        _resolvedComplaints =
            _toInt(complaints['resolved']);

        // ─── TEMPORARY NEW STUDENTS SECTION ───
        // Backend hozir created_today/week/month yubormaydi.
        _studentsToday = 0;
        _studentsThisWeek = 0;
        _studentsThisMonth = 0;

        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Dashboard API error: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _statsError = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is double) return value;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  // ─────────────────────────────────────────────────────────────
  // ANNOUNCEMENT
  // ─────────────────────────────────────────────────────────────

  Future<void> _sendAnnouncement() async {
    final text = _announcementController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Avval e'lon matnini yozing"),
        ),
      );
      return;
    }

    if (_isSendingAnnouncement) return;

    setState(() {
      _isSendingAnnouncement = true;
    });

    try {
     await _apiService.createAnnouncement(
  {
    'title': "Yotoqxona e'loni",
    'message': text,
    'target_hostel': widget.hostel,
    'target_role': 'talaba',
  },
);

      _announcementController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _C.bgCard2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Row(
            children: [
              Icon(
                Icons.celebration_rounded,
                color: _C.mint,
                size: 18,
              ),
              SizedBox(width: 10),
              Text(
                "E'lon muvaffaqiyatli yuborildi!",
                style: TextStyle(color: _C.white),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Announcement error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "E'lon yuborishda xatolik: $e",
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingAnnouncement = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bgBase,
      child: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: _C.violet,
        backgroundColor: _C.bgCard,
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _GlowOrb(
                color: _C.purple,
                size: 180,
              ),
            ),
            Positioned(
              top: 220,
              left: -60,
              child: _GlowOrb(
                color: _C.teal,
                size: 140,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide =
                    constraints.maxWidth > 700;

                return SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 32 : 16,
                    20,
                    isWide ? 32 : 16,
                    32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),

                          const SizedBox(height: 18),

                          _buildPeriodSelector(),

                          const SizedBox(height: 20),

                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.all(48),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: _C.violet,
                                ),
                              ),
                            )
                          else ...[
                            if (_statsError != null) ...[
                              _buildErrorCard(),
                              const SizedBox(height: 18),
                            ],

                            _buildStatsGrid(
                              constraints.maxWidth,
                            ),

                            const SizedBox(height: 22),

                            _sectionLabel(
                              "Tushgan arizalar",
                              Icons.person_add_alt_1_rounded,
                              _C.mint,
                            ),

                            const SizedBox(height: 4),

                            const Text(
                              "Yangi talabalar statistikasi",
                              style: TextStyle(
                                color: _C.muted,
                                fontSize: 11.5,
                              ),
                            ),

                            const SizedBox(height: 10),

                            _buildNewStudentsGrid(
                              constraints.maxWidth,
                            ),

                            const SizedBox(height: 24),

                            _buildAnnouncementCard(),

                            const SizedBox(height: 22),

                            _sectionLabel(
                              "Bandlik dinamikasi",
                              Icons.donut_large_rounded,
                              _C.orange,
                            ),

                            const SizedBox(height: 10),

                            _darkFrame(
                              child: BandlikGrafik(
                                hostel: widget.hostel,
                              ),
                            ),

                            const SizedBox(height: 18),

                            if (widget.showFinancials) ...[
                              _sectionLabel(
                                "Daromad hisoboti",
                                Icons.trending_up_rounded,
                                _C.teal,
                              ),

                              const SizedBox(height: 10),

                              _darkFrame(
                                child: DaromadHisobot(
                                  period: _selectedPeriod,
                                ),
                              ),

                              const SizedBox(height: 18),
                            ],

                            _sectionLabel(
                              "Talabalar statistikasi",
                              Icons.bar_chart_rounded,
                              _C.pink,
                            ),

                            const SizedBox(height: 10),

                            _darkFrame(
                              child: TalabalarStatistikasi(
                                hostel: widget.hostel,
                              ),
                            ),

                            if (widget.showFinancials) ...[
                              const SizedBox(height: 18),

                              _sectionLabel(
                                "Hisobotni eksport qilish",
                                Icons.ios_share_rounded,
                                _C.violet,
                              ),

                              const SizedBox(height: 10),

                              _darkFrame(
                                child: HisobotEksport(
                                  hostel: widget.hostel,
                                ),
                              ),
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

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.pink.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _C.pink.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _C.pink,
            size: 18,
          ),
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
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statsError ?? '',
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _loadDashboard,
                  child: const Text(
                    "Qayta urinish",
                    style: TextStyle(
                      color: _C.violet,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────

  Widget _buildHeader() {
    final hour = DateTime.now().hour;

    final greeting = hour < 12
        ? "Xayrli tong"
        : hour < 18
            ? "Kun yaxshi o'tsin"
            : "Xayrli kech";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            _C.purple,
            Color(0xFF4A3FA0),
          ],
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color:
                        Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  "Yotoqxona nazorat paneli",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${_occupancyRate.toStringAsFixed(0)}% bandlik · $_totalStudents talaba",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    Colors.white.withOpacity(0.3),
              ),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PERIOD SELECTOR ────────────────────────────────────────

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

  Widget _buildPeriodButton(
    String period,
    String label,
  ) {
    final isSelected =
        _selectedPeriod == period;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
          });
        },
        child: AnimatedContainer(
          duration:
              const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      _C.purple,
                      _C.violet,
                    ],
                  )
                : null,
            borderRadius:
                BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color:
                  isSelected ? Colors.white : _C.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  // ─── MAIN STATS ─────────────────────────────────────────────

  Widget _buildStatsGrid(double maxWidth) {
    final stats = [
      _StatData(
        "Talabalar",
        "$_totalStudents ta",
        Icons.groups_rounded,
        _C.teal,
      ),

      _StatData(
        "Band xonalar",
        "$_occupiedRooms/$_totalRooms",
        Icons.meeting_room_rounded,
        _C.orange,
      ),

      _StatData(
        "Bandlik foizi",
        "${_occupancyRate.toStringAsFixed(1)}%",
        Icons.donut_small_rounded,
        _C.pink,
      ),

      _StatData(
        "Jami daromad",
        _formatMoney(_totalIncome),
        Icons.payments_rounded,
        _C.mint,
        onTap: widget.showFinancials
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const DaromadTafsilotlari(),
                  ),
                );
              }
            : null,
      ),

      _StatData(
        "Kutilayotgan",
        "$_pendingComplaints ta",
        Icons.pending_actions_rounded,
        _C.coral,
      ),

      _StatData(
        "Hal qilingan",
        "$_resolvedComplaints ta",
        Icons.check_circle_rounded,
        _C.violet,
      ),
    ];

    final crossAxisCount =
        maxWidth >= 600 ? 3 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 114,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) {
        return _DarkStatCard(
          data: stats[i],
        );
      },
    );
  }

  // ─── APPLICATION / STUDENT GRID ─────────────────────────────

  Widget _buildNewStudentsGrid(double maxWidth) {
    final stats = [
      _StatData(
        "Jami arizalar",
        "$_totalApplications ta",
        Icons.description_rounded,
        _C.pink,
      ),

      _StatData(
        "Kutilmoqda",
        "$_pendingApplications ta",
        Icons.hourglass_top_rounded,
        _C.orange,
      ),

      _StatData(
        "Tasdiqlangan",
        "$_approvedApplications ta",
        Icons.check_circle_rounded,
        _C.mint,
      ),

      _StatData(
        "Rad etilgan",
        "$_rejectedApplications ta",
        Icons.cancel_rounded,
        _C.coral,
      ),
    ];

    final crossAxisCount =
        maxWidth >= 980
            ? 4
            : (maxWidth >= 600 ? 4 : 2);

    return GridView.builder(
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 114,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) {
        return _DarkStatCard(
          data: stats[i],
        );
      },
    );
  }

  // ─── ANNOUNCEMENT ───────────────────────────────────────────

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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      _C.mint.withOpacity(0.16),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  size: 16,
                  color: _C.mint,
                ),
              ),

              const SizedBox(width: 10),

              const Text(
                "Talabalarga e'lon yuborish",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _C.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            decoration: BoxDecoration(
              color: _C.bgCard2,
              borderRadius:
                  BorderRadius.circular(14),
              border:
                  Border.all(color: _C.faint),
            ),
            child: TextField(
              controller:
                  _announcementController,
              maxLines: 3,
              style: const TextStyle(
                color: _C.white,
                fontSize: 13.5,
              ),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.all(14),
                hintText:
                    "Navbatchiliklar yoki ichki tartib qoidalarni shu yerga yozib tarqating...",
                border: InputBorder.none,
                hintStyle: const TextStyle(
                  color: _C.muted,
                  fontSize: 13,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _isSendingAnnouncement
                  ? null
                  : _sendAnnouncement,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      _C.purple,
                      _C.violet,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    if (_isSendingAnnouncement)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(
                        Icons.send_rounded,
                        size: 16,
                        color: Colors.white,
                      ),

                    const SizedBox(width: 8),

                    Text(
                      _isSendingAnnouncement
                          ? "Yuborilmoqda..."
                          : "E'lonni tarqatish",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ────────────────────────────────────────────────

  String _formatMoney(double amount) {
    if (amount >= 1000000) {
      return "${(amount / 1000000).toStringAsFixed(1)}M so'm";
    }

    return "${amount.toStringAsFixed(0)} so'm";
  }

  Widget _sectionLabel(
    String text,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: _C.white,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _darkFrame({
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _C.bgCard,
        borderRadius:
            BorderRadius.circular(20),
        border:
            Border.all(color: _C.faint),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data:
            Theme.of(context).copyWith(
          cardColor: _C.bgCard2,
          scaffoldBackgroundColor:
              _C.bgCard,
          colorScheme:
              Theme.of(context)
                  .colorScheme
                  .copyWith(
                    surface: _C.bgCard2,
                    primary: _C.violet,
                  ),
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(4),
          child: child,
        ),
      ),
    );
  }
}

// ─── STAT DATA ────────────────────────────────────────────────

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  _StatData(
    this.title,
    this.value,
    this.icon,
    this.color, {
    this.onTap,
  });
}

// ─── DARK STAT CARD ───────────────────────────────────────────

class _DarkStatCard extends StatelessWidget {
  final _StatData data;

  const _DarkStatCard({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final tappable =
        data.onTap != null;

    return Material(
      color: Colors.transparent,
      borderRadius:
          BorderRadius.circular(18),
      child: InkWell(
        onTap: data.onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Container(
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.bgCard,
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: tappable
                  ? data.color.withOpacity(0.35)
                  : _C.faint,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color:
                          data.color.withOpacity(0.16),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Icon(
                      data.icon,
                      size: 17,
                      color: data.color,
                    ),
                  ),

                  const Spacer(),

                  if (tappable)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color:
                          data.color.withOpacity(0.7),
                    )
                  else
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: data.color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                data.color.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const Spacer(),

              Text(
                data.value,
                style: const TextStyle(
                  color: _C.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
                overflow:
                    TextOverflow.ellipsis,
              ),

              const SizedBox(height: 3),

              Text(
                data.title,
                style: const TextStyle(
                  color: _C.muted,
                  fontSize: 11.5,
                ),
                overflow:
                    TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── GLOW ORB ─────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({
    required this.color,
    required this.size,
  });

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
              color:
                  color.withOpacity(0.14),
              blurRadius:
                  size * 0.8,
              spreadRadius:
                  size * 0.18,
            ),
          ],
        ),
      ),
    );
  }
}