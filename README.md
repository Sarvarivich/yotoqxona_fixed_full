# Yotoqxona PostgreSQL/Laravel migration base

Bu fayllar yangi PostgreSQL bazasini ko'tarish uchun tayyorlangan.
Firebase/Supabase ma'lumotlari hali ko'chirilmaydi va o'chirilmaydi.

1. Laravel loyihasida database/migrations ichiga PHP fayllarni qo'ying.
2. .env da DB_CONNECTION=pgsql va PostgreSQL ulanishini sozlang.
3. `php artisan migrate` ni faqat yangi/test PostgreSQL bazasida ishga tushiring.
4. Keyingi bosqich: Firestore -> PostgreSQL import/mapping skripti.
5. Payment/complaint fayllari public URL emas, storage_path orqali private storage bilan ishlaydi.

girls_attendance, girls_reports, girls_settings hozirgi ko'rsatilgan Firestore hujjatlarida faqat init:true bo'lgani uchun bu paketga taxminiy jadvallar qo'shilmagan.
