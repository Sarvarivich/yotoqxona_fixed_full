import 'package:flutter/material.dart';
import 'package:yotoqxona/modules/services/api_service.dart';

// Parol o'zgartirilgan foydalanuvchilar ro'yxati (faqat superAdmin uchun).
// Ma'lumot GET /api/notifications dan olinadi, faqat type == 'password_changed'.
// Bu widget o'zining AppBar'iga ega emas: sarlavha qobiq (admin_screen) tomonidan ko'rsatiladi.

class _C {
  static const bgBase = Color(0xFF0F0D1A);
  static const bgCard = Color(0xFF1A1730);
  static const purple = Color(0xFF6C5CE7);
  static const violet = Color(0xFFa29bfe);
  static const pink = Color(0xFFfd79a8);
  static const white = Color(0xFFFFFFFF);
  static const soft = Color(0xB3FFFFFF);
  static const muted = Color(0x66FFFFFF);
  static const faint = Color(0x0FFFFFFF);
}

class ParolOzgarishlari extends StatefulWidget {
  const ParolOzgarishlari({super.key});

  @override
  State<ParolOzgarishlari> createState() => _ParolOzgarishlariState();
}

class _ParolOzgarishlariState extends State<ParolOzgarishlari> {
  final _api = ApiService();
  bool _loading = true;
  String? _xato;
  List<Map<String, dynamic>> _royxat = [];

  @override
  void initState() {
    super.initState();
    _yukla();
  }

  Future<void> _yukla() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _xato = null;
      });
    }
    try {
      final javob = await _api.get('notifications');
      final xom = javob['data'];
      final natija = <Map<String, dynamic>>[];
      if (xom is List) {
        for (final e in xom) {
          if (e is Map && e['type'] == 'password_changed') {
            natija.add(Map<String, dynamic>.from(e));
          }
        }
      }
      natija.sort((a, b) => _sanaOl(b).compareTo(_sanaOl(a)));
      if (!mounted) return;
      setState(() {
        _royxat = natija;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _xato = e.toString();
        _loading = false;
      });
    }
  }

  // Server vaqti UTC (timestamp without timezone). Mahalliy vaqtga o'tkazamiz.
  DateTime _sanaOl(Map<String, dynamic> e) {
    final s = (e['created_at'] ?? '').toString();
    if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    try {
      var iso = s.contains(' ') ? s.replaceFirst(' ', 'T') : s;
      if (!iso.endsWith('Z') && !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(iso)) {
        iso = '${iso}Z';
      }
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _sanaMatni(Map<String, dynamic> e) {
    final d = _sanaOl(e);
    if (d.millisecondsSinceEpoch == 0) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bgBase,
      child: RefreshIndicator(
        color: _C.violet,
        onRefresh: _yukla,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _C.violet))
            : _xato != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Icon(Icons.error_outline_rounded,
                          size: 56, color: _C.pink),
                      const SizedBox(height: 12),
                      Text(
                        "Ma'lumotni yuklab bo'lmadi",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _C.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _xato!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _C.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: _yukla,
                          child: const Text("Qayta urinish"),
                        ),
                      ),
                    ],
                  )
                : _royxat.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          Icon(Icons.lock_reset_rounded,
                              size: 56, color: _C.muted),
                          const SizedBox(height: 12),
                          Text(
                            "Hozircha parol o'zgarishlari yo'q",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _C.muted, fontSize: 14),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _royxat.length,
                        itemBuilder: (context, index) {
                          final e = _royxat[index];
                          final satrlar = (e['message'] ?? '')
                              .toString()
                              .split('\n')
                              .where((s) => s.trim().isNotEmpty)
                              .toList();
                          final sarlavha = (e['title'] ?? '').toString();
                          final tafsilot = satrlar.isEmpty
                              ? ''
                              : (satrlar.first == sarlavha
                                  ? satrlar.skip(1).join('\n')
                                  : satrlar.join('\n'));
                          final sana = _sanaMatni(e);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _C.bgCard,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: _C.faint),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _C.purple.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.key_rounded,
                                      color: _C.violet, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sarlavha.isEmpty
                                            ? "Parol o'zgartirildi"
                                            : sarlavha,
                                        style: const TextStyle(
                                          color: _C.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      if (tafsilot.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          tafsilot,
                                          style: TextStyle(
                                              color: _C.soft, fontSize: 12),
                                        ),
                                      ],
                                      if (sana.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          sana,
                                          style: TextStyle(
                                              color: _C.muted, fontSize: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
