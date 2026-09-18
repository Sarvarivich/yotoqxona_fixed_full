import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/email_service.dart';

class BildirishnomaYuborish extends StatefulWidget {
  const BildirishnomaYuborish({super.key});

  @override
  State<BildirishnomaYuborish> createState() => _BildirishnomaYuborishState();
}

class _BildirishnomaYuborishState extends State<BildirishnomaYuborish> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  String _selectedAudience = 'all';
  String? _selectedStudentId;
  final String _selectedType = 'general';

  List<Map<String, dynamic>> _students = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  final _api = ApiService();

  /// Barcha talabalarni yuklaydi.
  ///
  /// Backend bir so'rovda 100 tadan ko'p bermaydi, shuning uchun
  /// oxirgi sahifagacha aylanamiz.
  Future<void> _loadStudents() async {
    final natija = <Map<String, dynamic>>[];

    try {
      int sahifa = 1;
      int oxirgi = 1;

      do {
        final javob = await _api.get(
          'students?role=talaba&per_page=100&page=$sahifa',
        );

        final royxat = javob['data'];
        if (royxat is List) {
          for (final e in royxat) {
            if (e is! Map) continue;
            natija.add({
              'id': (e['id'] ?? '').toString(),
              'name': (e['full_name'] ?? e['fullName'] ?? '').toString(),
              'email': (e['email'] ?? '').toString(),
            });
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

    if (!mounted) return;
    setState(() => _students = natija);
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      switch (_selectedAudience) {
        case 'all':
          await _sendToAll();
          break;

        case 'students':
          await _sendToStudents();
          break;

        case 'specific':
          await _sendToSpecific();
          break;
      }

      await _saveToDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bildirishnoma yuborildi"),
          backgroundColor: Colors.green,
        ),
      );

      _titleController.clear();
      _bodyController.clear();
      setState(() => _selectedStudentId = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Xatolik: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  // 🔥 ALL USERS
  Future<void> _sendToAll() async {
    for (final user in _students) {
      await EmailService.sendEmail(
        toEmail: user['email'],
        subject: _titleController.text,
        message: _bodyController.text,
      );
    }
  }

  // 🔥 ONLY STUDENTS
  Future<void> _sendToStudents() async {
    for (final student in _students) {
      await EmailService.sendEmail(
        toEmail: student['email'],
        subject: _titleController.text,
        message: _bodyController.text,
      );
    }
  }

  // 🔥 SPECIFIC STUDENT
  Future<void> _sendToSpecific() async {
    final student = _students.firstWhere(
      (s) => s['id'] == _selectedStudentId,
      orElse: () => {},
    );

    if (student['email'] != null && student['email'].toString().isNotEmpty) {
      await EmailService.sendEmail(
        toEmail: student['email'],
        subject: _titleController.text,
        message: _bodyController.text,
      );
    }
  }

  /// Bildirishnomani Laravel'ga saqlaydi.
  ///
  /// Backend har bir bildirishnomani aniq foydalanuvchiga
  /// biriktiradi, shuning uchun tanlangan auditoriya bo'yicha
  /// birma-bir yuboriladi. `is_read` va `created_at` server
  /// tomonda avtomatik to'ldiriladi.
  Future<void> _saveToDatabase() async {
    // Kimga yuborilishini aniqlaymiz.
    final qabul = <String>[];

    if (_selectedAudience == 'specific') {
      if (_selectedStudentId != null && _selectedStudentId!.isNotEmpty) {
        qabul.add(_selectedStudentId!);
      }
    } else {
      // 'all' va 'students' - ikkalasi ham talabalarga yuboriladi.
      // Laravel'da xodimlarga yuborish uchun alohida ro'yxat kerak,
      // hozircha talabalar bilan cheklanamiz.
      for (final s in _students) {
        final id = (s['id'] ?? '').toString();
        if (id.isNotEmpty) qabul.add(id);
      }
    }

    if (qabul.isEmpty) {
      throw Exception('Bildirishnoma uchun qabul qiluvchi topilmadi.');
    }

    var xato = 0;

    for (final userId in qabul) {
      try {
        await _api.post('notifications', body: {
          'user_id': userId,
          'title': _titleController.text.trim(),
          // Backend 'message' maydonini kutadi ('body' emas).
          'message': _bodyController.text.trim(),
          'type': _selectedType,
        });
      } catch (e) {
        xato++;
        debugPrint('Bildirishnoma yuborilmadi ($userId): $e');
      }
    }

    if (xato > 0 && xato == qabul.length) {
      throw Exception('Bildirishnoma yuborilmadi.');
    }

    if (xato > 0) {
      debugPrint('$xato ta bildirishnoma yuborilmadi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bildirishnoma yuborish"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // AUDIENCE
              Row(
                children: [
                  _buildRadio('all', "Barcha"),
                  _buildRadio('students', "Talabalar"),
                  _buildRadio('specific', "Bitta"),
                ],
              ),

              const SizedBox(height: 10),

              // STUDENT SELECT
              if (_selectedAudience == 'specific')
                DropdownButtonFormField<String>(
                  initialValue: _selectedStudentId,
                  items: _students.map((s) {
                    return DropdownMenuItem<String>(
                      value: s['id'],
                      child: Text("${s['name']}"),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedStudentId = v),
                  decoration: const InputDecoration(
                    labelText: "Talaba tanlang",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (_selectedAudience == 'specific' && v == null) {
                      return "Tanlang";
                    }
                    return null;
                  },
                ),

              const SizedBox(height: 10),

              // TITLE
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Sarlavha",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Sarlavha kiriting" : null,
              ),

              const SizedBox(height: 10),

              // BODY
              TextFormField(
                controller: _bodyController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Xabar",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Xabar kiriting" : null,
              ),

              const SizedBox(height: 20),

              // BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendNotification,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Yuborish"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadio(String value, String label) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: _selectedAudience,
          onChanged: (v) => setState(() => _selectedAudience = v!),
        ),
        Text(label),
      ],
    );
  }
}
