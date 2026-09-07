import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload user profile image
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      String fileName =
          'users/$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = _storage.ref().child(fileName);

      await ref.putFile(imageFile);
      String downloadUrl = await ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Upload profile image error: $e');
      return null;
    }
  }

  // Upload document (PDF, image, etc.)
  Future<String?> uploadDocument(
      String userId, String documentType, File file) async {
    String extension = path.extension(file.path);
    String fileName =
        'users/$userId/documents/${documentType}_${DateTime.now().millisecondsSinceEpoch}$extension';
    Reference ref = _storage.ref().child(fileName);

    // ✅ Xatolikni yutib yubormaymiz — chaqiruvchi kod (masalan, chek
    // yuklash ekrani) haqiqiy Firebase xatoligini foydalanuvchiga
    // ko'rsata olishi uchun uni qayta uloqtiramiz (rethrow).
    await ref.putFile(file).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception("Yuklash 30 soniyada tugamadi — internetni tekshiring");
      },
    );
    String downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }

  // Upload a PlatformFile (from file_picker) — ishlaydi ham web (bytes
  // orqali), ham mobil/desktop (fayl yo'li orqali) muhitlarida. Ijtimoiy
  // imtiyoz ma'lumotnomalari (PDF/rasm) shu metod orqali yuklanadi.
  Future<String?> uploadPlatformFile(
      String userId, String documentType, PlatformFile file) async {
    String extension = file.extension != null ? '.${file.extension}' : '';
    String fileName =
        'users/$userId/documents/${documentType}_${DateTime.now().millisecondsSinceEpoch}$extension';
    Reference ref = _storage.ref().child(fileName);

    if (file.bytes != null) {
      await ref.putData(file.bytes!).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception(
              "Yuklash 60 soniyada tugamadi — internetni tekshiring");
        },
      );
    } else if (file.path != null) {
      await ref.putFile(File(file.path!)).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception(
              "Yuklash 60 soniyada tugamadi — internetni tekshiring");
        },
      );
    } else {
      throw Exception("Fayl ma'lumotlari topilmadi");
    }
    String downloadUrl = await ref.getDownloadURL();
    return downloadUrl;
  }

  // Upload complaint attachment
  Future<String?> uploadComplaintAttachment(
      String complaintId, File file) async {
    try {
      String extension = path.extension(file.path);
      String fileName =
          'complaints/$complaintId/attachment_${DateTime.now().millisecondsSinceEpoch}$extension';
      Reference ref = _storage.ref().child(fileName);

      await ref.putFile(file);
      String downloadUrl = await ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Upload complaint attachment error: $e');
      return null;
    }
  }

  // Delete file
  Future<bool> deleteFile(String fileUrl) async {
    try {
      await _storage.refFromURL(fileUrl).delete();
      return true;
    } catch (e) {
      print('Delete file error: $e');
      return false;
    }
  }

  // Get file download URL
  Future<String?> getFileUrl(String filePath) async {
    try {
      String url = await _storage.ref(filePath).getDownloadURL();
      return url;
    } catch (e) {
      print('Get file URL error: $e');
      return null;
    }
  }

  // Upload multiple files
  Future<List<String>> uploadMultipleFiles(
      String basePath, List<File> files) async {
    List<String> urls = [];

    for (int i = 0; i < files.length; i++) {
      File file = files[i];
      String extension = path.extension(file.path);
      String fileName =
          '$basePath/file_${DateTime.now().millisecondsSinceEpoch}_$i$extension';
      Reference ref = _storage.ref().child(fileName);

      try {
        await ref.putFile(file);
        String url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        print('Upload file $i error: $e');
      }
    }

    return urls;
  }

  // Get file metadata
  Future<FullMetadata?> getFileMetadata(String filePath) async {
    try {
      return await _storage.ref(filePath).getMetadata();
    } catch (e) {
      print('Get file metadata error: $e');
      return null;
    }
  }

  // List all files in a directory
  Future<ListResult?> listFiles(String directory) async {
    try {
      return await _storage.ref(directory).listAll();
    } catch (e) {
      print('List files error: $e');
      return null;
    }
  }
}
