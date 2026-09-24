<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * "Parolni almashtirish shart" belgisini qo'shadi.
 *
 * NEGA KERAK
 * ----------
 * 210 talaba bir xil vaqtinchalik parol bilan kiritildi
 * (KuHostel2026), email esa taxmin qilish oson:
 * familiya.ism@ku.uz.
 *
 * Ya'ni har bir talaba boshqasining hisobiga kirib, uning pasport
 * ma'lumotini va to'lovlarini ko'ra oladi. Bu 210 kishilik tizimda
 * jiddiy xavf.
 *
 * Endi birinchi kirishda parol majburiy almashtiriladi.
 *
 * QANDAY ISHLAYDI
 * ---------------
 * - Yangi ustun: must_change_password (boolean, default false)
 * - Mavjud talabalarning hammasiga true qo'yiladi
 * - Login javobida bu belgi qaytadi; ilova uni ko'rib, parol
 *   almashtirish ekraniga yo'naltiradi
 * - Parol almashtirilgach belgi false bo'ladi
 *
 * Xodimlarga (mudir, moliyachi, admin) tegilmaydi - ularning
 * parollari alohida berilgan.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('must_change_password')
                ->default(false)
                ->after('password')
                ->comment('Birinchi kirishda parol majburiy almashtirilsinmi');
        });

        // Mavjud talabalarning hammasi umumiy parol bilan kiritilgan,
        // shuning uchun ularga belgi qo'yamiz.
        DB::table('users')
            ->where('role', 'talaba')
            ->update(['must_change_password' => true]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('must_change_password');
        });
    }
};
