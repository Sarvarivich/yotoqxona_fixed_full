import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  SupabaseStorageService._();

  static final SupabaseStorageService instance = SupabaseStorageService._();

  static const String bucket = 'payment-checks';

  // 🎗️ Ijtimoiy imtiyoz hujjatlari (o'lim varaqasi, ma'lumotnomalar) uchun
  // alohida bucket. Bu Supabase loyihangizda oldindan yaratilgan bo'lishi
  // kerak: Supabase Dashboard → Storage → "New bucket" → nomi
  // "student-documents" (Firebase Storage'dan farqli o'laroq, bunga
  // to'lovli tarifga o'tish shart emas — Supabase bepul tarifda ham
  // Storage to'liq ishlaydi).
  static const String documentsBucket = 'student-documents';

  static const int maxFileSize = 3 * 1024 * 1024; // 3 MB

  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
  ];

  final SupabaseClient _client = Supabase.instance.client;

  bool isAllowedExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return allowedExtensions.contains(ext);
  }

  void validateFile({
    required Uint8List bytes,
    required String fileName,
  }) {
    if (bytes.isEmpty) {
      throw Exception("Fayl bo'sh.");
    }

    if (bytes.length > maxFileSize) {
      throw Exception(
        "Fayl hajmi 2 MB dan oshmasligi kerak.",
      );
    }

    if (!isAllowedExtension(fileName)) {
      throw Exception(
        "Faqat JPG, PNG, WEBP yoki PDF yuklash mumkin.",
      );
    }
  }

  String generateFilePath({
    required String studentId,
    required String fileName,
  }) {
    final ext = fileName.split('.').last.toLowerCase();

    final random = Random().nextInt(999999);

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return "$studentId/${timestamp}_$random.$ext";
  }

  Future<Map<String, String>> uploadPaymentCheck({
    required Uint8List bytes,
    required String studentId,
    required String fileName,
  }) async {
    validateFile(
      bytes: bytes,
      fileName: fileName,
    );

    final path = generateFilePath(
      studentId: studentId,
      fileName: fileName,
    );

    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );

    final publicUrl = _client.storage.from(bucket).getPublicUrl(path);

    return {
      "path": path,
      "publicUrl": publicUrl,
      "fileName": fileName,
    };
  }

  Future<void> deleteFile(String path) async {
    if (path.isEmpty) return;

    await _client.storage.from(bucket).remove([path]);
  }

  String getPublicUrl(String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<bool> fileExists(String path) async {
    try {
      final folder = path.split('/').first;

      final files = await _client.storage.from(bucket).list(path: folder);

      return files.any((e) => e.name == path.split('/').last);
    } catch (_) {
      return false;
    }
  }

  // 🎗️ Ijtimoiy imtiyoz hujjatini (o'lim varaqasi, nogironlik
  // ma'lumotnomasi va h.k.) "student-documents" bucket'iga yuklaydi.
  Future<String> uploadStudentDocument({
    required Uint8List bytes,
    required String studentId,
    required String fileName,
    required String documentType,
  }) async {
    validateFile(bytes: bytes, fileName: fileName);

    final ext = fileName.split('.').last.toLowerCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$studentId/${documentType}_$timestamp.$ext';

    await _client.storage.from(documentsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );

    return _client.storage.from(documentsBucket).getPublicUrl(path);
  }
}
