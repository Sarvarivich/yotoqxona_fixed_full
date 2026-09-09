import 'package:flutter/material.dart';
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
  static Future<void> registerAndLoginUser({
    required BuildContext context,
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    required String hostel, // "boys" yoki "girls" — talaba ro'yxatdan
    // o'tishda tanlaydi, keyin login qilganda faqat shu yotoqxonaga kiradi
    String? phoneNumber,
    String? faculty,
    String? course,
    String? passportId,
    String? jshshir,
    DateTime? birthDate,
    String? region,
    String? district,
    // 🎗️ Ijtimoiy imtiyoz — talaba ro'yxatdan o'tishda tanlagan bo'lsa
    bool hasSocialBenefit = false,
    String? benefitType, // '1'..'6'
    String? lostParentType, // faqat benefitType == '1' uchun: 'ota'/'ona'
    PlatformFile? deathCertificateFile, // 1-tur uchun o'lim varaqasi (PDF)
    PlatformFile? benefitDocumentFile, // 2—6 turlar uchun ma'lumotnoma
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPassword = password.trim();

      // ✅ Firebase Authentication orqali haqiqiy hisob yaratamiz.
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      final uid = credential.user!.uid;

      // 🎗️ Ijtimoiy imtiyoz hujjatlari — tanlangan bo'lsa, Supabase
      // Storage'ga yuklaymiz (Firebase Storage emas — u to'lovli Blaze
      // tarifini talab qiladi, Supabase esa bepul tarifda ham to'liq
      // ishlaydi va loyihada allaqachon ulangan). MUHIM: agar yuklash
      // muvaffaqiyatsiz tugasa ham, bu BUTUN ro'yxatdan o'tishni
      // to'xtatib qo'ymasligi kerak — aks holda Firebase Auth hisobi
      // allaqachon yaratilgan bo'ladi-yu, Firestore profili yozilmay
      // qoladi va talaba tizimga kira olmay qoladi. Shu sabab xatolik
      // faqat "warning" sifatida saqlanadi va ro'yxatdan o'tish
      // oxirigacha davom etadi — hujjatni talaba keyinroq profilidan
      // qayta yuklashi mumkin.
      String? deathCertificateUrl;
      String? benefitDocumentUrl;
      String? documentUploadWarning;

      if (hasSocialBenefit &&
          benefitType == '1' &&
          deathCertificateFile != null) {
        if (deathCertificateFile.bytes == null) {
          documentUploadWarning =
              "Ro'yxatdan o'tish muvaffaqiyatli, lekin o'lim varaqasi fayli o'qilmadi. Buni profilingizdan keyinroq qayta yuklashingiz mumkin.";
        } else {
          try {
            deathCertificateUrl =
                await SupabaseStorageService.instance.uploadStudentDocument(
              bytes: deathCertificateFile.bytes!,
              studentId: uid,
              fileName: deathCertificateFile.name,
              documentType: 'death_certificate',
            );
          } catch (e) {
            documentUploadWarning =
                "Ro'yxatdan o'tish muvaffaqiyatli, lekin o'lim varaqasini yuklashda xatolik yuz berdi (${_friendlyUploadError(e)}). Buni profilingizdan keyinroq qayta yuklashingiz mumkin.";
          }
        }
      } else if (hasSocialBenefit &&
          benefitType != null &&
          benefitType != '1' &&
          benefitDocumentFile != null) {
        if (benefitDocumentFile.bytes == null) {
          documentUploadWarning =
              "Ro'yxatdan o'tish muvaffaqiyatli, lekin ma'lumotnoma fayli o'qilmadi. Buni profilingizdan keyinroq qayta yuklashingiz mumkin.";
        } else {
          try {
            benefitDocumentUrl =
                await SupabaseStorageService.instance.uploadStudentDocument(
              bytes: benefitDocumentFile.bytes!,
              studentId: uid,
              fileName: benefitDocumentFile.name,
              documentType: 'benefit_document_$benefitType',
            );
          } catch (e) {
            documentUploadWarning =
                "Ro'yxatdan o'tish muvaffaqiyatli, lekin ma'lumotnomani yuklashda xatolik yuz berdi (${_friendlyUploadError(e)}). Buni profilingizdan keyinroq qayta yuklashingiz mumkin.";
          }
        }
      }

      final benefitData = <String, dynamic>{
        if (hasSocialBenefit) 'hasSocialBenefit': true,
        if (hasSocialBenefit && benefitType != null) 'benefitType': benefitType,
        if (lostParentType != null) 'lostParentType': lostParentType,
        if (deathCertificateUrl != null)
          'deathCertificateUrl': deathCertificateUrl,
        if (benefitDocumentUrl != null)
          'benefitDocumentUrl': benefitDocumentUrl,

        // 🏠 Yotoqxona arizasi holati:
        // 1-bosqich — ariza to'ldirilmoqda (register oynasi),
        // yuborilgach darhol 2-bosqich — "ko'rib chiqilmoqda".
        'applicationStep': 2,
        'applicationStatus': 'submitted',
      };

      final newUser = UserModel(
        id: uid,
        fullName: fullName.trim(),
        email: cleanEmail,
        phoneNumber: phoneNumber?.trim() ?? "+998900000000",
        role: role,
        hostel: hostel,
        faculty: faculty,
        course: course,
        passportId: passportId?.trim(),
        jshshir: jshshir?.trim(),
        birthDate: birthDate,
        region: region,
        district: district,
        additionalData: benefitData.isEmpty ? null : benefitData,
      );

      // ✅ Firestore hujjat ID'si endi Auth UID bilan bir xil, va
      // parol maydoni umuman yozilmaydi.
      // 🕒 "createdAt" — server vaqti bilan qo'yiladi (klient soati
      // noto'g'ri bo'lsa ham to'g'ri vaqt saqlanadi), "registeredBy" —
      // bu yerda talaba O'ZI ro'yxatdan o'tayotgani uchun 'self'.
      await _usersCollection.doc(uid).set({
        ...newUser.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'registeredBy': 'self',
        'applicationStep': 2,
        'applicationStatus': 'submitted',
        'applicationSubmittedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (documentUploadWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(documentUploadWarning),
            backgroundColor: const Color(0xFFffb020),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Muvaffaqiyatli ro'yxatdan o'tdingiz!"),
              backgroundColor: Colors.green),
        );
      }

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_friendlyAuthError(e)), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Xatolik yuz berdi: $e"),
            backgroundColor: Colors.red),
      );
    }
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