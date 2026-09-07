import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';

class XonaTahrirlash extends StatefulWidget {
  final RoomModel room;
  const XonaTahrirlash({super.key, required this.room});

  @override
  _XonaTahrirlashState createState() => _XonaTahrirlashState();
}

class _XonaTahrirlashState extends State<XonaTahrirlash> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  RoomStatus _selectedStatus = RoomStatus.empty;
  List<String> _selectedAmenities = [];
  bool _isLoading = false;
  
  final List<String> _availableAmenities = [
    'WiFi',
    'Konditsioner',
    'TV',
    'Muzlatgich',
    'Hammom',
    'Balkon',
    'Mebellar',
    "To'shak",
    'Shkaf',
    'Stol',
    'Stul',
    'Isitish',
  ];

  @override
  void initState() {
    super.initState();
    _priceController.text = widget.room.pricePerMonth.toString();
    _capacityController.text = widget.room.capacity.toString();
    _selectedStatus = widget.room.status;
    _selectedAmenities = List.from(widget.room.amenities);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _updateRoom() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      await FirebaseFirestore.instance
          .collection('xonalar')
          .doc(widget.room.id)
          .update({
            'pricePerMonth': double.parse(_priceController.text),
            'capacity': int.parse(_capacityController.text),
            'status': _selectedStatus.name,
            'amenities': _selectedAmenities,
          });
      
      setState(() => _isLoading = false);
      
      final updatedRoom = widget.room.copyWith(
        pricePerMonth: double.parse(_priceController.text),
        capacity: int.parse(_capacityController.text),
        status: _selectedStatus,
        amenities: List<String>.from(_selectedAmenities),
        updatedAt: DateTime.now(),
      );
      
      if (mounted) {
        Navigator.pop(context, updatedRoom);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Xona ma'lumotlari yangilandi"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteRoom() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Xonani o'chirish"),
        content: Text(
          "Xona ${widget.room.roomNumber} ni o'chirmoqchimisiz?\n\n"
          "Diqqat! Bu xonada turgan talabalar ham o'chiriladi!",
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
              
              // Remove roomId from all students in this room
              if (widget.room.studentIds.isNotEmpty) {
                for (String studentId in widget.room.studentIds) {
                  await FirebaseFirestore.instance
                      .collection('foydalanuvchilar')
                      .doc(studentId)
                      .update({'roomId': null});
                }
              }
              
              // Delete room
              await FirebaseFirestore.instance
                  .collection('xonalar')
                  .doc(widget.room.id)
                  .delete();
              
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Close edit screen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Xona o'chirildi"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("O'chirish"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Xona ${widget.room.roomNumber} - Tahrirlash",
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
              // Room Number Display
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade400, Colors.purple.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      "${widget.room.roomNumber}",
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "${widget.room.floor}-qavat",
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Capacity Field
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Sig'imi (kishi soni)",
                  prefixIcon: Icon(Icons.people),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Sig'imni kiriting";
                  }
                  int? capacity = int.tryParse(value);
                  if (capacity == null || capacity < 1 || capacity > 10) {
                    return "Sig'im 1-10 oralig'ida bo'lishi kerak";
                  }
                  if (capacity < widget.room.currentOccupants) {
                    return "Sig'im hozirgi bandlikdan kichik bo'lishi mumkin emas";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Price Field
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Oylik to'lov (so'm)",
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "To'lov miqdorini kiriting";
                  }
                  if (double.tryParse(value) == null) {
                    return "Faqat raqam kiriting";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              
              // Status Dropdown
              DropdownButtonFormField<RoomStatus>(
                initialValue: _selectedStatus,
                decoration: InputDecoration(
                  labelText: "Xona holati",
                  prefixIcon: Icon(Icons.info_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: RoomStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(_getStatusText(status)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedStatus = value!),
              ),
              SizedBox(height: 16),
              
              // Amenities Selection
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        "Qulayliklar",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Divider(height: 0),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableAmenities.map((amenity) {
                          return FilterChip(
                            label: Text(amenity),
                            selected: _selectedAmenities.contains(amenity),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedAmenities.add(amenity);
                                } else {
                                  _selectedAmenities.remove(amenity);
                                }
                              });
                            },
                            selectedColor: Colors.purple.shade100,
                            backgroundColor: Colors.grey.shade200,
                            labelStyle: TextStyle(fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              
              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateRoom,
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
                  onPressed: _isLoading ? null : _deleteRoom,
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
                      Text("Xonani o'chirish", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              
              // Warning for occupied rooms
              if (widget.room.currentOccupants > 0 && _selectedStatus == RoomStatus.renovation)
                Container(
                  margin: EdgeInsets.only(top: 16),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Bu xonada ${widget.room.currentOccupants} ta talaba turibdi. "
                          "Ta'mirlash holatiga o'tkazishdan oldin ularni boshqa xonalarga ko'chirishingiz kerak.",
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty: return Colors.green;
      case RoomStatus.occupied: return Colors.blue;
      case RoomStatus.paymentPending: return Colors.orange;
      case RoomStatus.renovation: return Colors.red;
    }
  }

  String _getStatusText(RoomStatus status) {
    switch (status) {
      case RoomStatus.empty: return "Bo'sh";
      case RoomStatus.occupied: return "Band";
      case RoomStatus.paymentPending: return "To'lov kutilmoqda";
      case RoomStatus.renovation: return "Ta'mirlashda";
    }
  }
}