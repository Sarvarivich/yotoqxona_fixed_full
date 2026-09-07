import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// ============================================================
/// KU HOSTEL - OFFLINE FIRST SERVICE
///
/// Asosiy ishlash tartibi:
///
/// 1. Firebase ishlayapti:
///      Flutter -> Firebase
///
/// 2. Firebase ishlamayapti:
///      Flutter -> XAMPP API -> MySQL
///
/// 3. Firebase qayta ishlaganda:
///      worker.js -> sync_queue -> Firebase
///
/// Bu servis Firebase bilan ishlashni va XAMPP fallback'ni
/// bitta joydan boshqarish uchun ishlatiladi.
/// ============================================================

class OfflineFirstService {
  OfflineFirstService._();

  static final OfflineFirstService instance = OfflineFirstService._();

  /// ==========================================================
  /// XAMPP API MANZILI
  /// ==========================================================
  ///
  /// Android Emulator uchun:
  ///
  /// 10.0.2.2 = kompyuter localhost'i
  ///
  /// Windows Desktop uchun:
  /// localhost ishlatilishi mumkin.
  ///
  /// Haqiqiy Android telefon uchun:
  /// kompyuterning lokal IP manzili kerak bo'ladi.
  ///

  static const String baseUrl =
      'http://10.0.2.2/yotoqxona_fixed/xampp_backend/index.php';

  /// Firebase serverga javob berishini kutish vaqti.

  static const Duration firebaseTimeout = Duration(seconds: 5);

  /// XAMPP API javobini kutish vaqti.

  static const Duration apiTimeout = Duration(seconds: 10);

  // ==========================================================
  // XAMPP API REQUEST
  // ==========================================================

