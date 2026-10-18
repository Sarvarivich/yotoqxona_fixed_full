<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Parol oxirgi marta qachon o'zgartirilganini saqlaydi.
 *
 * Talabalar paroli 40 kunda bir marta almashtirilishi shart.
 * Mavjud talabalarga hozirgi vaqt qo'yiladi, shuning uchun deploy
 * kunidan boshlab 40 kun hisoblanadi (hammasi bir vaqtda majburlanmaydi).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('password_changed_at')
                ->nullable()
                ->after('password');
        });

        DB::table('users')
            ->where('role', 'talaba')
            ->update(['password_changed_at' => now()]);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('password_changed_at');
        });
    }
};
