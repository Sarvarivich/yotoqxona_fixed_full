import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/excel_download.dart';

class HisobotEksport extends StatefulWidget {
  final String hostel;

  const HisobotEksport({
    super.key,
    required this.hostel,
  });
  @override
  _HisobotEksportState createState() => _HisobotEksportState();
}

class _HisobotEksportState extends State<HisobotEksport> {
  bool _isExporting = false;
  String _exportType = 'json';
  String _selectedData = 'all';

  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      Map<String, dynamic> exportData = {};

      // Export based on selection
      if (_selectedData == 'all' || _selectedData == 'foydalanuvchilar') {
        QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
            .collection('foydalanuvchilar')
            .where('hostel', isEqualTo: widget.hostel)
            .get();
        exportData['foydalanuvchilar'] =
            usersSnapshot.docs.map((doc) => doc.data()).toList();
      }

      if (_selectedData == 'all' || _selectedData == 'xonalar') {
        QuerySnapshot roomsSnapshot = await FirebaseFirestore.instance
            .collection('xonalar')
            .where('hostel', isEqualTo: widget.hostel)
            .get();
        exportData['xonalar'] =
            roomsSnapshot.docs.map((doc) => doc.data()).toList();
      }

      if (_selectedData == 'all' || _selectedData == 'murojaatlar') {
        QuerySnapshot complaintsSnapshot = await FirebaseFirestore.instance
            .collection('murojaatlar')
            .where('hostel', isEqualTo: widget.hostel)
            .get();
        exportData['murojaatlar'] =
            complaintsSnapshot.docs.map((doc) => doc.data()).toList();
      }

      if (_selectedData == 'all' || _selectedData == 'tolovlar') {
        QuerySnapshot paymentsSnapshot = await FirebaseFirestore.instance
            .collection('tolovlar')
            .where('hostel', isEqualTo: widget.hostel)
            .get();
        exportData['tolovlar'] =
            paymentsSnapshot.docs.map((doc) => doc.data()).toList();
      }

      // Add metadata
      exportData['metadata'] = {
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'totalRecords': _getTotalRecords(exportData),
      };

      // Generate file
      String content;
      String extension;
      String mimeType;

      if (_exportType == 'json') {
        content = const JsonEncoder.withIndent('  ').convert(exportData);
        extension = 'json';
        mimeType = 'application/json';
      } else {
        content = _convertToCSV(exportData);
        extension = 'csv';
        mimeType = 'text/csv';
      }

      // Faylni platformaga mos usulda yuklab olish / ulashish
      final fileName =
          '${widget.hostel}_export_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await downloadExcelBytes(utf8.encode(content), fileName);

      setState(() => _isExporting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ma'lumotlar eksport qilindi"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
      );
    }
  }

  int _getTotalRecords(Map<String, dynamic> data) {
    int total = 0;
    data.forEach((key, value) {
      if (key != 'metadata' && value is List) {
        total += value.length;
      }
    });
    return total;
  }

  String _convertToCSV(Map<String, dynamic> data) {
    StringBuffer csv = StringBuffer();

    for (var entry in data.entries) {
      if (entry.key == 'metadata') continue;

      csv.writeln("\n# ${entry.key.toUpperCase()}");

      List<dynamic> items = entry.value;
      if (items.isEmpty) continue;

      // Get headers
      Set<String> headers = {};
      for (var item in items) {
        if (item is Map) {
          headers.addAll(item.keys.map((k) => k.toString()));
        }
      }

      // Write headers
      csv.writeln(headers.join(','));

      // Write data
      for (var item in items) {
        if (item is Map) {
          List<String> row = [];
          for (var header in headers) {
            var value = item[header];
            if (value != null) {
              String strValue = value.toString();
              if (strValue.contains(',') || strValue.contains('"')) {
                strValue = '"${strValue.replaceAll('"', '""')}"';
              }
              row.add(strValue);
            } else {
              row.add('');
            }
          }
          csv.writeln(row.join(','));
        }
      }
    }

    return csv.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ma'lumotlar eksporti",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Barcha ma'lumotlarni JSON yoki CSV formatida eksport qilish",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 16),

            // Format Selection
            Row(
              children: [
                Text("Format:"),
                SizedBox(width: 12),
                _buildFormatRadio('json', "JSON"),
                SizedBox(width: 16),
                _buildFormatRadio('csv', "CSV"),
              ],
            ),
            SizedBox(height: 16),

            // Data Selection
            Text("Ma'lumotlar:"),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDataChip('all', "Barcha"),
                _buildDataChip('foydalanuvchilar', "Foydalanuvchilar"),
                _buildDataChip('xonalar', "Xonalar"),
                _buildDataChip('murojaatlar', "Murojaatlar"),
                _buildDataChip('tolovlar', "To'lovlar"),
              ],
            ),
            SizedBox(height: 24),

            // Export Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportData,
                icon: _isExporting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.download),
                label: Text(
                  _isExporting ? "Eksport qilinmoqda..." : "Eksport qilish",
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.purple.shade700,
                ),
              ),
            ),

            SizedBox(height: 12),

            // Info
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Eksport qilingan fayl avtomatik ravishda yuklab olinadi va ulashish menyusi ochiladi",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatRadio(String value, String label) {
    return Row(
      children: [
        Radio<String>(
          value: value,
          groupValue: _exportType,
          onChanged: (v) => setState(() => _exportType = v!),
          activeColor: Colors.purple.shade700,
        ),
        Text(label),
      ],
    );
  }

  Widget _buildDataChip(String value, String label) {
    return FilterChip(
      label: Text(label),
      selected: _selectedData == value,
      onSelected: (selected) {
        if (selected) setState(() => _selectedData = value);
      },
      selectedColor: Colors.purple.shade100,
      backgroundColor: Colors.grey.shade200,
    );
  }
}
