import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';

class XonaQoshish extends StatefulWidget {
  final String hostel;

  const XonaQoshish({
    super.key,
    this.hostel = 'boys',
  });

  @override
  State<XonaQoshish> createState() => _XonaQoshishState();
}

class _XonaQoshishState extends State<XonaQoshish> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _floorController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();

  final List<String> _selectedAmenities = [];
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
  void dispose() {
    _roomNumberController.dispose();
    _floorController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _addRoom() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      RoomModel newRoom = RoomModel(
        id: '',
        roomNumber: int.parse(_roomNumberController.text),
        floor: int.parse(_floorController.text),
        capacity: int.parse(_capacityController.text),
        currentOccupants: 0,
        status: RoomStatus.empty,
        hostel: widget.hostel,
        pricePerMonth: double.parse(_priceController.text),
        amenities: _selectedAmenities,
        studentIds: [],
        createdAt: DateTime.now(),
      );

      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('xonalar')
          .add(newRoom.toJson());
      await docRef.update({'id': docRef.id});

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Xona muvaffaqiyatli qo'shildi"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.hostel == 'girls'
              ? "Qizlar yotoqxonasi - Yangi xona"
              : "O'g'il bolalar yotoqxonasi - Yangi xona",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
              // Header Icon
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.meeting_room,
                  size: 50,
                  color: Colors.purple.shade700,
                ),
              ),
              SizedBox(height: 24),

              // Room Number Field
              TextFormField(
                controller: _roomNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Xona raqami",
                  hintText: "Masalan: 101",
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Xona raqamini kiriting";
                  }
                  if (int.tryParse(value) == null) {
                    return "Faqat raqam kiriting";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Floor Field
              TextFormField(
                controller: _floorController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Qavat",
                  hintText: "Masalan: 1",
                  prefixIcon: Icon(Icons.stairs),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Qavatni kiriting";
                  }
                  if (int.tryParse(value) == null) {
                    return "Faqat raqam kiriting";
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Capacity Field
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Sig'imi (kishi soni)",
                  hintText: "Masalan: 4",
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
                  if (capacity == null) {
                    return "Faqat raqam kiriting";
                  }
                  if (capacity < 1 || capacity > 10) {
                    return "Sig'im 1-10 oralig'ida bo'lishi kerak";
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
                  hintText: "Masalan: 500000",
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
                            labelStyle: TextStyle(
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addRoom,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.purple.shade700,
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

              // Info Card
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: Colors.blue.shade700),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Xona qo'shilgandan so'ng, unga talabalarni biriktirishingiz mumkin",
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade700),
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
}
