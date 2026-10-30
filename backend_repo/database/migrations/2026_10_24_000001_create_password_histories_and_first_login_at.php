<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. users jadvaliga first_login_at ustunini qo'shamiz
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('first_login_at')->nullable()->after('password_changed_at');
        });

        // Mavjud foydalanuvchilar uchun password_changed_at null bo'lsa, now() o'rnatamiz
        DB::table('users')
            ->whereNull('password_changed_at')
            ->update(['password_changed_at' => now()]);

        // 2. password_histories jadvalini yaratamiz
        Schema::create('password_histories', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('password');
            $table->timestamp('created_at')->useCurrent();

            $table->index(['user_id', 'created_at']);
        });

        // 3. Mavjud foydalanuvchilarning joriy parollarini tarixga kiritamiz
        $existingUsers = DB::table('users')
            ->whereNotNull('password')
            ->where('password', '!=', '')
            ->get(['id', 'password']);

        $now = now();
        $inserts = [];
        foreach ($existingUsers as $u) {
            $inserts[] = [
                'user_id' => $u->id,
                'password' => $u->password,
                'created_at' => $now,
            ];
        }

        if (!empty($inserts)) {
            // Chunk qilib kiritamiz
            foreach (array_chunk($inserts, 100) as $chunk) {
                DB::table('password_histories')->insert($chunk);
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('password_histories');

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('first_login_at');
        });
    }
};
