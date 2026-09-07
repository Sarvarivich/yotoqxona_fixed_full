import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/room_model.dart';

// ─── GirlsRoomService: Qizlar yotoqxonasi xonalari uchun.
// ⚠️ MUHIM: bolalar (superAdmin/admin) tomonida "Xonalar" bo'limi
// (XonalarList) FAQAT 'xonalar' Firestore to'plamini o'qiydi va
// hujjatlardagi 'hostel' maydoni bo'yicha ("boys" / "girls") filtrlaydi.
// Avval bu servis alohida 'girls_rooms' to'plamiga yozar edi — shu sabab
// qizlar bo'limida yaratilgan yangi xonalar 'xonalar' to'plamida umuman
// bo'lmagani uchun superAdmin ekranida (XonalarList) ko'rinmas edi.
// Muammoni tuzatish uchun bu servis ham xuddi shu umumiy 'xonalar'
// to'plamidan foydalanadi, faqat har doim hostel:'girls' bilan yozadi
// va o'qishda ham shu maydon bo'yicha filtrlaydi — shunda ikkala ekran
// (superAdmin va qizlar admin paneli) bir xil ma'lumotni ko'radi.
class GirlsRoomService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('xonalar');

  Stream<List<RoomModel>> getRooms() {
    // Umumiy 'xonalar' to'plamida hostel bo'yicha filtrlaymiz (client
    // tomonda), shunda o'g'il bolalar xonalari bu yerda ko'rinmaydi va
    // orderBy bilan indeks talab qilinmaydi.
    return _collection.orderBy('roomNumber').snapshots().map((snap) {
      return snap.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return RoomModel.fromJson(data);
          })
          .where((room) =>
              (room.hostel.isEmpty ? 'boys' : room.hostel.toLowerCase()) ==
              'girls')
          .toList();
    });
  }

  Future<RoomModel?> getRoomById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data() ?? {});
    data['id'] = doc.id;
    return RoomModel.fromJson(data);
  }

  /// Bitta xonani real vaqtda kuzatish — talaba biriktirilgach/olib
  /// tashlangach ekran avtomatik yangilanadi.
  Stream<RoomModel?> watchRoom(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data() ?? {});
      data['id'] = doc.id;
      return RoomModel.fromJson(data);
    });
  }

  Future<void> addRoom(RoomModel room) async {
    final data = room.toJson();
    data['hostel'] = 'girls';
    data.remove('id');
    await _collection.add(data);
  }

  Future<void> updateRoom(RoomModel room) async {
    final data = room.toJson();
    data['hostel'] = 'girls';
    data.remove('id');
    data['updatedAt'] = Timestamp.now();
    await _collection.doc(room.id).update(data);
  }

  Future<void> deleteRoom(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> addStudentToRoom(String roomId, String studentId) async {
    await _collection.doc(roomId).update({
      'studentIds': FieldValue.arrayUnion([studentId]),
    });
    final doc = await _collection.doc(roomId).get();
    final list = List<String>.from(doc.data()?['studentIds'] ?? []);
    await _collection.doc(roomId).update({'currentOccupants': list.length});
  }

  Future<void> removeStudentFromRoom(String roomId, String studentId) async {
    await _collection.doc(roomId).update({
      'studentIds': FieldValue.arrayRemove([studentId]),
    });
    final doc = await _collection.doc(roomId).get();
    final list = List<String>.from(doc.data()?['studentIds'] ?? []);
    await _collection.doc(roomId).update({'currentOccupants': list.length});
  }
}
