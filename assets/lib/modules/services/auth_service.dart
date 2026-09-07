import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;
import 'dart:convert';
import 'package:yotoqxona/modules/models/user_model.dart';
import 'supabase_storage_service.dart';

// ─── AuthService: endi TO'LIQ Firebase Authentication'ga asoslangan ───
// ✅ Parollar endi Firestore'da ochiq matn (plain text) holida
//    SAQLANMAYDI. Ularni Firebase Authentication o'zi xavfsiz
//    boshqaradi (hash'langan holda). Firestore'dagi `users/{uid}`
//    hujjati faqat profil ma'lumotlarini (ism, rol, telefon va h.k.)
//    saqlaydi, hujjat ID'si esa Firebase Auth UID bilan bir xil bo'ladi.
class AuthService {
  static final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('foydalanuvchilar');

  // ⚠️ BU YERGA O'ZINGIZNING VERCEL DOMENINGIZNI YOZING
  // (masalan: "https://kuhostel.vercel.app")
  static const String _apiBaseUrl = "https://KU-USD.vercel.app";

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
  // ✅ Ikkinchi (vaqtinchalik) Firebase ilova nusxasidan foydalanadi —
  // shunda yangi hisob yaratilganda hozir tizimga kirgan admin/mudir
  // hisobidan avtomatik chiqib ketmaydi.
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
    FirebaseApp? secondaryApp;
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPassword = password.trim();

      try {
        secondaryApp = Firebase.app('SecondaryApp');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
      }

      final credential = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
      final uid = credential.user!.uid;

      final newUser = UserModel(
        id: uid,
        fullName: fullName.trim(),
        email: cleanEmail,
        phoneNumber: phoneNumber?.trim() ?? "+998900000000",
        role: role,
        hostel: hostel,
        faculty: faculty,
        course: course,
      );

      // ✅ MUAMMO: agar quyidagi Firestore yozish (masalan Security Rules
      // yoki tarmoq xatosi tufayli) muvaffaqiyatsiz tugasa, Firebase
      // Authentication'da hisob ALLAQACHON yaratilgan bo'lib qoladi, lekin
      // "foydalanuvchilar" kolleksiyasida profili bo'lmaydi ("orphan"
      // hisob). Natijada bu login/parol bilan keyinroq kirishga urinilganda
      // "Hisob topildi, lekin profil ma'lumotlari yo'q" xatosi chiqadi —
      // ya'ni tashqi ko'rinishda "hisob yaratilgan, lekin kira bo'lmayabdi"
      // holati aynan shu yerdan kelib chiqishi mumkin.
      // ✅ YECHIM: yozishni try/catch bilan o'raymiz va agar u
      // muvaffaqiyatsiz tugasa, yangi yaratilgan Auth hisobini DARHOL
      // o'chiramiz (rollback), shunda orphan hisob umuman qolmaydi va
      // admin xatolikni aniq ko'radi (keyin xohlasa qayta urinib ko'radi).
      try {
        // 🕒 "createdAt" — server vaqti, "registeredBy" — bu yerda
        // Admin/Mudir talabani QO'LDA qo'shayotgani uchun 'admin'.
        // `extraData` eng oxirida yoziladi, shunda kerak bo'lsa
        // chaqiruvchi tomon bu ikkalasini ham ustidan yozib
        // (override) qo'lda boshqacha qiymat bera oladi.
        await _usersCollection.doc(uid).set({
          ...newUser.toJson(),
          'createdAt': FieldValue.serverTimestamp(),
          'registeredBy': 'admin',
          if (extraData != null) ...extraData,
        });

        // ✅ Qo'shimcha xavfsizlik: yozilgandan so'ng darhol o'qib,
        // haqiqatan saqlanganini tasdiqlaymiz. Ba'zi holatlarda Firestore
        // "muvaffaqiyatli" javob qaytarsa-da (masalan offline cache),
        // hujjat serverga yetib bormasligi mumkin.
        final verifySnap = await _usersCollection.doc(uid).get();
        if (!verifySnap.exists) {
          throw Exception(
              "Profil Firestore'da yaratilmadi (write tasdiqlanmadi).");
        }
      } catch (writeError) {
        // Rollback: Auth hisobini o'chiramiz, shunda orphan hisob qolmaydi
        try {
          await credential.user!.delete();
        } catch (_) {
          // Agar shu yerda ham xato bo'lsa (masalan qayta autentifikatsiya
          // talab qilinsa), hech bo'lmasa asl xatoni yuqoriga uzatamiz —
          // shunda kamida Firebase Console'dan qo'lda tozalash mumkin.
        }
        rethrow;
      }

