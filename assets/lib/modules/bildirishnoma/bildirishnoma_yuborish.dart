import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> _loadStudents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('foydalanuvchilar')
        .where('role', isEqualTo: 'talaba')
        .get();

    _students = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['fullName'] ?? '',
        'email': data['email'] ?? '',
      };
    }).toList();

    setState(() {});
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

  // 🔥 SAVE TO FIRESTORE
  Future<void> _saveToDatabase() async {
    final users = await FirebaseFirestore.instance.collection('foydalanuvchilar').get();

    for (var user in users.docs) {
      if (_selectedAudience == 'students' && user['role'] != 'talaba') continue;
      if (_selectedAudience == 'specific' && user.id != _selectedStudentId) {
        continue;
      }
      if (_selectedAudience == 'all' ||
          _selectedAudience == 'students' ||
          user.id == _selectedStudentId) {
        await FirebaseFirestore.instance.collection('bildirishnomalar').add({
          'userId': user.id,
          'title': _titleController.text,
          'body': _bodyController.text,
          'type': _selectedType,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
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
