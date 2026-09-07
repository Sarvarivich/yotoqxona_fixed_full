import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      List<int> bytes;
      String extension;

      if (_exportType == 'json') {
        final content = const JsonEncoder.withIndent('  ').convert(exportData);
        bytes = utf8.encode(content);
        extension = 'json';
      } else if (_exportType == 'csv') {
        final content = _convertToCSV(exportData);
        bytes = utf8.encode(content);
        extension = 'csv';
      } else {
        // 📊 Excel (.xlsx): har bir to'plam ('foydalanuvchilar', 'xonalar',
        // 'murojaatlar', 'tolovlar') alohida varaq (sheet) sifatida, ustunlar
        // esa hujjatlardagi maydonlar bo'yicha avtomatik aniqlanadi.
        bytes = _convertToExcel(exportData);
        extension = 'xlsx';
      }

      // Faylni platformaga mos usulda yuklab olish / ulashish
      final fileName = '${widget.hostel}_export_$timestamp.$extension';
      await downloadExcelBytes(bytes, fileName);

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

  // Firestore qiymatini Excel katagiga yozish uchun o'qish qulay matnga
  // o'giradi (Timestamp -> sana-vaqt, List/Map -> JSON matn va h.k.).
  String _cellText(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      final dt = value.toDate();
      String two(int n) => n.toString().padLeft(2, '0');
      return "${two(dt.day)}.${two(dt.month)}.${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
    }
    if (value is List || value is Map) return jsonEncode(value);
    return value.toString();
  }

  // 📊 Barcha eksport qilingan to'plamlarni bitta Excel (.xlsx) faylga,
  // har birini alohida varaqqa (sheet) yozadi. Ustunlar har bir
  // to'plamdagi hujjatlarning barcha maydonlaridan yig'ib olinadi, shu
  // sababli qaysi to'plam (foydalanuvchilar/xonalar/murojaatlar/tolovlar)
  // tanlanishidan qat'iy nazar ishlaydi.
  List<int> _convertToExcel(Map<String, dynamic> data) {
    final workbook = xls.Excel.createExcel();
    bool wroteAnySheet = false;

    for (final entry in data.entries) {
      if (entry.key == 'metadata') continue;
      final items = entry.value;
      if (items is! List || items.isEmpty) continue;

      // Excel varaq nomlari 31 belgidan oshmasligi va ba'zi belgilarni
      // o'z ichiga olmasligi kerak.
      final sheetName =
          entry.key.length > 31 ? entry.key.substring(0, 31) : entry.key;
      final sheet = workbook[sheetName];
      wroteAnySheet = true;

      // Ustun sarlavhalarini shu to'plamdagi barcha hujjatlar
      // maydonlaridan yig'amiz (turli hujjatlarda maydonlar farq qilishi
      // mumkin, masalan ba'zi talabalarda ijtimoiy imtiyoz maydonlari yo'q).
      final headers = <String>{};
      for (final item in items) {
        if (item is Map) headers.addAll(item.keys.map((k) => k.toString()));
      }
      final headerList = headers.toList();

      sheet.appendRow([
        xls.TextCellValue("T/r"),
        ...headerList.map((h) => xls.TextCellValue(h)),
      ]);

      int index = 1;
      for (final item in items) {
        if (item is! Map) continue;
        sheet.appendRow([
          xls.IntCellValue(index),
          ...headerList.map((h) => xls.TextCellValue(_cellText(item[h]))),
        ]);
        index++;
      }
    }

    // Hech qanday ma'lumot bo'lmasa ham, bo'sh fayl o'rniga tushunarli
    // xabar bilan bitta varaq qaytaramiz.
    if (!wroteAnySheet) {
      final sheet = workbook['Ma\'lumotlar'];
      sheet.appendRow([xls.TextCellValue("Eksport uchun ma'lumot topilmadi")]);
    } else if (workbook.tables.containsKey('Sheet1') &&
        !data.keys.contains('Sheet1') &&
        workbook.tables.keys.length >= 2) {
      // Excel.createExcel() avtomatik qo'shadigan bo'sh "Sheet1" varag'ini
      // olib tashlaymiz — bizga faqat haqiqiy ma'lumot varaqlari kerak.
      // (`delete` kamida 2 ta varaq mavjud bo'lgandagina ishlaydi.)
      workbook.delete('Sheet1');
    }

    final bytes = workbook.save();
    return bytes ?? <int>[];
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
              "Barcha ma'lumotlarni JSON, CSV yoki Excel (.xlsx) formatida eksport qilish",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            SizedBox(height: 16),

            // Format Selection
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text("Format:"),
                _buildFormatRadio('json', "JSON"),
                _buildFormatRadio('csv', "CSV"),
                _buildFormatRadio('excel', "Excel (.xlsx)"),
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
