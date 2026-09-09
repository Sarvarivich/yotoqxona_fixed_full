<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * JSHSHIR va pasport raqamiga unique index qo'shadi.
 *
 * Sababi: hozir bir xil JSHSHIR bilan ikki talaba ro'yxatdan o'ta
 * oladi. 50 ta qo'lda kiritishda bu sezilmaydi, 2500 tada esa
 * albatta chalkashlik chiqadi va keyin tuzatish qiyin bo'ladi.
 *
 * Index nullable maydonlarda ishlaydi: NULL qiymatlar unique
 * cheklovga tushmaydi, ya'ni JSHSHIR kiritilmagan talabalar
 * bir necha bo'lishi mumkin.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Migratsiya ishga tushmasdan oldin mavjud dublikatlarni
        // tekshiramiz. Agar bor bo'lsa - aniq xabar bilan to'xtaymiz,
        // chunki qaysi yozuvni qoldirish kerakligini faqat odam
        // hal qila oladi.
        $this->dublikatlarniTekshir('jshshir');
        $this->dublikatlarniTekshir('passport_id');

        Schema::table('users', function (Blueprint $table) {
            $table->unique('jshshir', 'users_jshshir_unique');
            $table->unique('passport_id', 'users_passport_id_unique');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique('users_jshshir_unique');
            $table->dropUnique('users_passport_id_unique');
        });
    }

    /**
     * Ustunda takrorlangan qiymat bor-yo'qligini tekshiradi.
     */
    private function dublikatlarniTekshir(string $ustun): void
    {
        $dublikatlar = DB::table('users')
            ->select($ustun, DB::raw('count(*) as soni'))
            ->whereNotNull($ustun)
            ->where($ustun, '!=', '')
            ->groupBy($ustun)
            ->havingRaw('count(*) > 1')
            ->get();

        if ($dublikatlar->isEmpty()) {
            return;
        }

        $royxat = $dublikatlar
            ->map(fn ($d) => "{$d->$ustun} ({$d->soni} marta)")
            ->implode(', ');

        throw new \RuntimeException(
            "'{$ustun}' ustunida takrorlangan qiymatlar bor, shuning uchun "
            . "unique index qo'shib bo'lmadi. Avval ularni tuzating: {$royxat}"
        );
    }
};
