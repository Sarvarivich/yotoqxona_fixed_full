// migrate_girls_rooms.dart
//
// BIR MARTALIK MIGRATSIYA SKRIPTI.
//
// Muammo: avval "Qizlar" bo'limida yaratilgan xonalar alohida
// 'girls_rooms' Firestore to'plamiga yozilardi, superAdmin/admin
// esa faqat 'xonalar' to'plamini o'qirdi — shu sabab superAdmin'ga
// yangi qiz xonalari ko'rinmasdi.
//
// Kod endi tuzatildi: bundan buyon qizlar bo'limida yaratiladigan
// barcha yangi xonalar ham to'g'ridan-to'g'ri 'xonalar' to'plamiga
// (hostel: 'girls' bilan) yoziladi va superAdmin ularni darhol ko'radi.
//
// Lekin agar avval 'girls_rooms' to'plamida ESKI (kod tuzatilishidan
// oldin yaratilgan) xonalar mavjud bo'lsa, ular hamon eski to'plamda
// qolib ketgan va superAdmin'ga hali ham ko'rinmaydi. Ushbu skript
// o'sha eski xonalarni bir martaga 'xonalar' to'plamiga ko'chiradi.
//
// ISHLATISH:
// 1) Loyiha papkasiga joylashtiring (masalan: tool/migrate_girls_rooms.dart)
// 2) Terminalda ishga tushiring:  dart run tool/migrate_girls_rooms.dart
//    (Firebase CLI orqali autentifikatsiya yoki servis kaliti sozlangan
//    bo'lishi kerak — yoki shunchaki Flutter ilova ichida bir martalik
//    tugma bosilganda quyidagi funksiyani chaqiring.)
// 3) Muvaffaqiyatli ko'chirilgach, eski 'girls_rooms' to'plamini
//    Firebase konsolidan qo'lda o'chirib tashlashingiz mumkin.

import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> migrateGirlsRooms() async {
  final db = FirebaseFirestore.instance;
  final oldCollection = db.collection('girls_rooms');
  final newCollection = db.collection('xonalar');

  final oldRoomsSnap = await oldCollection.get();

  if (oldRoomsSnap.docs.isEmpty) {
    print('Eski girls_rooms to\'plamida hech narsa topilmadi. Migratsiya shart emas.');
    return;
  }

  int migrated = 0;
  int skipped = 0;

  for (final doc in oldRoomsSnap.docs) {
    final data = Map<String, dynamic>.from(doc.data());
    final roomNumber = data['roomNumber'];

    // Takrorlanishning oldini olish: agar 'xonalar' to'plamida xuddi shu
    // roomNumber + hostel:'girls' bilan hujjat allaqachon mavjud bo'lsa,
    // uni qayta qo'shmaymiz.
    final existing = await newCollection
        .where('roomNumber', isEqualTo: roomNumber)
        .where('hostel', isEqualTo: 'girls')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      skipped++;
      continue;
    }

    data['hostel'] = 'girls';
    data.remove('id');
    await newCollection.add(data);
    migrated++;
  }

  print('Migratsiya tugadi: $migrated ta xona ko\'chirildi, $skipped ta o\'tkazib yuborildi (allaqachon mavjud edi).');
  print('Tekshirib bo\'lgach, Firebase konsolida eski "girls_rooms" to\'plamini qo\'lda o\'chirishingiz mumkin.');
}
