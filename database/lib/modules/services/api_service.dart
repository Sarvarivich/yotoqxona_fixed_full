import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'http://127.0.0.1:8000/api'; // Generic GET request
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: _getHeaders(headers),
      );

      return _handleResponse(response);
    } catch (e) {
      print('GET error: $e');
      rethrow;
    }
  }

  // Generic POST request
  Future<dynamic> post(String endpoint, dynamic data,
      {Map<String, String>? headers}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: _getHeaders(headers),
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      print('POST error: $e');
      rethrow;
    }
  }

  // Generic PUT request
  Future<dynamic> put(String endpoint, dynamic data,
      {Map<String, String>? headers}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$endpoint'),
        headers: _getHeaders(headers),
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      print('PUT error: $e');
      rethrow;
    }
  }

  // Generic DELETE request
  Future<dynamic> delete(String endpoint,
      {Map<String, String>? headers}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$endpoint'),
        headers: _getHeaders(headers),
      );

      return _handleResponse(response);
    } catch (e) {
      print('DELETE error: $e');
      rethrow;
    }
  }

  // Headers
  Map<String, String> _getHeaders(Map<String, String>? additionalHeaders) {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  // Handle response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // ============ AUTH ENDPOINTS ============

  Future<Map<String, dynamic>> login(String email, String password) async {
    return await post('auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    return await post('auth/register', userData);
  }

  Future<Map<String, dynamic>> logout(String token) async {
    return await post('auth/logout', {}, headers: {
      'Authorization': 'Bearer $token',
    });
  }

  // ============ USER ENDPOINTS ============

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return await get('users/$userId');
  }

  Future<Map<String, dynamic>> updateUserProfile(
      String userId, Map<String, dynamic> data) async {
    return await put('users/$userId', data);
  }

  Future<List<dynamic>> getAllUsers() async {
    return await get('foydalanuvchilar');
  }

  // ============ ROOM ENDPOINTS ============

  Future<List<dynamic>> getAllRooms() async {
    return await get('xonalar');
  }

  Future<Map<String, dynamic>> getRoom(String roomId) async {
    return await get('rooms/$roomId');
  }

  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> roomData) async {
    return await post('xonalar', roomData);
  }

  Future<Map<String, dynamic>> updateRoom(
      String roomId, Map<String, dynamic> data) async {
    return await put('rooms/$roomId', data);
  }

  Future<void> deleteRoom(String roomId) async {
    await delete('rooms/$roomId');
  }

  // ============ COMPLAINT ENDPOINTS ============

  Future<List<dynamic>> getComplaints({String? status}) async {
    String endpoint = 'murojaatlar';
    if (status != null) {
      endpoint += '?status=$status';
    }
    return await get(endpoint);
  }

  Future<Map<String, dynamic>> getComplaint(String complaintId) async {
    return await get('complaints/$complaintId');
  }

  Future<Map<String, dynamic>> createComplaint(
      Map<String, dynamic> complaintData) async {
    return await post('murojaatlar', complaintData);
  }

  Future<Map<String, dynamic>> respondToComplaint(
      String complaintId, String response) async {
    return await post('complaints/$complaintId/respond', {
      'response': response,
    });
  }

  // ============ STATISTICS ENDPOINTS ============

  Future<Map<String, dynamic>> getDashboardStats() async {
    return await get('stats/dashboard');
  }

  Future<Map<String, dynamic>> getRoomStats() async {
    return await get('stats/rooms');
  }

  Future<Map<String, dynamic>> getIncomeStats(String period) async {
    return await get('stats/income?period=$period');
  }

  // ============ NOTIFICATION ENDPOINTS ============

  Future<Map<String, dynamic>> sendNotification(
      Map<String, dynamic> data) async {
    return await post('notifications/send', data);
  }

  Future<List<dynamic>> getUserNotifications(String userId) async {
    return await get('notifications/user/$userId');
  }

  // ============ SURVEY ENDPOINTS ============

  Future<Map<String, dynamic>> submitSurvey(
      Map<String, dynamic> surveyData) async {
    return await post('sorovnomalar', surveyData);
  }

  Future<Map<String, dynamic>> getSurveyStats() async {
    return await get('surveys/stats');
  }
}
