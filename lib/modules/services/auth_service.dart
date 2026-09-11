import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;
import 'package:yotoqxona/modules/models/user_model.dart';
import 'supabase_storage_service.dart';
import 'api_service.dart';

// ─── AuthService: endi TO'LIQ Firebase Authentication'ga asoslangan ───
// ✅ Parollar endi Firestore'da ochiq matn (plain text) holida
//    SAQLANMAYDI. Ularni Firebase Authentication o'zi xavfsiz
//    boshqaradi (hash'langan holda). Firestore'dagi `users/{uid}`
//    hujjati faqat profil ma'lumotlarini (ism, rol, telefon va h.k.)
//    saqlaydi, hujjat ID'si esa Firebase Auth UID bilan bir xil bo'ladi.
class AuthService {
  static final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('foydalanuvchilar');

  // Firebase login xatolik kodlarini talabaga tushunarli xabarga aylantiradi
  static String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return "Email yoki parol xato!";
      case 'invalid-email':
        return "Email formati noto'g'ri";
      case 'user-disabled':
        return "Bu hisob bloklangan";
      case 'email-already-in-use':
        return "Bu email band!";
      case 'weak-password':
        return "Parol juda oddiy — kamida 6 ta belgi bo'lishi kerak";
      case 'network-request-failed':
        return "Internet aloqasi yo'q, qaytadan urinib ko'ring";
      default:
        return e.message ?? "Noma'lum xatolik: ${e.code}";
    }
  }

  // Hujjat yuklashdagi xatolikni talabaga tushunarli qisqa xabarga o'giradi.
  static String _friendlyUploadError(Object e) {
    if (e is StorageException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('bucket not found')) {
        return "hujjatlar uchun bucket topilmadi — administratorga xabar bering";
      }
      if (msg.contains('row-level security') ||
          msg.contains('policy') ||
          e.statusCode == '403') {
        return "yuklashga ruxsat yo'q";
      }
      return e.message;
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'unauthorized':
        case 'permission-denied':
          return "ruxsat yo'q";
        case 'canceled':
          return "bekor qilindi";
        case 'retry-limit-exceeded':
          return "internet aloqasi beqaror";
        default:
          return e.code;
      }
    }
    final msg = e.toString();
    if (msg.contains('tugamadi')) return "internet sekin yoki uzilgan";
    return "noma'lum xatolik";
  }

  // 1. TALABANING O'ZI RO'YXATDAN O'TISHI
  /// Talabaning o'zi ro'yxatdan o'tishi.
  ///
  /// Endi to'liq Laravel API orqali: POST /api/register.
  /// Backend bir so'rovda hammasini bajaradi вЂ” foydalanuvchi
  /// yaratish, ijtimoiy imtiyoz hujjatlarini saqlash, ariza ochish
  /// (2-bosqich, "ko'rib chiqilmoqda") va Sanctum tokeni berish.
  ///
  /// Ilgari bu metod Firebase Auth'da hisob ochib, hujjatlarni
  /// Supabase'ga yuklab, profilni Firestore'ga yozardi. Uch qadam,
  /// uchtasi ham alohida buzilishi mumkin edi вЂ” va Firebase
  /// sozlanmagan platformalarda (masalan Windows) umuman ishlamasdi.
  static Future<void> registerAndLoginUser({
    required BuildContext context,
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    required String hostel, // "boys" yoki "girls"
    String? phoneNumber,
    String? faculty,
    String? course,
    String? passportId,
    String? jshshir,
    DateTime? birthDate,
    String? region,
    String? district,
    bool hasSocialBenefit = false,
    String? benefitType, // '1'..'6'
    String? lostParentType, // faqat benefitType == '1' uchun
    PlatformFile? deathCertificateFile,
    PlatformFile? benefitDocumentFile,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Hujjatlar bo'lgani uchun multipart so'rov yuboramiz.
      final sorov = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/register'),
      );
      sorov.headers['Accept'] = 'application/json';

      void qosh(String kalit, String? qiymat) {
        if (qiymat != null && qiymat.trim().isNotEmpty) {
          sorov.fields[kalit] = qiymat.trim();
        }
      }

      qosh('full_name', fullName);
      qosh('email', email.toLowerCase());
      qosh('password', password);
      qosh('hostel', hostel);
      qosh('phone', phoneNumber);
      qosh('faculty', faculty);
      qosh('passport_id', passportId);
      qosh('jshshir', jshshir);
      qosh('region', region);
      qosh('district', district);

      // Kurs butun son bo'lishi kerak: "1-kurs" -> "1"
      if (course != null && course.isNotEmpty) {
        final raqam = course.replaceAll(RegExp(r'[^0-9]'), '');
        if (raqam.isNotEmpty) sorov.fields['course'] = raqam;
      }

      if (birthDate != null) {
        sorov.fields['birth_date'] =
            birthDate.toIso8601String().split('T').first;
      }

      if (hasSocialBenefit) {
        sorov.fields['has_social_benefit'] = '1';
        qosh('benefit_type', benefitType);
        qosh('lost_parent_type', lostParentType);
      }

      // Hujjatlar. Backend ularni saqlaydi va havolasini
      // additional_data ichiga yozadi.
      if (hasSocialBenefit &&
          benefitType == '1' &&
          deathCertificateFile?.bytes != null) {
        sorov.files.add(http.MultipartFile.fromBytes(
          'death_certificate',
          deathCertificateFile!.bytes!,
          filename: deathCertificateFile.name,
        ));
      } else if (hasSocialBenefit &&
          benefitType != null &&
          benefitType != '1' &&
          benefitDocumentFile?.bytes != null) {
        sorov.files.add(http.MultipartFile.fromBytes(
          'benefit_document',
          benefitDocumentFile!.bytes!,
          filename: benefitDocumentFile.name,
        ));
      }

      final javob = await http.Response.fromStream(await sorov.send());
      final tana = jsonDecode(javob.body) as Map<String, dynamic>;

      if (javob.statusCode < 200 || javob.statusCode >= 300) {
        throw Exception(_registerXato(tana));
      }

      // Token darhol saqlanadi вЂ” talaba qayta login qilmasdan
      // tizimga kiradi.
      final token = tana['token']?.toString();
      if (token != null && token.isNotEmpty) {
        await ApiService.saveToken(token);
      }

      if (!context.mounted) return;
      Navigator.of(context).pop(); // yuklanish oynasi

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Muvaffaqiyatli ro'yxatdan o'tdingiz!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(); // ro'yxatdan o'tish ekrani
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$e".replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  /// Backend validatsiya xatolarini o'qish uchun qulay matnga o'giradi.
  static String _registerXato(Map<String, dynamic> tana) {
    final errors = tana['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final birinchi = errors.values.first;
      final matn = birinchi is List && birinchi.isNotEmpty
          ? birinchi.first.toString()
          : birinchi.toString();

      final past = matn.toLowerCase();
      if (past.contains('email') && past.contains('taken')) {
        return "Bu email allaqachon ro'yxatdan o'tgan.";
      }
      if (past.contains('jshshir')) {
        return "Bu JSHSHIR allaqachon ro'yxatdan o'tgan.";
      }
      if (past.contains('passport')) {
        return "Bu pasport raqami allaqachon ro'yxatdan o'tgan.";
      }
      return matn;
    }

    return tana['message']?.toString() ?? "Ro'yxatdan o'tishda xatolik.";
  }
  // 2. ADMIN/MUDIR ICHKARIDAN YANGI FOYDALANUVCHI QO'SHISHI
  //
  // ✅ Endi Laravel API orqali ishlaydi (POST /api/students).
  //
  // Ilgari bu metod ikkinchi (vaqtinchalik) Firebase ilova nusxasini
  // ochib, Firebase Auth'da hisob yaratardi va profilni Firestore'ga
  // yozardi. Bu murakkab edi va uch muammosi bor edi:
  //   1. Firestore yozish muvaffaqiyatsiz tugasa "orphan" Auth hisobi
  //      qolib ketardi — hisob bor, profil yo'q.
  //   2. Windows va boshqa Firebase sozlanmagan platformalarda
  //      umuman ishlamas edi.
  //   3. Ma'lumot Laravel bazasiga tushmasdi.
  //
  // Laravel tomonida hammasi bitta so'rovda va bitta tranzaksiyada
  // bajariladi. Ruxsatlar ham server tomonda tekshiriladi:
  // mudir faqat talaba qo'sha oladi, xodim hisobini faqat superAdmin
  // ocha oladi (qarang: UserPolicy::create).
  static Future<bool> addUserByAdmin({
    required BuildContext context,
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String hostel = "boys",
    String? phoneNumber,
    String? faculty,
    String? course,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final body = <String, dynamic>{
        'full_name': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password.trim(),
        'role': role.name,
        'hostel': hostel,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phone': phoneNumber.trim(),
        if (faculty != null && faculty.isNotEmpty) 'faculty': faculty,
        // Backend 'course' ni butun son sifatida kutadi, ekran esa
        // matn ("1-kurs" yoki "1") berishi mumkin — raqamini ajratamiz.
        if (course != null && course.isNotEmpty)
          'course': int.tryParse(course.replaceAll(RegExp(r'[^0-9]'), '')),
        // Admin/superAdmin uchun huquqlar ro'yxati additional_data
        // ichida saqlanadi.
        if (extraData != null) 'additional_data': extraData,
      };

      // null qiymatlarni yubormaymiz — validatsiya ularni rad etishi
      // mumkin (masalan course ajratib bo'lmasa).
      body.removeWhere((key, value) => value == null);

      await ApiService().createStudent(body);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Yangi foydalanuvchi muvaffaqiyatli qo'shildi!"),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } on ApiException catch (e) {
      // Backend validatsiya xatosini (422) foydalanuvchiga tushunarli
      // ko'rinishda chiqaramiz: takroriy email, band JSHSHIR, qisqa
      // parol va hokazo.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyApiError(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Xatolik: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  // Laravel API xatosini o'zbekcha tushunarli xabarga o'giradi.
  static String _friendlyApiError(ApiException e) {
    final matn = e.message.toLowerCase();

    if (matn.contains('email') && matn.contains('taken')) {
      return "Bu email allaqachon ro'yxatdan o'tgan.";
    }
    if (matn.contains('jshshir')) {
      return "Bu JSHSHIR allaqachon boshqa foydalanuvchiga biriktirilgan.";
    }
    if (matn.contains('passport')) {
      return "Bu pasport raqami allaqachon ro'yxatdan o'tgan.";
    }
    if (matn.contains('password') && matn.contains('8')) {
      return "Parol kamida 8 ta belgidan iborat bo'lishi kerak.";
    }
    if (matn.contains('ruxsat') || matn.contains('403')) {
      return "Bu amalni bajarish uchun sizda ruxsat yo'q.";
    }

    return e.message;
  }

  static Future<void> logout() async {
    try {
      await ApiService().logout();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  // 3. TIZIMGA KIRISH (LOGIN)
  // ✅ Birinchi navbatda Laravel REST API (Sanctum) orqali tekshiradi,
  // kerak bo'lsa Firebase Auth zaxira sifatida ishlaydi.
  static Future<UserModel?> loginUser({
    required BuildContext context,
    required String email,
    required String password,
    required String hostel,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final inputEmail = email.trim().toLowerCase();
    final inputPassword = password.trim();

    // 1. Laravel API orqali kirishga urinish
    try {
      final loginData = await ApiService().login(inputEmail, inputPassword);

      final nestedData = loginData['data'] is Map
          ? Map<String, dynamic>.from(loginData['data'] as Map)
          : <String, dynamic>{};

      final rawUserData = loginData['user'] ??
          nestedData['user'] ??
          (nestedData.containsKey('id') ? nestedData : null);

      if (rawUserData != null && rawUserData is Map) {
        final user = UserModel.fromJson(Map<String, dynamic>.from(rawUserData));

        final bool isHostelCheckExempt = user.role == UserRole.admin ||
            user.role == UserRole.superAdmin ||
            user.hostel == null ||
            user.hostel!.isEmpty;

        if (!isHostelCheckExempt && user.hostel != hostel) {
          await ApiService.clearToken();
          if (!context.mounted) return null;
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                hostel == 'boys'
                    ? "Bu login O'g'il bolalar yotoqxonasiga tegishli emas."
                    : "Bu login Qiz bolalar yotoqxonasiga tegishli emas.",
              ),
            ),
          );
          return null;
        }

        if (!context.mounted) return null;
        Navigator.of(context).pop();
        return user;
      }
    } on ApiException catch (e) {
      debugPrint('ℹ️ Laravel login javobi: ${e.message}');
      // FIX: avval bu yerda 401/403/422 kelganda darhol xato ko'rsatib
      // to'xtar edik. Lekin ilovada ro'yxatdan o'tish (registerAndLoginUser)
      // FAQAT Firebase'ga yozadi, Laravel'ga umuman yozmaydi — shuning
      // uchun o'zi ro'yxatdan o'tgan har bir talaba uchun Laravel doim
      // "topilmadi" (401/422) deb javob berardi va login shu yerda
      // muvaffaqiyatsiz to'xtab qolardi, pastdagi Firebase Auth
      // tekshiruviga hech qachon yetib bormas edi. Endi bu holatda ham
      // kod pastga — Firebase Auth zaxira tekshiruviga — o'tadi.
    } catch (e) {
      debugPrint(
          'ℹ️ Laravel API ulanishida xatolik: $e. Firebase Auth orqali tekshirilmoqda...');
    }

    // 2. Firebase Auth zaxira tekshiruvi (agar Laravel API serveri vaqtinchalik uzoqda bo'lsa)
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: inputEmail,
        password: inputPassword,
      );

      final uid = credential.user!.uid;
      final docSnap = await _usersCollection.doc(uid).get();

      if (!context.mounted) return null;
      Navigator.of(context).pop();

      if (docSnap.exists) {
        final docData = docSnap.data() as Map<String, dynamic>;
        final user = UserModel.fromJson(docData);

        final bool isHostelCheckExempt = user.role == UserRole.admin ||
            user.role == UserRole.superAdmin ||
            user.hostel == null;

        if (!isHostelCheckExempt && user.hostel != hostel) {
          await FirebaseAuth.instance.signOut();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                hostel == 'boys'
                    ? "Bu login O'g'il bolalar yotoqxonasiga tegishli emas."
                    : "Bu login Qiz bolalar yotoqxonasiga tegishli emas.",
              ),
            ),
          );

          return null;
        }

        return user;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Hisob topildi, lekin profil ma'lumotlari yo'q. Administratorga murojaat qiling."),
              backgroundColor: Colors.red),
        );
        return null;
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return null;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_friendlyAuthError(e)), backgroundColor: Colors.red),
      );
      return null;
    } catch (e) {
      if (!context.mounted) return null;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Login xatoligi: $e"), backgroundColor: Colors.red),
      );
      return null;
    }
  }

  // ✅ ADMIN tomonidan boshqa foydalanuvchining parolini yangilash.
  // Laravel API orqali amalga oshiriladi (PUT /api/students/{id}/password).
  static Future<void> adminResetPassword(String uid, String newPassword) async {
    try {
      await ApiService().put('students/$uid/password', body: {
        'new_password': newPassword,
        'new_password_confirmation': newPassword,
      });
    } catch (e) {
      throw Exception("Parolni yangilashda xatolik: $e");
    }
  }

  // ✅ Foydalanuvchini tizimdan o'chirish.
  // Laravel API orqali amalga oshiriladi (DELETE /api/students/{id}).
  static Future<void> deleteUserAccount(String uid) async {
    try {
      await ApiService().delete('students/$uid');
    } catch (e) {
      throw Exception("Foydalanuvchini o'chirishda xatolik: $e");
    }
  }
}