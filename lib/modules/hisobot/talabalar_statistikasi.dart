import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class TalabalarStatistikasi extends StatefulWidget {
  final String hostel;

  const TalabalarStatistikasi({
    super.key,
    required this.hostel,
  });

  @override
  _TalabalarStatistikasiState createState() => _TalabalarStatistikasiState();
}

class _TalabalarStatistikasiState extends State<TalabalarStatistikasi> {
  final Map<String, int> _facultyStats = {};
  final Map<int, int> _courseStats = {};
  int _totalStudents = 0;
  int _studentsWithRoom = 0;
  int _studentsWithoutRoom = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _facultyStats.clear();
    _courseStats.clear();

    _totalStudents = 0;
    _studentsWithRoom = 0;
    _studentsWithoutRoom = 0;
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('foydalanuvchilar')
        .where('role', isEqualTo: 'talaba')
        .where('hostel', isEqualTo: widget.hostel)
        .get();

    _totalStudents = snapshot.docs.length;

    for (var doc in snapshot.docs) {
      UserModel student =
          UserModel.fromJson(doc.data() as Map<String, dynamic>);

      // Faculty stats (using faculty field saved at registration)
      String faculty =
          student.faculty != null && student.faculty!.trim().isNotEmpty
              ? student.faculty!
              : "Noma'lum";
      _facultyStats[faculty] = (_facultyStats[faculty] ?? 0) + 1;

      // Course stats (using studentId)
      int course = student.studentId != null && student.studentId!.length >= 6
          ? int.tryParse(student.studentId!.substring(4, 6)) ?? 0
          : 0;
      if (course > 0 && course <= 4) {
        _courseStats[course] = (_courseStats[course] ?? 0) + 1;
      }

      // Room stats
      if (student.roomId != null && student.roomId!.isNotEmpty) {
        _studentsWithRoom++;
      } else {
        _studentsWithoutRoom++;
      }
    }

    setState(() => _isLoading = false);
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
              "Talabalar statistikasi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text("Jami talabalar",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            "$_totalStudents",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text("Xonada yashovchilar",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            "$_studentsWithRoom",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Xonasiz talabalar:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      "$_studentsWithoutRoom",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Faculty Stats
              if (_facultyStats.isNotEmpty) ...[
                Text(
                  "Fakultetlar kesimida",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                ..._facultyStats.entries.map((entry) {
                  double percentage = (entry.value / _totalStudents) * 100;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                entry.key,
                                style: TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: Colors.grey.shade200,
                                color: Colors.purple,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              "${entry.value} (${percentage.toStringAsFixed(1)}%)",
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],

              SizedBox(height: 16),

              // Course Stats
              if (_courseStats.isNotEmpty) ...[
                Text(
                  "Kurslar kesimida",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _courseStats.entries.map((entry) {
                    double percentage = (entry.value / _totalStudents) * 100;
                    return Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Text(
                        "${entry.key}-kurs: ${entry.value} (${percentage.toStringAsFixed(1)}%)",
                        style: TextStyle(
                            fontSize: 12, color: Colors.teal.shade700),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
