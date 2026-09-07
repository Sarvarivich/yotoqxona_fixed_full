import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';

class XonaTaqsimlash extends StatefulWidget {
  final RoomModel room;
  const XonaTaqsimlash({super.key, required this.room});

  @override
  _XonaTaqsimlashState createState() => _XonaTaqsimlashState();
}

class _XonaTaqsimlashState extends State<XonaTaqsimlash> {
  List<UserModel> _availableStudents = [];
  UserModel? _selectedStudent;
  bool _isLoading = true;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableStudents();
  }

  Future<void> _loadAvailableStudents() async {
    setState(() => _isLoading = true);

    // ⚠️ Muhim tuzatish: avval bu yerda faqat `.where('roomId', isNull:
    // true)` bilan filterlangan edi. Firestore'da bu filtr FAQAT
    // qiymati ANIQ `null` bo'lgan hujjatlarga mos keladi — agar
    // talabaning `roomId` maydoni umuman mavjud bo'lmasa (masalan eski
    // yozuvlar) yoki bo'sh satr `""` bo'lsa (xonadan chiqarilganda ba'zi
    // ekranlar aynan shunday qiymat yozadi — masalan
    // roles/room_assignment_screen.dart), bunday talaba natijada
    // umuman KO'RINMAY qolar edi, garchi u haqiqatda hech qanday
    // xonaga biriktirilmagan bo'lsa ham.
    //
    // Shuning uchun endi barcha "talaba" rolidagi foydalanuvchilar
    // yuklanadi va "biriktirilmagan" holati mijoz tomonida (Dart'da)
    // aniqlanadi — bu null, bo'sh satr va maydon umuman yo'qligi
    // holatlarining barchasini bir xilda "bo'sh" deb hisoblaydi.
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('foydalanuvchilar')
        .where('role', isEqualTo: 'talaba')
        .get();

    _availableStudents = snapshot.docs
        .map((doc) => UserModel.fromJson(doc.data() as Map<String, dynamic>))
        .where((student) => student.roomId == null || student.roomId!.isEmpty)
        .toList();

    setState(() => _isLoading = false);
  }

  Future<void> _assignStudent() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Talabani tanlang"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isAssigning = true);

    try {
      // Update room
      await FirebaseFirestore.instance
          .collection('xonalar')
          .doc(widget.room.id)
          .update({
        'currentOccupants': widget.room.currentOccupants + 1,
        'studentIds': FieldValue.arrayUnion([_selectedStudent!.id]),
        'status': widget.room.currentOccupants + 1 >= widget.room.capacity
            ? RoomStatus.occupied.name
            : widget.room.status.name,
      });

      // Update student
      await FirebaseFirestore.instance
          .collection('foydalanuvchilar')
          .doc(_selectedStudent!.id)
          .update({'roomId': widget.room.id});

      setState(() => _isAssigning = false);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Talaba muvaffaqiyatli biriktirildi"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isAssigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int availableSpaces = widget.room.capacity - widget.room.currentOccupants;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Xonaga talaba biriktirish",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade700,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Room Info Card
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.shade400,
                          Colors.purple.shade700,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              "${widget.room.roomNumber}",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Xona ${widget.room.roomNumber}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "${widget.room.floor}-qavat",
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "Bo'sh joy: $availableSpaces/${widget.room.capacity}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Available Students
                  if (_availableStudents.isEmpty)
                    Container(
                      padding: EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Biriktirish uchun talabalar yo'q",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Barcha talabalar allaqachon xonalarga biriktirilgan",
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadAvailableStudents,
                            icon: Icon(Icons.refresh),
                            label: Text("Qayta yuklash"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Student Selection
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Talabani tanlang",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            DropdownButtonFormField<UserModel>(
                              initialValue: _selectedStudent,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              items: _availableStudents.map((student) {
                                return DropdownMenuItem(
                                  value: student,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.fullName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        student.studentId ?? "ID mavjud emas",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) =>
                                  setState(() => _selectedStudent = value),
                              validator: (value) {
                                if (value == null) return "Talabani tanlang";
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Selected Student Info
                    if (_selectedStudent != null)
                      Card(
                        elevation: 2,
                        color: Colors.green.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.green.shade100,
                                child: Text(
                                  _selectedStudent!.fullName.isNotEmpty
                                      ? _selectedStudent!.fullName[0]
                                          .toUpperCase()
                                      : "?",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Tanlangan talaba",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    Text(
                                      _selectedStudent!.fullName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _selectedStudent!.phoneNumber,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: 24),

                    // Assign Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isAssigning ? null : _assignStudent,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.green.shade700,
                        ),
                        child: _isAssigning
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
                                  Icon(Icons.person_add),
                                  SizedBox(width: 8),
                                  Text(
                                    "Biriktirish",
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],

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
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.blue.shade700,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Talaba biriktirilgandan so'ng, u xona ma'lumotlarini ko'ra oladi",
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
}
