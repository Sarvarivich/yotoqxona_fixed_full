import 'dart:convert';
import 'package:http/http.dart' as http;

class XamppApiService {
  XamppApiService._();

  static final XamppApiService instance = XamppApiService._();

  // Telefon/emulator uchun localhost emas.
  //
  // Android Emulator:
  // 10.0.2.2
  //
  // Real telefon:
  // kompyuteringizning LAN IP manzili.
  static const String baseUrl =
      'http://10.0.2.2/yotoqxona_fixed/xampp_backend/api/index.php';

  Future<Map<String, dynamic>> createDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    return _send(
      method: 'POST',
      collection: collection,
      documentId: documentId,
      data: data,
    );
  }

  Future<Map<String, dynamic>> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    return _send(
      method: 'PUT',
      collection: collection,
      documentId: documentId,
      data: data,
    );
  }

  Future<Map<String, dynamic>> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    return _send(
      method: 'DELETE',
      collection: collection,
      documentId: documentId,
    );
  }

  Future<Map<String, dynamic>> _send({
    required String method,
    required String collection,
    required String documentId,
    Map<String, dynamic>? data,
  }) async {
    final uri = Uri.parse(
      '$baseUrl?path=document/'
      '${Uri.encodeComponent(collection)}/'
      '${Uri.encodeComponent(documentId)}',
    );

    final response = await _request(
      method,
      uri,
      data,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'XAMPP API ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw Exception('XAMPP API noto‘g‘ri javob qaytardi.');
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, dynamic>? data,
  ) async {
    const timeout = Duration(seconds: 10);

    switch (method) {
      case 'POST':
        return http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data ?? {}),
            )
            .timeout(timeout);

      case 'PUT':
        return http
            .put(
              uri,
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data ?? {}),
            )
            .timeout(timeout);

      case 'DELETE':
        return http.delete(uri).timeout(timeout);

      default:
        throw Exception('Noma‘lum HTTP method: $method');
    }
  }
}
