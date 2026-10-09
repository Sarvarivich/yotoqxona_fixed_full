import 'package:flutter/material.dart';
import 'package:yotoqxona/modules/services/api_service.dart';
import 'package:yotoqxona/modules/bildirishnoma/bildirishnomalar_list.dart';

// ─── Superadmin umumiy dashboard (Laravel API) ───
// GET /dashboard: statistika. GET /notifications: so'nggi bildirishnomalar
// (parol o'zgarishi haqidagi xabarlar ham shu yerda chiqadi).
class SuperadminDashboardApiScreen extends StatefulWidget {
  const SuperadminDashboardApiScreen({super.key});

  @override
  State<SuperadminDashboardApiScreen> createState() =>
      _SuperadminDashboardApiScreenState();
}

class _SuperadminDashboardApiScreenState
    extends State<SuperadminDashboardApiScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  // So'nggi bildirishnomalar bo'limi uchun
  List<Map<String, dynamic>> _bildirishnomalar = [];
  static const int _korsatiladi = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.getDashboard();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Xatolik: $e";
        _loading = false;
      });
    }

    // Bildirishnomalar dashboard'ni to'xtatmasin: xato bo'lsa bo'lim bo'sh qoladi.
    await _yuklaBildirishnomalar();
  }

  Future<void> _yuklaBildirishnomalar() async {
    try {
      final javob = await _api.get('notifications');
      final xom = javob['data'];
      final royxat = <Map<String, dynamic>>[];
      if (xom is List) {
        for (final e in xom) {
          if (e is Map) royxat.add(Map<String, dynamic>.from(e));
        }
      }
      royxat.sort((a, b) {
        final sa = DateTime.tryParse((a['created_at'] ?? '').toString());
        final sb = DateTime.tryParse((b['created_at'] ?? '').toString());
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sb.compareTo(sa);
      });
      if (!mounted) return;
      setState(() => _bildirishnomalar = royxat);
    } catch (_) {
      // Jim qolamiz: dashboard ishlashda davom etadi.
    }
  }

  void _barchasiniOchish() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BildirishnomalarList(userId: '', hostel: ''),
      ),
    );
  }

  num _n(Map? m, String key) {
    if (m == null) return 0;
    final v = m[key];
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '0') ?? 0;
  }

  String _sana(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    final l = d.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return "${two(l.day)}.${two(l.month)}.${l.year} ${two(l.hour)}:${two(l.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Umumiy dashboard"),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _load,
                            child: const Text("Qayta urinish")),
                      ],
                    ),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final students = _data['students'] as Map?;
    final rooms = _data['rooms'] as Map?;
    final applications = _data['applications'] as Map?;
    final assignments = _data['assignments'] as Map?;
    final payments = _data['payments'] as Map?;
    final hostels = _data['hostels'] as Map?;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _bildirishnomaBolimi(),
          const SizedBox(height: 20),

          if (students != null || rooms != null) ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                if (students != null)
                  _statCard(
                    icon: Icons.school,
                    color: Colors.indigo,
                    title: "Talabalar",
                    value: "${_n(students, 'total').toInt()}",
                  ),
                if (hostels != null)
                  _statCard(
                    icon: Icons.apartment,
                    color: Colors.teal,
                    title: "Yotoqxonalar",
                    value:
                        "${_n(hostels, 'active').toInt()}/${_n(hostels, 'total').toInt()}",
                  ),
                if (rooms != null)
                  _statCard(
                    icon: Icons.meeting_room,
                    color: Colors.orange,
                    title: "Xonalar bandligi",
                    value:
                        "${_n(rooms, 'occupied').toInt()}/${_n(rooms, 'capacity').toInt()}",
                    subtitle: "${_n(rooms, 'occupancy_percent')}%",
                  ),
                if (assignments != null)
                  _statCard(
                    icon: Icons.assignment_turned_in,
                    color: Colors.purple,
                    title: "Faol biriktirishlar",
                    value: "${_n(assignments, 'active').toInt()}",
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (applications != null) ...[
            const Text("Arizalar",
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat("Jami", _n(applications, 'total'), Colors.black87),
                _miniStat(
                    "Kutilmoqda", _n(applications, 'pending'), Colors.orange),
                _miniStat("Tasdiqlangan", _n(applications, 'approved'),
                    Colors.green),
                _miniStat(
                    "Rad etilgan", _n(applications, 'rejected'), Colors.red),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (payments != null) ...[
            const Text("To'lovlar",
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat("Kutilmoqda", _n(payments, 'pending'), Colors.orange),
                _miniStat(
                    "Tasdiqlangan", _n(payments, 'approved'), Colors.green),
                _miniStat("Rad etilgan", _n(payments, 'rejected'), Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.indigo.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _amountRow("Jami tushum",
                        _n(payments, 'approved_amount')),
                    _amountRow(
                        "Kutilayotgan summa", _n(payments, 'pending_amount')),
                    _amountRow("Umumiy (barcha holat)",
                        _n(payments, 'total_amount')),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Alohida bo'lim: so'nggi bildirishnomalar va "Barchasi" tugmasi.
  Widget _bildirishnomaBolimi() {
    final korsatish = _bildirishnomalar.take(_korsatiladi).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active,
                    color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Bildirishnomalar",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: _barchasiniOchish,
                  child: const Text("Barchasi"),
                ),
              ],
            ),
            const Divider(),
            if (korsatish.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "Bildirishnomalar yo'q",
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ...korsatish.map((n) {
                final oqilgan = n['is_read'] == true || n['is_read'] == 1;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    oqilgan ? Icons.notifications_none : Icons.notifications,
                    color: oqilgan ? Colors.grey : Colors.indigo,
                  ),
                  title: Text(
                    (n['title'] ?? '').toString(),
                    style: TextStyle(
                      fontWeight:
                          oqilgan ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    "${(n['message'] ?? '').toString()}\n${_sana(n['created_at']?.toString())}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  onTap: _barchasiniOchish,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (subtitle != null)
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, num value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text("${value.toInt()}",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _amountRow(String label, num amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text("${amount.toInt()} so'm",
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}