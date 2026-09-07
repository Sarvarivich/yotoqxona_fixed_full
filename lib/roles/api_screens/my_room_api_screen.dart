import 'package:flutter/material.dart';
import 'package:yotoqxona/modules/services/api_service.dart';

// ─── Talabaning o'z xonasi (Laravel API asosida) ───
// GET /my-room chaqiradi. Agar talaba hali xonaga biriktirilmagan
// bo'lsa, data null bo'ladi va bu xato emas — mos xabar ko'rsatiladi.
class MyRoomApiScreen extends StatefulWidget {
  const MyRoomApiScreen({super.key});

  @override
  State<MyRoomApiScreen> createState() => _MyRoomApiScreenState();
}

class _MyRoomApiScreenState extends State<MyRoomApiScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _room;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final room = await _api.getMyRoom();
      if (!mounted) return;
      setState(() {
        _room = room;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mening xonam"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
                ? _buildError()
                : _room == null
                    ? _buildNoRoom()
                    : _buildRoom(_room!),
      ),
    );
  }

  Widget _buildError() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.error_outline, color: Colors.red[400], size: 56),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      ],
    );
  }

  Widget _buildNoRoom() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.meeting_room_outlined, color: Colors.grey[400], size: 72),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            "Sizga hali xona biriktirilmagan.\nArizangiz ko'rib chiqilgach, "
            "administratsiya sizni xonaga biriktiradi.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildRoom(Map<String, dynamic> room) {
    final roomNumber = room['room_number']?.toString() ?? '-';
    final floor = room['floor']?.toString() ?? '-';
    final hostelType = room['hostel_type']?.toString() ?? '-';
    final capacity = room['capacity']?.toString() ?? '-';
    final price = room['price_per_month'];
    final assignedAt = room['assigned_at']?.toString();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.meeting_room,
                          color: Colors.indigo, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$roomNumber-xona",
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          hostelType == 'girls'
                              ? "Qizlar yotoqxonasi"
                              : "O'g'il bolalar yotoqxonasi",
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32),
                _infoRow(Icons.layers, "Qavat", floor),
                _infoRow(Icons.groups, "Sig'im", "$capacity kishi"),
                if (price != null)
                  _infoRow(Icons.payments, "Oylik to'lov",
                      "${price.toString()} so'm"),
                if (assignedAt != null)
                  _infoRow(Icons.event_available, "Biriktirilgan sana",
                      assignedAt.split('T').first),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black45),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(color: Colors.black54)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
