import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class TalabaTahrirlash extends StatefulWidget {
  final UserModel student;
  const TalabaTahrirlash({super.key, required this.student});

  @override
  _TalabaTahrirlashState createState() => _TalabaTahrirlashState();
}

class _TalabaTahrirlashState extends State<TalabaTahrirlash> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _studentIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.student.fullName;
    _phoneController.text = widget.student.phoneNumber;
    _studentIdController.text = widget.student.studentId ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _updateStudent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await _apiService.updateStudent(widget.student.id, {
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'passport_id': _studentIdController.text.trim().isEmpty
              ? null
              : _studentIdController.text.trim(),
        });

        setState(() => _isLoading = false);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Talaba ma'lumotlari yangilandi"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Xatolik: $e"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Talaba ma'lumotlarini tahrirlash",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Student Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.student.fullName.isNotEmpty
                        ? widget.student.fullName[0].toUpperCase()
                        : "?",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Full Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "To'liq ism",
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Ismni kiriting";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Email (read-only)
              TextFormField(
                initialValue: widget.student.email,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              SizedBox(height: 16),

              // Phone Number Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Telefon raqam",
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Telefon raqamni kiriting";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Student ID Field
              TextFormField(
                controller: _studentIdController,
                decoration: InputDecoration(
                  labelText: "Talaba ID",
                  prefixIcon: Icon(Icons.school_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              SizedBox(height: 24),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateStudent,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.green.shade700,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text("Saqlash", style: TextStyle(fontSize: 18)),
                          ],
                        ),
                ),
              ),

              SizedBox(height: 16),

              // Delete Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _showDeleteDialog,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete),
                      SizedBox(width: 8),
                      Text(
                        "Talabani o'chirish",
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteStudent() async {
    try {
      await _apiService.deleteStudent(widget.student.id);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context, true); // Close edit screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Talaba o'chirildi"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("O'chirishda xatolik: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Talabani o'chirish"),
        content: Text(
          "${widget.student.fullName} ni tizimdan o'chirmoqchimisiz?\n\nBu amalni qaytarib bo'lmaydi!",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              await _deleteStudent();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("O'chirish"),
          ),
        ],
      ),
    );
  }
}
