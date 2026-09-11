<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Xona raqamining takrorlanmasligi shartini tuzatadi.
 *
 * MUAMMO
 * ------
 * Hozir: unique(['hostel_id', 'room_number'])
 *
 * Ilovada to'rt yotoqxona turi bor (university, avto_yol,
 * med_college, navoi_object), `hostels` jadvalida esa faqat ikki
 * bino: boys va girls. RoomController `hostel_type` ni tanimaydi va
 * xonani baribir boys yoki girls binosiga bog'laydi.
 *
 * Natijada "Tibbiyot kolleji" uchun 101-xona yaratmoqchi bo'lsak, u
 * boys binosiga tushadi va u yerdagi mavjud 101-xona bilan
 * to'qnashadi. Baza rad etadi, foydalanuvchi esa "Server Error"
 * ko'radi.
 *
 * YECHIM
 * ------
 * Takrorlanmaslik sharti `hostel_type` ni ham hisobga olsin:
 *   unique(['hostel_id', 'hostel_type', 'room_number'])
 *
 * Shunda har bir yotoqxona turida o'z 101-xonasi bo'lishi mumkin.
 *
 * Bu vaqtinchalik yechim. To'g'ri yo'l — `hostels` jadvaliga to'rtta
 * binoni qo'shish va jinsni alohida ustunda saqlash. Lekin u
 * mavjud ma'lumotni ko'chirishni talab qiladi, shuning uchun
 * keyinroq qilinadi.
 */
return new class extends Migration
{
    public function up(): void
    {
        // hostel_type bo'sh bo'lgan eski yozuvlarni to'ldiramiz —
        // NULL qiymatlar unique indeksda kutilmagan natija beradi.
        DB::table('rooms')
            ->whereNull('hostel_type')
            ->orWhere('hostel_type', '')
            ->update(['hostel_type' => 'boys']);

        Schema::table('rooms', function (Blueprint $table) {
            // Eski shartni olib tashlaymiz.
            $table->dropUnique(['hostel_id', 'room_number']);
        });

        Schema::table('rooms', function (Blueprint $table) {
            // hostel_type 20 belgi edi; 'navoi_object' 12 ta, sig'adi,
            // lekin kelajakda uzunroq nom qo'shilsa joy bo'lsin.
            $table->string('hostel_type', 40)->nullable(false)->default('boys')->change();

            $table->unique(
                ['hostel_id', 'hostel_type', 'room_number'],
                'rooms_hostel_type_number_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::table('rooms', function (Blueprint $table) {
            $table->dropUnique('rooms_hostel_type_number_unique');
        });

        Schema::table('rooms', function (Blueprint $table) {
            $table->string('hostel_type', 20)->nullable()->change();
            $table->unique(['hostel_id', 'room_number']);
        });
    }
};
