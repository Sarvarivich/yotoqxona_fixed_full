import 'package:flutter/material.dart';
import '../../models/room_model.dart';
import '../services/girls_room_service.dart';

class GirlsRoomProvider extends ChangeNotifier {
  final GirlsRoomService _service = GirlsRoomService();

  Stream<List<RoomModel>> get rooms => _service.getRooms();

  Stream<RoomModel?> watchRoom(String id) => _service.watchRoom(id);

  Future<void> add(RoomModel room) => _service.addRoom(room);

  Future<void> update(RoomModel room) => _service.updateRoom(room);

  Future<void> delete(String id) => _service.deleteRoom(id);

  Future<void> assignStudent(String roomId, String studentId) =>
      _service.addStudentToRoom(roomId, studentId);

  Future<void> unassignStudent(String roomId, String studentId) =>
      _service.removeStudentFromRoom(roomId, studentId);

  Future<RoomModel?> getRoomById(String id) => _service.getRoomById(id);
}
