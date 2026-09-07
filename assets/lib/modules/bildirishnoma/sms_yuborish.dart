import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SmsYuborish extends StatefulWidget {
  const SmsYuborish({super.key});

  @override
  State<SmsYuborish> createState() => _SmsYuborishState();
}

class _SmsYuborishState extends State<SmsYuborish> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedRecipient = 'manual';
  String? _selectedStudentId;

  List<Map<String, dynamic>> _students = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .where('role', isEqualTo: 'talaba')
          .get();

      _students = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['fullName'] ?? '',
          'phone': data['phoneNumber'] ?? '',
        };
      }).toList();

      setState(() {});
    } catch (e) {
      debugPrint("Student load error: $e");
    }
  }

  Future<void> _sendSMS() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String phoneNumber = '';

    if (_selectedRecipient == 'manual') {
      phoneNumber = _phoneController.text.trim();
    } else {
      final student = _students.firstWhere(
        (s) => s['id'] == _selectedStudentId,
        orElse: () => {},
      );

      phoneNumber = student['phone'] ?? '';
    }

    try {
      // 🔥 REAL SMS API shu yerga ulanadi
      debugPrint("SMS YUBORILDI");
      debugPrint("To: $phoneNumber");
      debugPrint("Message: ${_messageController.text}");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("SMS yuborildi"),
          backgroundColor: Colors.green,
        ),
      );

      _phoneController.clear();
      _messageController.clear();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SMS yuborish"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // RECIPIENT SELECT
              Row(
                children: [
                  Radio<String>(
                    value: 'manual',
                    groupValue: _selectedRecipient,
                    onChanged: (v) {
                      setState(() => _selectedRecipient = v!);
                    },
                  ),
                  const Text("O‘zim yozaman"),
                  Radio<String>(
                    value: 'student',
                    groupValue: _selectedRecipient,
                    onChanged: (v) {
                      setState(() => _selectedRecipient = v!);
                    },
                  ),
                  const Text("Talaba"),
                ],
              ),

              const SizedBox(height: 10),

              // PHONE INPUT
              if (_selectedRecipient == 'manual')
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Telefon raqam",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (_selectedRecipient == 'manual' &&
                        (v == null || v.isEmpty)) {
                      return "Telefon kiriting";
                    }
                    return null;
                  },
                ),

              const SizedBox(height: 10),

              // STUDENT DROPDOWN (FIXED)
              if (_selectedRecipient == 'student')
                DropdownButtonFormField<String>(
                  initialValue: _selectedStudentId,
                  decoration: const InputDecoration(
                    labelText: "Talaba tanlang",
                    border: OutlineInputBorder(),
                  ),
                  items: _students
                      .where((s) => s['id'] != null)
                      .map<DropdownMenuItem<String>>((s) {
                    final id = s['id'] as String;
                    final name = s['name'] ?? '';
                    final phone = s['phone'] ?? '';

                    return DropdownMenuItem<String>(
                      value: id,
                      child: Text("$name - $phone"),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() => _selectedStudentId = v);
                  },
                  validator: (v) {
                    if (_selectedRecipient == 'student' && v == null) {
                      return "Talabani tanlang";
                    }
                    return null;
                  },
                ),

              const SizedBox(height: 10),

              // MESSAGE
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "SMS matni",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? "Matn kiriting" : null,
              ),

              const SizedBox(height: 20),

              // SEND BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendSMS,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.all(14),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SMS yuborish"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
