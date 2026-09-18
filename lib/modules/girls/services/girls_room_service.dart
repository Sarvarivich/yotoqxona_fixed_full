import '../../models/room_model.dart';
import '../../services/api_service.dart';

// ─── GirlsRoomService: Qizlar yotoqxonasi xonalari ─────────────────
//
// Ma'lumot Laravel API'dan olinadi: GET /api/rooms
//
// Laravel'da qizlar uchun alohida jadval yo'q — hamma xona `rooms`
// da, bino esa `hostel_type` ustunida ('boys' / 'girls'). Shu sabab
// bu servis umumiy endpointdan o'qiydi va faqat girls xonalarini
// qaytaradi. Superadmin ekrani (XonalarList) ham xuddi shu manbadan
// o'qigani uchun ikkala ekran bir xil ma'lumotni ko'radi.
//
// DIQQAT: metodlar hamon `Stream` qaytaradi — ekranlar
// `StreamBuilder` bilan yozilgan va ularga tegilmaydi. Lekin endi
// bu bir martalik oqim: ma'lumot ekran ochilganda yuklanadi, real
// vaqtda o'z-o'zidan yangilanmaydi.
class GirlsRoomService {
  final ApiService _api = ApiService();

  /// Xona qaysi binoga tegishli ekanini aniqlaydi.
  ///
  /// Bino uch joyda bo'lishi mumkin: `hostel_type` ustunida,
  /// bog'langan `hostel` obyektining `code` maydonida, yoki uning
  /// nomida.
  String _bino(Map<String, dynamic> d) {
    var bino = (d['hostel_type'] ?? '').toString().trim().toLowerCase();

    if (bino.isEmpty || bino.length > 10) {
      final h = d['hostel'];
      if (h is Map) {
        bino = (h['code'] ?? '').toString().trim().toLowerCase();
        if (bino.isEmpty) {
          final nom = (h['name'] ?? '').toString().toLowerCase();
          bino = nom.contains('qiz') ? 'girls' : 'boys';
        }
      } else if (h != null) {
        bino = h.toString().trim().toLowerCase();
      }
    }

    return bino.isEmpty ? 'boys' : bino;
  }

  Future<List<RoomModel>> _yukla() async {
    final xom = await _api.getRooms();
    final natija = <RoomModel>[];

    for (final x in xom) {
      if (x is! Map) continue;
      final d = Map<String, dynamic>.from(x);
      if (_bino(d) != 'girls') continue;

      try {
        natija.add(RoomModel.fromJson(d));
      } catch (_) {
        // Buzuq yozuv butun ro'yxatni to'xtatmasin.
      }
    }

    natija.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
    return natija;
  }

  Stream<List<RoomModel>> getRooms() => Stream.fromFuture(_yukla());

  Future<RoomModel?> getRoomById(String id) async {
    try {
      final javob = await _api.getRoom(id);
      final d = javob['data'];
      if (d is! Map) return null;
      return RoomModel.fromJson(Map<String, dynamic>.from(d));
    } catch (_) {
      return null;
    }
  }

  /// Bitta xonani kuzatish.
  ///
  /// Ilgari Firestore snapshots() bilan real vaqtda edi. Endi bir
  /// martalik: ekran ochilganda yuklanadi.
  Stream<RoomModel?> watchRoom(String id) =>
      Stream.fromFuture(getRoomById(id));

  Future<void> addRoom(RoomModel room) async {
    await _api.createRoom({
      'room_number': room.roomNumber.toString(),
      'floor': room.floor,
      'capacity': room.capacity,
      'current_occupants': room.currentOccupants,
      'status': room.status.name,
      'hostel': 'girls',
      'hostel_type': 'girls',
      'price_per_month': room.pricePerMonth,
      'amenities': room.amenities,
    });
  }

  Future<void> updateRoom(RoomModel room) async {
    await _api.updateRoom(room.id, {
      'room_number': room.roomNumber.toString(),
      'floor': room.floor,
      'capacity': room.capacity,
      'status': room.status.name,
      'hostel': 'girls',
      'hostel_type': 'girls',
      'price_per_month': room.pricePerMonth,
      'amenities': room.amenities,
    });
  }

  Future<void> deleteRoom(String id) async {
    await _api.deleteRoom(id);
  }

  /// Talabani xonaga biriktiradi.
  ///
  /// Ilgari `studentIds` massivi va `currentOccupants` qo'lda
  /// yangilanardi. Laravel buni bitta tranzaksiyada bajaradi va
  /// sig'imni ham o'zi tekshiradi.
  Future<void> addStudentToRoom(String roomId, String studentId) async {
    await _api.assignStudentToRoom(studentId: studentId, roomId: roomId);
  }

  /// Talabani xonadan chiqaradi.
  ///
  /// Biriktirish yozuvini topib, uni bekor qilamiz.
  Future<void> removeStudentFromRoom(String roomId, String studentId) async {
    final biriktirishlar = await _api.getRoomAssignments();

    for (final b in biriktirishlar) {
      if (b is! Map) continue;
      final d = Map<String, dynamic>.from(b);

      if ((d['room_id'] ?? '').toString() != roomId) continue;
      if ((d['student_id'] ?? '').toString() != studentId) continue;

      final id = (d['id'] ?? '').toString();
      if (id.isEmpty) continue;

      await _api.unassignRoomStudent(id);
      return;
    }
  }
}
