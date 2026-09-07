import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BildirishnomaSozlamalari extends StatefulWidget {
  const BildirishnomaSozlamalari({super.key});

  @override
  _BildirishnomaSozlamalariState createState() =>
      _BildirishnomaSozlamalariState();
}

class _BildirishnomaSozlamalariState extends State<BildirishnomaSozlamalari> {
  bool _pushEnabled = true;
  bool _emailEnabled = true;
  bool _smsEnabled = false;
  bool _paymentReminder = true;
  bool _complaintResponse = true;
  bool _roomChange = true;
  bool _announcements = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool('push_enabled') ?? true;
      _emailEnabled = prefs.getBool('email_enabled') ?? true;
      _smsEnabled = prefs.getBool('sms_enabled') ?? false;
      _paymentReminder = prefs.getBool('payment_reminder') ?? true;
      _complaintResponse = prefs.getBool('complaint_response') ?? true;
      _roomChange = prefs.getBool('room_change') ?? true;
      _announcements = prefs.getBool('elonlar') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_enabled', _pushEnabled);
    await prefs.setBool('email_enabled', _emailEnabled);
    await prefs.setBool('sms_enabled', _smsEnabled);
    await prefs.setBool('payment_reminder', _paymentReminder);
    await prefs.setBool('complaint_response', _complaintResponse);
    await prefs.setBool('room_change', _roomChange);
    await prefs.setBool('elonlar', _announcements);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Sozlamalar saqlandi"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Bildirishnoma sozlamalari"),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Notification Methods
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bildirishnoma usullari",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Push bildirishnomalar"),
                      subtitle: Text("Mobil ilovada xabarlar"),
                      value: _pushEnabled,
                      onChanged: (val) => setState(() => _pushEnabled = val),
                      activeThumbColor: Colors.blue.shade700,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Email xabarlar"),
                      subtitle: Text("Email orqali xabarlar"),
                      value: _emailEnabled,
                      onChanged: (val) => setState(() => _emailEnabled = val),
                      activeThumbColor: Colors.blue.shade700,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("SMS xabarlar"),
                      subtitle: Text("Telefon raqamga SMS"),
                      value: _smsEnabled,
                      onChanged: (val) => setState(() => _smsEnabled = val),
                      activeThumbColor: Colors.blue.shade700,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Notification Types
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bildirishnoma turlari",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("To'lov eslatmasi"),
                      subtitle: Text("Oylik to'lov haqida eslatma"),
                      value: _paymentReminder,
                      onChanged: (val) =>
                          setState(() => _paymentReminder = val),
                      activeThumbColor: Colors.blue.shade700,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Murojaat javobi"),
                      subtitle: Text("Murojaatga javob berilganda"),
                      value: _complaintResponse,
                      onChanged: (val) =>
                          setState(() => _complaintResponse = val),
                      activeThumbColor: Colors.blue.shade700,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Xona o'zgarishi"),
                      subtitle: Text("Xona o'zgartirilganda"),
                      value: _roomChange,
                      onChanged: (val) => setState(() => _roomChange = val),
                      activeThumbColor: Colors.blue.shade700,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Umumiy e'lonlar"),
                      subtitle: Text("Yotoqxona e'lonlari"),
                      value: _announcements,
                      onChanged: (val) => setState(() => _announcements = val),
                      activeThumbColor: Colors.blue.shade700,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.green.shade700,
                ),
                child: Text("Saqlash", style: TextStyle(fontSize: 18)),
              ),
            ),

            SizedBox(height: 16),

            // Reset Info
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Sozlamalar faqat shu qurilmada saqlanadi",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
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
}
