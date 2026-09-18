import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class TalabaHujjatlar extends StatefulWidget {
  final String studentId;
  final String studentName;
  const TalabaHujjatlar({super.key, 
    required this.studentId,
    required this.studentName,
  });

  @override
  _TalabaHujjatlarState createState() => _TalabaHujjatlarState();
}

class _TalabaHujjatlarState extends State<TalabaHujjatlar> {
  final ImagePicker _picker = ImagePicker();

  final Map<String, String?> _documents = {
    'student_card': null,
    'payment_receipt': null,
    'medical_certificate': null,
  };

  bool _isLoading = true;
  bool _isUploading = false;

  final Map<String, Map<String, dynamic>> _documentInfo = {
    'student_card': {
      'icon': Icons.credit_card,
      'title': "Talaba guvohnomasi",
      'color': Colors.blue,
    },
    'payment_receipt': {
      'icon': Icons.receipt,
      'title': "To'lov kvitansiyasi",
      'color': Colors.green,
    },
    'medical_certificate': {
      'icon': Icons.health_and_safety,
      'title': "Tibbiy ma'lumotnoma",
      'color': Colors.orange,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  /// Talabaning hujjatlarini yuklaydi.
  ///
  /// Backend uchta hujjat turini qaytaradi: talaba guvohnomasi,
  /// to'lov cheki va tibbiy ma'lumotnoma. Ruxsatni o'zi tekshiradi -
  /// talaba faqat o'zinikini ko'radi.
  Future<void> _loadDocuments() async {
    try {
      final javob =
          await ApiService().get('students/${widget.studentId}/documents');

      final d = javob['data'];
      if (d is Map && mounted) {
        setState(() {
          _documents['student_card'] =
              (d['student_card'] ?? d['student_card_url'])?.toString();
          _documents['payment_receipt'] =
              (d['payment_receipt'] ?? d['payment_receipt_url'])?.toString();
          _documents['medical_certificate'] =
              (d['medical_certificate'] ?? d['medical_certificate_url'])
                  ?.toString();
        });
      }
    } catch (e) {
      debugPrint('Hujjatlarni yuklashda xatolik: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadDocument(String documentType) async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text("Kamera orqali olish"),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(documentType, ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text("Galeriyadan tanlash"),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(documentType, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(String documentType, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() => _isUploading = true);

        // Fayl to'g'ridan-to'g'ri Laravel'ga yuboriladi - Firebase
        // Storage kerak emas. Backend uni saqlaydi va havolasini
        // qaytaradi.
        final file = File(image.path);
        final token = await ApiService.getToken();

        final sorov = http.MultipartRequest(
          'POST',
          Uri.parse(
            '${ApiService.baseUrl}/students/${widget.studentId}/documents',
          ),
        );
        sorov.headers['Accept'] = 'application/json';
        if (token != null) {
          sorov.headers['Authorization'] = 'Bearer $token';
        }
        sorov.fields['document_type'] = documentType;
        sorov.files.add(await http.MultipartFile.fromPath('file', file.path));

        final javob = await http.Response.fromStream(await sorov.send());
        final tana = jsonDecode(javob.body);

        if (javob.statusCode < 200 || javob.statusCode >= 300) {
          final xabar = tana is Map && tana['message'] != null
              ? tana['message'].toString()
              : "Hujjatni yuklab bo'lmadi.";
          throw Exception(xabar);
        }

        // Backend yangilangan havolalar ro'yxatini qaytaradi.
        String? yangiUrl;
        if (tana is Map && tana['data'] is Map) {
          final d = tana['data'] as Map;
          yangiUrl = (d[documentType] ?? d['${documentType}_url'])?.toString();
        }

        if (!mounted) return;

        setState(() {
          if (yangiUrl != null) _documents[documentType] = yangiUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hujjat yuklandi"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Xatolik: ${e.toString().replaceFirst('Exception: ', '')}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewDocument(String url) async {
    // Implement document viewer
    // You can use url_launcher or open a webview
    print("View document: $url");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "${widget.studentName} - Hujjatlar",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _documentInfo.length,
                  itemBuilder: (context, index) {
                    String key = _documentInfo.keys.elementAt(index);
                    Map<String, dynamic> info = _documentInfo[key]!;
                    String? url = _documents[key];

                    return Card(
                      elevation: 3,
                      margin: EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color:
                                    (info['color'] as Color).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                info['icon'],
                                size: 28,
                                color: info['color'],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    info['title'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    url != null ? "Yuklangan ✓" : "Yuklanmagan",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: url != null
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (url != null)
                              IconButton(
                                icon:
                                    Icon(Icons.visibility, color: Colors.blue),
                                onPressed: () => _viewDocument(url),
                              ),
                            IconButton(
                              icon: Icon(
                                url != null ? Icons.refresh : Icons.upload,
                                color: Colors.purple,
                              ),
                              onPressed: () => _uploadDocument(key),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_isUploading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text("Hujjat yuklanmoqda..."),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
