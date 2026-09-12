<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * To'lovga "qoldiq summa" ustunini qo'shadi.
 *
 * NEGA KERAK
 * ----------
 * Talaba yotoqxona to'lovini bo'lib-bo'lib to'laydi. Moliyachi chekni
 * ko'rib chiqqanda, shu to'lovdan keyin qancha qarz qolganini qo'lda
 * kiritadi — chunki umumiy summa har bir talaba uchun turlicha
 * bo'lishi mumkin (imtiyoz, qisman to'lov, kelishuv va hokazo).
 *
 * Talabaning joriy qarzi = eng oxirgi TASDIQLANGAN to'lovning
 * remaining_amount qiymati. Shu qiymat talaba profilida ham,
 * moliyachi ekranida ham ko'rsatiladi.
 *
 * NULL qoldirilishi mumkin: eski yozuvlarda bu ma'lumot yo'q, va
 * moliyachi kiritmasdan ham chekni tasdiqlay oladi.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->decimal('remaining_amount', 14, 2)
                ->nullable()
                ->after('amount')
                ->comment('Shu to\'lovdan keyin qolgan qarz summasi');
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropColumn('remaining_amount');
        });
    }
};
