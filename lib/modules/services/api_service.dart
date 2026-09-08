import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://web-production-53ebe.up.railway.app/api';

  static const Duration _timeout = Duration(seconds: 30);
  static const String _tokenKey = 'sanctum_token';

  // ============================================================
  // TOKEN
  // ============================================================

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ============================================================
  // URL
  // ============================================================

  Uri _uri(String endpoint) {
    final cleanEndpoint = endpoint
        .trim()
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'^api/'), '');

    return Uri.parse('$baseUrl/$cleanEndpoint');
  }

  // ============================================================
  // HEADERS
  // ============================================================

  Future<Map<String, String>> _headers({
    bool auth = true,
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await getToken();

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extra != null) {
      headers.addAll(extra);
    }

    return headers;
  }

  // ============================================================
  // RESPONSE
  // ============================================================

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      if (decoded is List) {
        return <String, dynamic>{
          'data': decoded,
        };
      }

      return <String, dynamic>{
        'data': decoded,
      };
    } catch (_) {
      return <String, dynamic>{
        'success': false,
        'message': response.body,
      };
    }
  }

  Map<String, dynamic> _handle(http.Response response) {
    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    String message = 'Server xatoligi (${response.statusCode})';

    final possibleMessage =
        data['message'] ?? data['error'] ?? data['detail'];

    if (possibleMessage is String && possibleMessage.isNotEmpty) {
      message = possibleMessage;
    } else {
      final errors = data['errors'];

      if (errors is Map) {
        final messages = <String>[];

        for (final value in errors.values) {
          if (value is List) {
            messages.addAll(value.map((e) => e.toString()));
          } else {
            messages.add(value.toString());
          }
        }

        if (messages.isNotEmpty) {
          message = messages.join('\n');
        }
      }
    }

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      data: data,
    );
  }

  List<dynamic> _asList(Map<String, dynamic> result) {
    final data = result['data'] ??
        result['items'] ??
        result['results'] ??
        result['expenses'] ??
        result['budgets'];

    if (data is List) {
      return data;
    }

    return <dynamic>[];
  }

  // ============================================================
  // HTTP METHODS
  // ============================================================

  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .get(
            _uri(endpoint),
            headers: await _headers(
              auth: auth,
              extra: headers,
            ),
          )
          .timeout(_timeout);

      return _handle(response);
    } on SocketException {
      throw ApiException(message: 'Internet bilan bog‘lanib bo‘lmadi.');
    } on TimeoutException {
      throw ApiException(message: 'Server javob berish vaqti tugadi.');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    dynamic body,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .post(
            _uri(endpoint),
            headers: await _headers(
              auth: auth,
              extra: headers,
            ),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);

      return _handle(response);
    } on SocketException {
      throw ApiException(message: 'Internet bilan bog‘lanib bo‘lmadi.');
    } on TimeoutException {
      throw ApiException(message: 'Server javob berish vaqti tugadi.');
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    dynamic body,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .put(
            _uri(endpoint),
            headers: await _headers(
              auth: auth,
              extra: headers,
            ),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);

      return _handle(response);
    } on SocketException {
      throw ApiException(message: 'Internet bilan bog‘lanib bo‘lmadi.');
    } on TimeoutException {
      throw ApiException(message: 'Server javob berish vaqti tugadi.');
    }
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    dynamic body,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .patch(
            _uri(endpoint),
            headers: await _headers(
              auth: auth,
              extra: headers,
            ),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);

      return _handle(response);
    } on SocketException {
      throw ApiException(message: 'Internet bilan bog‘lanib bo‘lmadi.');
    } on TimeoutException {
      throw ApiException(message: 'Server javob berish vaqti tugadi.');
    }
  }

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    dynamic body,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .delete(
            _uri(endpoint),
            headers: await _headers(
              auth: auth,
              extra: headers,
            ),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(_timeout);

      return _handle(response);
    } on SocketException {
      throw ApiException(message: 'Internet bilan bog‘lanib bo‘lmadi.');
    } on TimeoutException {
      throw ApiException(message: 'Server javob berish vaqti tugadi.');
    }
  }

  // ============================================================
  // AUTH
  // ============================================================

  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final result = await post(
      'auth/login',
      auth: false,
      body: {
        'email': email,
        'password': password,
      },
    );

    final token = result['token'];

    if (token is String && token.isNotEmpty) {
      await saveToken(token);
    }

    return result;
  }

  Future<Map<String, dynamic>> register(
    Map<String, dynamic> body,
  ) async {
    final result = await post(
      'auth/register',
      auth: false,
      body: body,
    );

    final token = result['token'];

    if (token is String && token.isNotEmpty) {
      await saveToken(token);
    }

    return result;
  }

  Future<Map<String, dynamic>> logout() async {
    try {
      return await post(
        'auth/logout',
        body: {},
      );
    } finally {
      await clearToken();
    }
  }

  Future<Map<String, dynamic>> getMe() {
    return get('auth/me');
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Future<Map<String, dynamic>> getDashboard() {
    return get('dashboard');
  }

  // ============================================================
  // STUDENTS
  // ============================================================

  Future<List<dynamic>> getStudents() async {
    return _asList(await get('students'));
  }

  Future<Map<String, dynamic>> getStudent(String id) {
    return get('students/$id');
  }

  Future<Map<String, dynamic>> createStudent(
    Map<String, dynamic> body,
  ) {
    return post('students', body: body);
  }

  Future<Map<String, dynamic>> updateStudent(
    String id,
    Map<String, dynamic> body,
  ) {
    return put('students/$id', body: body);
  }

  Future<Map<String, dynamic>> deleteStudent(String id) {
    return delete('students/$id');
  }

  Future<Map<String, dynamic>> updateStudentPassword({
    required String studentId,
    required String newPassword,
  }) {
    return put(
      'students/$studentId/password',
      body: {
        'password': newPassword,
      },
    );
  }

  // ============================================================
  // ROOMS
  // ============================================================

  Future<List<dynamic>> getRooms() async {
    return _asList(await get('rooms'));
  }

  Future<Map<String, dynamic>> getRoom(String id) {
    return get('rooms/$id');
  }

  Future<Map<String, dynamic>> createRoom(
    Map<String, dynamic> body,
  ) {
    return post('rooms', body: body);
  }

  Future<Map<String, dynamic>> updateRoom(
    String id,
    Map<String, dynamic> body,
  ) {
    return put('rooms/$id', body: body);
  }

  Future<Map<String, dynamic>> deleteRoom(String id) {
    return delete('rooms/$id');
  }

  // ============================================================
  // ROOM ASSIGNMENTS
  // ============================================================

  Future<List<dynamic>> getRoomAssignments() async {
    return _asList(await get('room-assignments'));
  }

  Future<Map<String, dynamic>> createRoomAssignment(
    Map<String, dynamic> body,
  ) {
    return post('room-assignments', body: body);
  }

  Future<Map<String, dynamic>> assignStudentToRoom({
    required String studentId,
    required String roomId,
  }) {
    return post(
      'room-assignments',
      body: {
        'student_id': studentId,
        'room_id': roomId,
      },
    );
  }

  Future<void> unassignRoomStudent(String assignmentId) async {
    await delete('room-assignments/$assignmentId');
  }

  Future<Map<String, dynamic>> deleteRoomAssignment(
    String id,
  ) {
    return delete('room-assignments/$id');
  }

  Future<Map<String, dynamic>> getMyRoom() {
    return get('my-room');
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Future<List<dynamic>> getPayments() async {
    return _asList(await get('payments'));
  }

  Future<Map<String, dynamic>> getPayment(String id) {
    return get('payments/$id');
  }

  Future<Map<String, dynamic>> createPayment(
    Map<String, dynamic> body,
  ) {
    return post('payments', body: body);
  }

  Future<Map<String, dynamic>> updatePayment(
    String id, {
    String? status,
    String? note,
    Map<String, dynamic>? body,
  }) {
    final requestBody = <String, dynamic>{};

    if (body != null) {
      requestBody.addAll(body);
    }

    if (status != null) {
      requestBody['status'] = status;
    }

    if (note != null) {
      requestBody['note'] = note;
    }

    return patch(
      'payments/$id',
      body: requestBody,
    );
  }

  Future<Map<String, dynamic>> deletePayment(String id) {
    return delete('payments/$id');
  }

  Future<Map<String, dynamic>> getPaymentsSummary() {
    return get('payments/summary');
  }

  // ============================================================
  // COMPLAINTS / MUROJAATLAR
  // ============================================================

  Future<List<dynamic>> getComplaints({
    String? targetRole,
    String? status,
    String? category,
  }) async {
    final parameters = <String, String>{};

    if (status != null && status.isNotEmpty) {
      parameters['status'] = status;
    }

    if (category != null && category.isNotEmpty) {
      parameters['category'] = category;
    }

    if (targetRole != null && targetRole.isNotEmpty) {
      parameters['target_role'] = targetRole;
    }

    var endpoint = 'complaints';

    if (parameters.isNotEmpty) {
      endpoint += '?${Uri(queryParameters: parameters).query}';
    }

    return _asList(await get(endpoint));
  }

  Future<Map<String, dynamic>> getComplaint(String id) {
    return get('complaints/$id');
  }

  Future<Map<String, dynamic>> createComplaint(
    Map<String, dynamic> body,
  ) {
    return post('complaints', body: body);
  }

  Future<Map<String, dynamic>> updateComplaint(
    String id,
    Map<String, dynamic> body,
  ) {
    return put('complaints/$id', body: body);
  }

  Future<Map<String, dynamic>> deleteComplaint(String id) {
    return delete('complaints/$id');
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Future<List<dynamic>> getNotifications() async {
    return _asList(await get('notifications'));
  }

  Future<Map<String, dynamic>> markNotificationAsRead(
    String id,
  ) {
    return patch('notifications/$id/read');
  }

  Future<void> markNotificationRead(String id) async {
    await patch('notifications/$id/read');
  }

  Future<List<dynamic>> getAnnouncements() async {
    return _asList(await get('announcements'));
  }

  Future<Map<String, dynamic>> createAnnouncement(
    Map<String, dynamic> body,
  ) {
    return post('announcements', body: body);
  }

  Future<Map<String, dynamic>> createNotification(
    Map<String, dynamic> body,
  ) {
    return createAnnouncement(body);
  }

  // ============================================================
  // FINANCE
  // ============================================================

  Future<List<dynamic>> getBudgets() async {
    return _asList(await get('budgets'));
  }

  Future<Map<String, dynamic>> setBudget(
    Map<String, dynamic> body,
  ) {
    return post('budgets', body: body);
  }

  Future<List<dynamic>> getExpenses({
    String? category,
  }) async {
    var endpoint = 'expenses';

    if (category != null && category.isNotEmpty) {
      endpoint +=
          '?${Uri(queryParameters: {'category': category}).query}';
    }

    return _asList(await get(endpoint));
  }

  Future<Map<String, dynamic>> createExpense(
    Map<String, dynamic> body,
  ) {
    return post('expenses', body: body);
  }

  // ============================================================
  // APPLICATIONS
  // ============================================================

  Future<List<dynamic>> getApplications() async {
    return _asList(await get('applications'));
  }

  Future<Map<String, dynamic>> getApplication(String id) {
    return get('applications/$id');
  }

  Future<Map<String, dynamic>> createApplication(
    Map<String, dynamic> body,
  ) {
    return post('applications', body: body);
  }

  Future<Map<String, dynamic>> updateApplication(
    String id,
    Map<String, dynamic> body,
  ) {
    return put('applications/$id', body: body);
  }

  Future<Map<String, dynamic>> deleteApplication(String id) {
    return delete('applications/$id');
  }

  // ============================================================
  // SURVEYS
  // ============================================================

  Future<List<dynamic>> getSurveys() async {
    return _asList(await get('surveys'));
  }

  Future<Map<String, dynamic>> getSurvey(String id) {
    return get('surveys/$id');
  }

  Future<Map<String, dynamic>> submitSurveyAnswers(
    String id,
    Map<String, dynamic> body,
  ) {
    return post(
      'surveys/$id/answers',
      body: body,
    );
  }

  // ============================================================
  // HOSTELS
  // ============================================================

  Future<List<dynamic>> getHostels() async {
    return _asList(await get('hostels'));
  }

  Future<Map<String, dynamic>> getHostel(String id) {
    return get('hostels/$id');
  }

  // ============================================================
  // CONTRACT
  // ============================================================

  Future<Map<String, dynamic>> getContractStatus() {
    return get('contract/status');
  }

  Future<bool> isContractAvailable() async {
    try {
      final result = await getContractStatus();

      if (result['available'] == true) {
        return true;
      }

      final data = result['data'];

      if (data is Map) {
        return data['available'] == true ||
            data['exists'] == true ||
            data['has_contract'] == true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> downloadContractBytes() async {
    try {
      final response = await http
          .get(
            _uri('contract/download'),
            headers: await _headers(),
          )
          .timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }

      _handle(response);
      return Uint8List(0);
    } on SocketException {
      throw ApiException(
        message: 'Internet bilan bog‘lanib bo‘lmadi.',
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Shartnomani yuklab olish vaqti tugadi.',
      );
    }
  }

  // ============================================================
  // FILE UPLOAD
  // ============================================================

  Future<Map<String, dynamic>> uploadFile({
    required String endpoint,
    required File file,
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        _uri(endpoint),
      );

      request.headers['Accept'] = 'application/json';

      final token = await getToken();

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (fields != null) {
        request.fields.addAll(fields);
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path,
        ),
      );

      final streamedResponse =
          await request.send().timeout(_timeout);

      final response =
          await http.Response.fromStream(streamedResponse);

      return _handle(response);
    } on SocketException {
      throw ApiException(
        message: 'Internet bilan bog‘lanib bo‘lmadi.',
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Fayl yuborish vaqti tugadi.',
      );
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => message;
}
