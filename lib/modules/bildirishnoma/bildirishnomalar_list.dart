import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Foydalanuvchining bildirishnomalari.
///
/// Ma'lumot Laravel API'dan olinadi:
///   ro'yxat     -> GET /api/notifications
///   o'qilgan    -> PATCH /api/notifications/{id}/read
///   o'chirish   -> DELETE /api/notifications/{id}
///
/// Backend javobni foydalanuvchi bo'yicha o'zi filtrlaydi — talaba
/// faqat o'z bildirishnomalarini oladi. Shuning uchun [userId] va
/// [hostel] endi filtr uchun emas, faqat moslik uchun saqlangan
/// (chaqiruvchi ekranlar ularni uzatadi).
class BildirishnomalarList extends StatefulWidget {
  final String userId;
  final String hostel;

  const BildirishnomalarList({
    super.key,
    required this.userId,
    required this.hostel,
  });

  @override
  State<BildirishnomalarList> createState() => _BildirishnomalarListState();
}

class _BildirishnomalarListState extends State<BildirishnomalarList> {
  final _api = ApiService();

  // MUHIM: Future initState'da bir marta yaratiladi. build() ichida
  // yaratilsa, har bir qayta chizishda yangi so'rov ketardi.
  late Future<List<Map<String, dynamic>>> _bildirishnomalar;

  @override
  void initState() {
    super.initState();
    _bildirishnomalar = _yukla();
  }

  Future<List<Map<String, dynamic>>> _yukla() async {
    final javob = await _api.get('notifications');

    final xom = javob['data'];
    if (xom is! List) return <Map<String, dynamic>>[];

    final royxat = <Map<String, dynamic>>[];
    for (final e in xom) {
      if (e is Map) royxat.add(Map<String, dynamic>.from(e));
    }

    // Eng yangisidan eng eskisiga.
    royxat.sort((a, b) {
      final sa = DateTime.tryParse((a['created_at'] ?? '').toString());
      final sb = DateTime.tryParse((b['created_at'] ?? '').toString());
      if (sa == null && sb == null) return 0;
      if (sa == null) return 1;
      if (sb == null) return -1;
      return sb.compareTo(sa);
    });

    return royxat;
  }

  Future<void> _qaytaYukla() async {
    if (!mounted) return;
    setState(() {
      _bildirishnomalar = _yukla();
    });
    await _bildirishnomalar;
  }

  // ===================================================================
  // YORDAMCHILAR
  // ===================================================================

  /// Sarlavha: Laravel `title`.
  String _sarlavha(Map<String, dynamic> n) =>
      (n['title'] ?? '').toString().trim();

  /// Matn: Laravel `message` yozadi, eski Firestore `body` yozardi.
  String _matn(Map<String, dynamic> n) =>
      (n['message'] ?? n['body'] ?? '').toString().trim();

  /// O'qilganmi: Laravel `is_read`, eski Firestore `isRead`.
  bool _oqilgan(Map<String, dynamic> n) {
    final v = n['is_read'] ?? n['isRead'];
    return v == true || v == 1 || v?.toString() == '1';
  }

  DateTime _sana(Map<String, dynamic> n) {
    return DateTime.tryParse(
          (n['created_at'] ?? n['createdAt'] ?? '').toString(),
        ) ??
        DateTime.now();
  }

  IconData _belgi(Map<String, dynamic> n) {
    final turi = (n['type'] ?? '').toString();

    if (turi == 'payment' ||
        turi == 'new_payment_check' ||
        turi == 'payment_check_result' ||
        turi == 'payment_reminder') {
      return Icons.payment;
    }
    if (turi == 'complaint') {
      return Icons.report_problem;
    }
    return Icons.notifications_active;
  }

  // ===================================================================
  // AMALLAR
  // ===================================================================

  Future<void> _oqilganDebBelgilash(String id) async {
    if (id.isEmpty) return;
    try {
      await _api.patch('notifications/$id/read');
    } catch (e) {
      debugPrint('Bildirishnomani belgilashda xatolik: $e');
    }
  }

  Future<void> _ochirish(String id) async {
    if (id.isEmpty) return;
    try {
      await _api.delete('notifications/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bildirishnoma o'chirildi")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("O'chirib bo'lmadi: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Xato bo'lsa ro'yxatni tiklaymiz — element qaytib keladi.
      await _qaytaYukla();
    }
  }

  // ===================================================================
  // KO'RINISH
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bildirishnomalar"),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _qaytaYukla,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bildirishnomalar,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "Xatolik: ${snapshot.error}",
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _qaytaYukla,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: _qaytaYukla,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Icon(Icons.notifications_none, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      "Bildirishnomalar yo'q",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      "Yangi bildirishnomalar kelganda bu yerda ko'rinadi",
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _qaytaYukla,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final id = (notification['id'] ?? '').toString();
                final isRead = _oqilgan(notification);

                return Dismissible(
                  key: Key(id.isNotEmpty ? id : 'n$index'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) async {
                    // Ro'yxatdan darhol olib tashlaymiz, so'ng serverga
                    // so'rov yuboramiz. Xato bo'lsa _ochirish() ro'yxatni
                    // qayta yuklaydi.
                    notifications.removeAt(index);
                    await _ochirish(id);
                  },
                  child: Card(
                    elevation: isRead ? 1 : 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: isRead ? Colors.grey.shade50 : Colors.white,
                    child: InkWell(
                      onTap: () async {
                        if (!isRead) {
                          await _oqilganDebBelgilash(id);
                          if (!mounted) return;
                          // Nuqtani darhol o'chiramiz — server javobini
                          // kutib o'tirmaymiz.
                          setState(() => notification['is_read'] = true);
                        }
                        if (!mounted) return;
                        _showNotificationDialog(context, notification);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        leading: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: isRead
                                ? Colors.grey.shade200
                                : Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _belgi(notification),
                            color: isRead ? Colors.grey : Colors.blue.shade700,
                          ),
                        ),
                        title: Text(
                          _sarlavha(notification),
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _matn(notification),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(_sana(notification)),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: !isRead
                            ? Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return "${date.day}.${date.month}.${date.year}";
    } else if (difference.inDays > 0) {
      return "${difference.inDays} kun oldin";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} soat oldin";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minut oldin";
    } else {
      return "Hozirgina";
    }
  }

  void _showNotificationDialog(
      BuildContext context, Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(_sarlavha(notification))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _matn(notification),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              _formatDate(_sana(notification)),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Yopish"),
          ),
        ],
      ),
    );
  }
}
