import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic body;

  ApiException(
    this.message, {
    this.statusCode,
    this.body,
  });

  @override
  String toString() => message;
}

class ApiService {
  // ============================================================
  // BASE URL
  // ============================================================

  static String get baseUrl {
    // Chrome / Flutter Web
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    // Android Emulator
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    // Windows / Desktop
    return 'http://127.0.0.1:8000/api';
  }

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
  // AUTH HEADERS
  // ============================================================

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'password': password,
      }),
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message']?.toString() ?? 'Login amalga oshmadi.',
        statusCode: response.statusCode,
        body: data,
      );
    }

    final token = data['token']?.toString();

    if (token != null && token.isNotEmpty) {
      await saveToken(token);
    }

    return data;
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  Future<Map<String, dynamic>> me() async {
    final headers = await _authHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: headers,
    );

    return _handle(response);
  }

  // Token bilan me
  Future<Map<String, dynamic>> getCurrentUser(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return _handle(response);
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<Map<String, dynamic>> logout() async {
    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: headers,
    );

    final data = _decode(response);

    await clearToken();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message']?.toString() ?? 'Logout amalga oshmadi.',
        statusCode: response.statusCode,
        body: data,
      );
    }

    return data;
  }

  // Token bilan logout
  Future<Map<String, dynamic>> logoutWithToken(
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = _decode(response);

    await clearToken();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message']?.toString() ?? 'Logout amalga oshmadi.',
        statusCode: response.statusCode,
        body: data,
      );
    }

    return data;
  }

  // ============================================================
  // GET
  // ============================================================

  Future<Map<String, dynamic>> get(
    String endpoint, {
    String? token,
  }) async {
    final headers = token != null
        ? {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          }
        : await _authHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
    );

    return _handle(response);
  }

  // ============================================================
  // POST JSON
  // ============================================================

  Future<Map<String, dynamic>> post(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final headers = token != null
        ? {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          }
        : await _authHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: jsonEncode(body ?? {}),
    );

    return _handle(response);
  }

  // ============================================================
  // PATCH
  // ============================================================

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final headers = token != null
        ? {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          }
        : await _authHeaders();

    final response = await http.patch(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: jsonEncode(body ?? {}),
    );

    return _handle(response);
  }

  // ============================================================
  // PUT
  // ============================================================

  Future<Map<String, dynamic>> put(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final headers = token != null
        ? {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          }
        : await _authHeaders();

    final response = await http.put(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
      body: jsonEncode(body ?? {}),
    );

    return _handle(response);
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    String? token,
  }) async {
    final headers = token != null
        ? {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          }
        : await _authHeaders();

    final response = await http.delete(
      Uri.parse('$baseUrl/$endpoint'),
      headers: headers,
    );

    return _handle(response);
  }

  // ============================================================
  // PAYMENTS - LIST
  // ============================================================

  Future<List<dynamic>> getPayments() async {
    final token = await getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/payments'),
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    final result = _handle(response);
    final data = result['data'];

    if (data is List) {
      return List<dynamic>.from(data);
    }

    return <dynamic>[];
  }

  // ============================================================
  // PAYMENT - SINGLE
  // ============================================================

  Future<Map<String, dynamic>> getPayment(
    String id,
  ) async {
    final headers = await _authHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/payments/$id'),
      headers: headers,
    );

    return _handle(response);
  }

  // ============================================================
  // PAYMENT - UPLOAD RECEIPT
  // ============================================================
  //
  // Laravel:
  // POST /api/payments
  //
  // Multipart fields:
  // room_id
  // amount
  // method
  // period
  // payment_date
  // payment_check_id
  // note
  // receipt
  //
  // Backend room_id orqali hostel_id ni o'zi aniqlaydi.
  // ============================================================

  Future<Map<String, dynamic>> uploadPayment({
    required List<int> bytes,
    required String fileName,
    required String roomId,
    required double amount,
    required String method,
    required String period,
    DateTime? paymentDate,
    String? paymentCheckId,
    String? note,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw ApiException(
        'Avtorizatsiya tokeni topilmadi. '
        'Iltimos, qaytadan login qiling.',
        statusCode: 401,
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/payments'),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    // ------------------------------------------------------------
    // TEXT FIELDS
    // ------------------------------------------------------------

    request.fields['room_id'] = roomId;
    request.fields['amount'] = amount.toString();
    request.fields['method'] = method;
    request.fields['period'] = period;

    if (paymentDate != null) {
      request.fields['payment_date'] = paymentDate.toIso8601String();
    }

    if (paymentCheckId != null && paymentCheckId.isNotEmpty) {
      request.fields['payment_check_id'] = paymentCheckId;
    }

    if (note != null && note.isNotEmpty) {
      request.fields['note'] = note;
    }

    // ------------------------------------------------------------
    // RECEIPT FILE
    // ------------------------------------------------------------

    request.files.add(
      http.MultipartFile.fromBytes(
        'receipt',
        bytes,
        filename: fileName,
      ),
    );

    // ------------------------------------------------------------
    // SEND
    // ------------------------------------------------------------

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(
      streamedResponse,
    );

    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message']?.toString() ?? 'To‘lovni yuborishda server xatosi.',
        statusCode: response.statusCode,
        body: data,
      );
    }

    return data;
  }

  // ============================================================
  // PAYMENT SUMMARY
  // ============================================================

  Future<Map<String, dynamic>> getPaymentSummary() async {
    final headers = await _authHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/payments/summary'),
      headers: headers,
    );

    return _handle(response);
  }

  // ============================================================
  // UPDATE PAYMENT
  // ============================================================

  Future<Map<String, dynamic>> updatePayment(
    String id, {
    String? note,
    String? status,
  }) async {
    final headers = await _authHeaders();

    final body = <String, dynamic>{};

    if (note != null) {
      body['note'] = note;
    }

    if (status != null) {
      body['status'] = status;
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/payments/$id'),
      headers: headers,
      body: jsonEncode(body),
    );

    return _handle(response);
  }

  // ============================================================
  // DELETE PAYMENT
  // ============================================================

  Future<void> deletePayment(
    String id,
  ) async {
    final headers = await _authHeaders();

    final response = await http.delete(
      Uri.parse('$baseUrl/payments/$id'),
      headers: headers,
    );

    _handle(response);
  }

  // ============================================================
  // HANDLE RESPONSE
  // ============================================================

  Map<String, dynamic> _handle(
    http.Response response,
  ) {
    final data = _decode(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        data['message']?.toString() ??
            'Server xatosi (${response.statusCode}).',
        statusCode: response.statusCode,
        body: data,
      );
    }

    return data;
  }

  // ============================================================
  // DECODE JSON
  // ============================================================

  Map<String, dynamic> _decode(
    http.Response response,
  ) {
    if (response.body.isEmpty) {
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
        'message': response.body,
      };
    }
  }
}