  /// XAMPP API'dan keladigan javob Map ham, List ham bo'lishi
  /// mumkin.
  ///
  /// Masalan:
  ///
  /// sync-state -> Map
  ///
  /// queue -> List
  ///
  /// changes -> List
  ///
  /// document -> Map
  ///
  Future<dynamic> _apiRequest({
    required String path,
    required String method,
    Map<String, dynamic>? data,
  }) async {
    final uri = Uri.parse(
      '$baseUrl?path=${Uri.encodeComponent(path)}',
    );

    late http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(uri).timeout(apiTimeout);
        break;

      case 'POST':
        response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data ?? {}),
            )
            .timeout(apiTimeout);
        break;

      case 'PUT':
        response = await http
            .put(
              uri,
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode(data ?? {}),
            )
            .timeout(apiTimeout);
        break;

      case 'DELETE':
        response = await http.delete(uri).timeout(apiTimeout);
        break;

      default:
        throw Exception(
          'Noma\'lum HTTP method: $method',
        );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'XAMPP API xatosi: '
        '${response.statusCode} '
        '${response.body}',
      );
    }

    if (response.body.trim().isEmpty) {
      return null;
    }

    final dynamic decoded = jsonDecode(response.body);

    return decoded;
  }

  // ==========================================================
  // XAMPP'GA SAQLASH
  // ==========================================================

  Future<bool> _saveToXampp({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    required bool isUpdate,
  }) async {
    try {
      final dynamic result = await _apiRequest(
        path: 'document/$collection/$documentId',
        method: isUpdate ? 'PUT' : 'POST',
        data: data,
      );

      if (result is Map) {
        return result['success'] == true;
      }

      return true;
    } catch (e) {
      print(
        '❌ XAMPP fallback ham ishlamadi: $e',
      );

      return false;
    }
  }

  // ==========================================================
  // DOCUMENT SET
  // ==========================================================

  /// Firebase:
  ///
  /// collection/documentId
  ///
  /// ga yangi document yozadi.
  ///
  /// Firebase ishlamasa:
  ///
  /// XAMPP'ga yozadi.

  Future<void> setDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
    bool merge = false,
  }) async {
    try {
      print(
        '🔥 Firebase SET: '
        '$collection/$documentId',
      );

      final DocumentReference<Map<String, dynamic>> ref =
          FirebaseFirestore.instance.collection(collection).doc(documentId);

      if (merge) {
        await ref
            .set(
              data,
              SetOptions(
                merge: true,
              ),
            )
            .timeout(firebaseTimeout);
      } else {
        await ref.set(data).timeout(firebaseTimeout);
      }

      print(
        '✅ Firebase SET muvaffaqiyatli',
      );
    } catch (firebaseError) {
      print(
        '⚠️ Firebase SET ishlamadi:',
      );

      print(firebaseError);

      print(
        '🔄 XAMPP fallback ishga tushmoqda...',
      );

      final bool success = await _saveToXampp(
        collection: collection,
        documentId: documentId,
        data: data,
        isUpdate: merge,
      );

      if (!success) {
        throw Exception(
          'Firebase ham, XAMPP ham ishlamadi.',
        );
      }

      print(
        '✅ Ma\'lumot XAMPP ga saqlandi.',
      );
    }
  }

  // ==========================================================
  // DOCUMENT UPDATE
  // ==========================================================

  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    try {
      print(
        '🔥 Firebase UPDATE: '
        '$collection/$documentId',
      );

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(documentId)
          .update(data)
          .timeout(firebaseTimeout);

      print(
        '✅ Firebase UPDATE muvaffaqiyatli',
      );
    } catch (firebaseError) {
      print(
        '⚠️ Firebase UPDATE ishlamadi:',
      );

      print(firebaseError);

      print(
        '🔄 XAMPP fallback ishga tushmoqda...',
      );

      final bool success = await _saveToXampp(
        collection: collection,
        documentId: documentId,
        data: data,
        isUpdate: true,
      );

      if (!success) {
        throw Exception(
          'Firebase ham, XAMPP ham ishlamadi.',
        );
      }

      print(
        '✅ UPDATE XAMPP ga saqlandi.',
      );
    }
  }

  // ==========================================================
  // DOCUMENT DELETE
  // ==========================================================

  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      print(
        '🔥 Firebase DELETE: '
        '$collection/$documentId',
      );

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(documentId)
          .delete()
          .timeout(firebaseTimeout);

      print(
        '✅ Firebase DELETE muvaffaqiyatli',
      );
    } catch (firebaseError) {
      print(
        '⚠️ Firebase DELETE ishlamadi:',
      );

      print(firebaseError);

      print(
        '🔄 XAMPP DELETE fallback...',
      );

      try {
        final dynamic result = await _apiRequest(
          path: 'document/$collection/$documentId',
          method: 'DELETE',
        );

        if (result is Map) {
          if (result['success'] != true) {
            throw Exception(
              'XAMPP DELETE muvaffaqiyatsiz.',
            );
          }
        }

        print(
          '✅ DELETE XAMPP ga saqlandi.',
        );
      } catch (xamppError) {
        print(
          '❌ Firebase ham, XAMPP ham DELETE qila olmadi:',
        );

        print(xamppError);

        throw Exception(
          'Ma\'lumotni o\'chirish amalga oshmadi.',
        );
      }
    }
  }

  // ==========================================================
  // DOCUMENT GET
  // ==========================================================

  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    try {
      print(
        '🔥 Firebase GET: '
        '$collection/$documentId',
      );

      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection(collection)
          .doc(documentId)
          .get()
          .timeout(firebaseTimeout);

      if (!doc.exists) {
        return null;
      }

      final Map<String, dynamic>? data = doc.data();

      if (data == null) {
        return null;
      }

      return {
        'id': doc.id,
        ...data,
      };
    } catch (firebaseError) {
      print(
        '⚠️ Firebase GET ishlamadi:',
      );

      print(firebaseError);

      print(
        '🔄 XAMPP GET fallback...',
      );

      try {
        final dynamic result = await _apiRequest(
          path: 'document/$collection/$documentId',
          method: 'GET',
        );

        if (result is! Map) {
          return null;
        }

        if (result['error'] != null) {
          return null;
        }

        final dynamic data = result['data'];

        if (data is Map) {
          return {
            'id': documentId,
            ...Map<String, dynamic>.from(
              data,
            ),
          };
        }

        return null;
      } catch (xamppError) {
        print(
          '❌ XAMPP GET ham ishlamadi:',
        );

        print(xamppError);

        return null;
      }
    }
  }

  // ==========================================================
  // COLLECTION GET
  // ==========================================================

  Future<List<Map<String, dynamic>>> getCollection({
    required String collection,
  }) async {
    try {
      print(
        '🔥 Firebase COLLECTION GET: '
        '$collection',
      );

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection(collection)
              .get()
              .timeout(firebaseTimeout);

      final List<Map<String, dynamic>> result = [];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();

        result.add({
          'id': doc.id,
          ...data,
        });
      }

      return result;
    } catch (firebaseError) {
      print(
        '⚠️ Firebase COLLECTION GET ishlamadi:',
      );

      print(firebaseError);

      print(
        '🔄 XAMPP COLLECTION fallback...',
      );

      try {
        final dynamic result = await _apiRequest(
          path: 'collection/$collection',
          method: 'GET',
        );

        if (result is! List) {
          return [];
        }

        final List<Map<String, dynamic>> list = [];

        for (final dynamic item in result) {
          if (item is Map) {
            list.add(
              Map<String, dynamic>.from(
                item,
              ),
            );
          }
        }

        return list;
      } catch (xamppError) {
        print(
          '❌ Firebase va XAMPP COLLECTION ishlamadi:',
        );

        print(xamppError);

        return [];
      }
    }
  }

  // ==========================================================
  // SYNC STATE
  // ==========================================================

  Future<Map<String, dynamic>?> getSyncState() async {
    try {
      final dynamic result = await _apiRequest(
        path: 'sync-state',
        method: 'GET',
      );

      if (result is Map) {
        return Map<String, dynamic>.from(
          result,
        );
      }

      return null;
    } catch (e) {
      print(
        '❌ sync-state olishda xato: $e',
      );

      return null;
    }
  }

  // ==========================================================
  // QUEUE
  // ==========================================================

  Future<List<Map<String, dynamic>>> getQueue() async {
    try {
      final dynamic result = await _apiRequest(
        path: 'queue',
        method: 'GET',
      );

      if (result is! List) {
        return [];
      }

      final List<Map<String, dynamic>> list = [];

      for (final dynamic item in result) {
        if (item is Map) {
          list.add(
            Map<String, dynamic>.from(
              item,
            ),
          );
        }
      }

      return list;
    } catch (e) {
      print(
        '❌ Queue olishda xato: $e',
      );

      return [];
    }
  }

  // ==========================================================
  // CHANGE HISTORY
  // ==========================================================

  Future<List<Map<String, dynamic>>> getChanges() async {
    try {
      final dynamic result = await _apiRequest(
        path: 'changes',
        method: 'GET',
      );

      if (result is! List) {
        return [];
      }

      final List<Map<String, dynamic>> list = [];

      for (final dynamic item in result) {
        if (item is Map) {
          list.add(
            Map<String, dynamic>.from(
              item,
            ),
          );
        }
      }

      return list;
    } catch (e) {
      print(
        '❌ Change history olishda xato: $e',
      );

      return [];
    }
  }
}