      await FirebaseAuth.instanceFor(app: secondaryApp).signOut();
      await secondaryApp.delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Yangi foydalanuvchi muvaffaqiyatli qo'shildi!"),
              backgroundColor: Colors.green),
        );
      }
      return true;
    } on FirebaseAuthException catch (e) {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_friendlyAuthError(e)),
              backgroundColor: Colors.red),
        );
      }
      return false;
    } catch (e) {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  static Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // ✅ Foydalanuvchini TO'LIQ o'chirish (Firestore + Firebase Authentication).
  // Bitta `deleteUserAccount` Cloud Function'ini chaqiradi — shu tufayli
  // Auth va Firestore hech qachon bir-biridan orqada qolmaydi.
  // (Client SDK boshqa foydalanuvchini Auth'dan o'chira olmaydi, shuning
  // uchun bu amal serverda, Admin SDK yordamida bajariladi.)
  static Future<void> deleteUserAccount(String uid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("Avval tizimga kiring.");
    }
    final idToken = await currentUser.getIdToken();

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/delete-user'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'uid': uid}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
          body['error'] ?? "O'chirishda xatolik: ${response.statusCode}");
    }
  }

  // ✅ ADMIN tomonidan boshqa foydalanuvchining haqiqiy Firebase
  // Authentication parolini yangilash. ESKI USUL faqat Firestore'dagi
  // 'password' maydonini yozardi — bu esa haqiqiy Auth parolini hech
  // qachon o'zgartirmasdi (chunki login Firestore emas, FirebaseAuth
  // orqali tekshiriladi), shu sabab yangi parol bilan kirib bo'lmasdi.
  // Client SDK boshqa foydalanuvchining parolini bevosita o'zgartira
  // olmaydi, shuning uchun bu amal ham (deleteUserAccount kabi) serverda,
  // Admin SDK yordamida bajariladi.
  static Future<void> adminResetPassword(String uid, String newPassword) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("Avval tizimga kiring.");
    }
    final idToken = await currentUser.getIdToken();

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/admin-reset-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'uid': uid, 'newPassword': newPassword}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ??
          "Parolni yangilashda xatolik: ${response.statusCode}");
    }
  }

  // 3. TIZIMGA KIRISH (LOGIN)
  // ✅ Endi Firestore'dan parol solishtirmaydi — haqiqiy Firebase
  // Authentication orqali tekshiradi, keyin profilni UID bo'yicha oladi.
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

    try {
      final inputEmail = email.trim().toLowerCase();
      final inputPassword = password.trim();

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

        debugPrint(
            '🔎 Login: uid=$uid | Firestore role="${docData['role']}" | doc-id="${docSnap.id}"');

        final user = UserModel.fromJson(docData);

        debugPrint("✅ Firestore role = ${docData['role']}");
        debugPrint("✅ Enum role      = ${user.role}");
        debugPrint("=============");
        debugPrint("Firestore hostel = ${user.hostel}");
        debugPrint("Login hostel     = $hostel");
        debugPrint("=============");

        // ✅ ADMIN / SUPERADMIN uchun yotoqxona tekshiruvi chetlab
        // o'tiladi: ularning hisobi Firestore'da faqat bitta hostel
        // qiymatiga ega bo'lsa-da (masalan 'boys'), tizimni umumiy
        // boshqarish uchun ular O'G'IL BOLALAR va QIZ BOLALAR
        // yotoqxonalarining IKKALASIGA HAM kira olishi kerak. Aks
        // holda admin login qilganda "Bu login ... tegishli emas"
        // xatosi bilan har ikkala tomondan ham chiqarib yuborilgan.
        //
        // ✅ Shuningdek, Firestore'da "hostel" maydoni umuman
        // to'ldirilmagan (null) foydalanuvchilar ham chetlab o'tiladi.
        // Masalan moliyachi (yoki boshqa) hisob ataylab ikkala
        // yotoqxonaga ham xizmat qilishi uchun "hostel" qiymati
        // bo'sh (null) qoldirilgan bo'lishi mumkin — bunday hisoblar
        // "global" hisoblanadi va tekshiruvsiz kiritiladi. Aks holda
        // "Firestore hostel = null" bo'lgan har qanday login "Bu
        // login ... tegishli emas" xatosi bilan rad etilardi.
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
        // 🔍 Debug: hujjat topilmagan holatda ham UID'ni chiqaramiz —
        // shu UID bilan "foydalanuvchilar" kolleksiyasida qo'lda
        // hujjat yaratish uchun kerak bo'ladi.
        debugPrint(
            '🔴 Login: uid=$uid uchun "foydalanuvchilar" kolleksiyasida hujjat topilmadi (email=$inputEmail).');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Hisob topildi, lekin profil ma'lumotlari yo'q. Administratorga murojaat qiling."),
              backgroundColor: Colors.red),
        );
        return null;
      }
    } on FirebaseAuthException catch (e) {
      // 🔍 Debug: aniq Firebase xato kodini konsolga chiqaramiz
      debugPrint('🔴 Firebase Auth xato kodi: ${e.code} | Xabar: ${e.message}');
      if (!context.mounted) return null;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_friendlyAuthError(e)), backgroundColor: Colors.red),
      );
      return null;
    } catch (e) {
      debugPrint('🔴 Login xatoligi (kutilmagan): $e');
      if (!context.mounted) return null;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Login xatoligi: $e"), backgroundColor: Colors.red),
      );
      return null;
    }
  }
}
