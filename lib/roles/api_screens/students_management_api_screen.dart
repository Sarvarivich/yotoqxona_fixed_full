import 'package:flutter/material.dart';
import 'package:yotoqxona/modules/services/api_service.dart';

// ─── Talabalar boshqaruvi (Laravel API) ───
// Ro'yxat, qidiruv, yangi talaba qo'shish, tahrirlash, o'chirish.
class StudentsManagementApiScreen extends StatefulWidget {
  const StudentsManagementApiScreen({super.key});

  @override
  State<StudentsManagementApiScreen> createState() =>
      _StudentsManagementApiScreenState();
}

class _StudentsManagementApiScreenState
    extends State<StudentsManagementApiScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<dynamic> _students = [];
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await _api.getStudents();
      if (!mounted) return;
      setState(() {
        _students = students;
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
  }

  List<dynamic> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _students;
    return _students.where((s) {
      final name = s['name']?.toString().toLowerCase() ?? '';
      final email = s['email']?.toString().toLowerCase() ?? '';
      final phone = s['phone']?.toString().toLowerCase() ?? '';
      return name.contains(q) || email.contains(q) || phone.contains(q);
    }).toList();
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StudentFormSheet(api: _api, existing: existing),
    );
    if (saved == true) await _load();
  }

  Future<void> _deleteStudent(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tasdiqlang"),
        content: Text("$name ni o'chirmoqchimisiz? Bu amalni orqaga qaytarib bo'lmaydi."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Bekor qilish"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("O'chirish", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.deleteStudent(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Talaba o'chirildi"), backgroundColor: Colors.green),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Talabalar (${_students.length})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text("Yangi talaba"),
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
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText: "Ism, email yoki telefon bo'yicha qidirish...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(child: Text("Talabalar topilmadi"))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                    bottom: 80, left: 12, right: 12),
                                itemCount: _filtered.length,
                                itemBuilder: (context, index) {
                                  final s = _filtered[index];
                                  final name = s['name']?.toString() ?? '-';
                                  final email = s['email']?.toString() ?? '';
                                  final phone = s['phone']?.toString();
                                  final faculty = s['faculty']?.toString();

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                        ),
                                      ),
                                      title: Text(name),
                                      subtitle: Text(
                                        [
                                          email,
                                          if (phone != null && phone.isNotEmpty)
                                            phone,
                                          if (faculty != null &&
                                              faculty.isNotEmpty)
                                            faculty,
                                        ].join(' • '),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 20),
                                            onPressed: () => _openForm(
                                                existing: Map<String,
                                                        dynamic>.from(s)),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                size: 20, color: Colors.red),
                                            onPressed: () => _deleteStudent(
                                                s['id'].toString(), name),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Qo'shish/tahrirlash formasi ───
class _StudentFormSheet extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic>? existing;

  const _StudentFormSheet({required this.api, this.existing});

  @override
  State<_StudentFormSheet> createState() => _StudentFormSheetState();
}

class _StudentFormSheetState extends State<_StudentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _faculty;
  late final TextEditingController _course;
  final TextEditingController _password = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString());
    _email = TextEditingController(text: e?['email']?.toString());
    _phone = TextEditingController(text: e?['phone']?.toString());
    _faculty = TextEditingController(text: e?['faculty']?.toString());
    _course = TextEditingController(text: e?['course']?.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _faculty.dispose();
    _course.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (_isEdit) {
        await widget.api.updateStudent(widget.existing!['id'].toString(), {
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'phone': _phone.text.trim(),
          'faculty': _faculty.text.trim(),
          'course': _course.text.trim(),
        });
      } else {
        await widget.api.createStudent({
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'password': _password.text.trim(),
          'password_confirmation': _password.text.trim(),
          'phone': _phone.text.trim(),
          'faculty': _faculty.text.trim(),
          'course': _course.text.trim(),
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? "Talabani tahrirlash" : "Yangi talaba qo'shish",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: "To'liq ism", border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Majburiy" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: "Email", border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Majburiy";
                  if (!v.contains('@')) return "Email noto'g'ri";
                  return null;
                },
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: "Vaqtinchalik parol",
                      border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return "Kamida 8 belgi";
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: "Telefon", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _faculty,
                decoration: const InputDecoration(
                    labelText: "Fakultet", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _course,
                decoration: const InputDecoration(
                    labelText: "Kurs", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isEdit ? "Saqlash" : "Qo'shish"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
