import 'package:flutter/material.dart';
import 'package:yotoqxona/modules/services/api_service.dart';

// ─── Xonalar boshqaruvi (Laravel API) ───
// Ro'yxat + qo'shish/tahrirlash/o'chirish. RoomController va
// HostelController allaqachon backendda tayyor.
class RoomsManagementApiScreen extends StatefulWidget {
  const RoomsManagementApiScreen({super.key});

  @override
  State<RoomsManagementApiScreen> createState() =>
      _RoomsManagementApiScreenState();
}

class _RoomsManagementApiScreenState extends State<RoomsManagementApiScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<dynamic> _rooms = [];
  List<dynamic> _hostels = [];
  String _hostelTypeFilter = 'all'; // all | boys | girls
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
      final results =
          await Future.wait([_api.getRooms(), _api.getHostels()]);
      if (!mounted) return;
      setState(() {
        _rooms = results[0];
        _hostels = results[1];
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

  List<dynamic> get _filteredRooms {
    final q = _search.text.trim().toLowerCase();
    return _rooms.where((r) {
      final matchesType = _hostelTypeFilter == 'all' ||
          r['hostel_type']?.toString() == _hostelTypeFilter;
      final matchesSearch = q.isEmpty ||
          (r['room_number']?.toString().toLowerCase().contains(q) ?? false);
      return matchesType && matchesSearch;
    }).toList();
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    if (_hostels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Avval yotoqxona (hostel) qo'shilishi kerak — hozircha ro'yxat bo'sh."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RoomFormSheet(
        api: _api,
        hostels: _hostels,
        existing: existing,
      ),
    );

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _deleteRoom(String roomId, String roomNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tasdiqlang"),
        content: Text("$roomNumber-xonani o'chirmoqchimisiz?"),
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
      await _api.deleteRoom(roomId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Xona o'chirildi"), backgroundColor: Colors.green),
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
        title: const Text("Xonalar boshqaruvi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text("Yangi xona"),
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
                      child: Column(
                        children: [
                          TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              hintText: "Xona raqami bo'yicha qidirish...",
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip('all', "Barchasi"),
                                _filterChip('boys', "O'g'il bolalar"),
                                _filterChip('girls', "Qizlar"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filteredRooms.isEmpty
                          ? const Center(child: Text("Xonalar topilmadi"))
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(
                                    bottom: 80, left: 12, right: 12),
                                itemCount: _filteredRooms.length,
                                itemBuilder: (context, index) {
                                  final r = _filteredRooms[index];
                                  final capacity = _toInt(r['capacity']);
                                  final occ = _toInt(r['current_occupants']);
                                  final full = occ >= capacity && capacity > 0;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: full
                                            ? Colors.red.withOpacity(0.15)
                                            : Colors.green.withOpacity(0.15),
                                        child: Icon(
                                          Icons.meeting_room,
                                          color:
                                              full ? Colors.red : Colors.green,
                                        ),
                                      ),
                                      title:
                                          Text("${r['room_number']}-xona"),
                                      subtitle: Text(
                                          "${r['hostel_type'] == 'girls' ? 'Qizlar' : "O'g'il bolalar"} • "
                                          "$occ/$capacity joy • ${r['floor'] ?? '-'}-qavat"),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 20),
                                            onPressed: () => _openForm(
                                                existing: Map<String,
                                                        dynamic>.from(r)),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                size: 20, color: Colors.red),
                                            onPressed: () => _deleteRoom(
                                                r['id'].toString(),
                                                r['room_number'].toString()),
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

  Widget _filterChip(String value, String label) {
    final selected = _hostelTypeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _hostelTypeFilter = value),
      ),
    );
  }
}

// ─── Qo'shish/tahrirlash formasi ───
class _RoomFormSheet extends StatefulWidget {
  final ApiService api;
  final List<dynamic> hostels;
  final Map<String, dynamic>? existing;

  const _RoomFormSheet({
    required this.api,
    required this.hostels,
    this.existing,
  });

  @override
  State<_RoomFormSheet> createState() => _RoomFormSheetState();
}

class _RoomFormSheetState extends State<_RoomFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _roomNumber;
  late final TextEditingController _floor;
  late final TextEditingController _capacity;
  late final TextEditingController _price;
  String? _hostelId;
  String _hostelType = 'boys';
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _roomNumber = TextEditingController(text: e?['room_number']?.toString());
    _floor = TextEditingController(text: e?['floor']?.toString() ?? '1');
    _capacity =
        TextEditingController(text: e?['capacity']?.toString() ?? '4');
    _price = TextEditingController(
        text: e?['price_per_month']?.toString() ?? '');
    _hostelId = e?['hostel_id']?.toString() ?? widget.hostels.first['id'].toString();
    _hostelType = e?['hostel_type']?.toString() ?? 'boys';
  }

  @override
  void dispose() {
    _roomNumber.dispose();
    _floor.dispose();
    _capacity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final body = {
      'hostel_id': _hostelId,
      'room_number': _roomNumber.text.trim(),
      'hostel_type': _hostelType,
      'floor': int.tryParse(_floor.text.trim()) ?? 1,
      'capacity': int.tryParse(_capacity.text.trim()) ?? 1,
      if (_price.text.trim().isNotEmpty)
        'price_per_month': double.tryParse(_price.text.trim()),
    };

    try {
      if (_isEdit) {
        await widget.api.updateRoom(
            widget.existing!['id'].toString(), body);
      } else {
        await widget.api.createRoom(body);
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
                _isEdit ? "Xonani tahrirlash" : "Yangi xona qo'shish",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: "Yotoqxona", border: OutlineInputBorder()),
                initialValue: _hostelId,
                items: widget.hostels.map((h) {
                  return DropdownMenuItem<String>(
                    value: h['id'].toString(),
                    child: Text(h['name']?.toString() ?? h['code'].toString()),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _hostelId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: "Turi", border: OutlineInputBorder()),
                initialValue: _hostelType,
                items: const [
                  DropdownMenuItem(value: 'boys', child: Text("O'g'il bolalar")),
                  DropdownMenuItem(value: 'girls', child: Text("Qizlar")),
                ],
                onChanged: (v) => setState(() => _hostelType = v ?? 'boys'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomNumber,
                decoration: const InputDecoration(
                    labelText: "Xona raqami", border: OutlineInputBorder()),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Majburiy" : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _floor,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "Qavat", border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "Sig'im", border: OutlineInputBorder()),
                      validator: (v) {
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n < 1) return "Kamida 1";
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Oylik narx (so'm)",
                    border: OutlineInputBorder()),
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
