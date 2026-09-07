<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('ratings', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('student_id')->constrained('users')->cascadeOnUpdate()->cascadeOnDelete();
            $table->unsignedSmallInteger('rating');
            $table->text('comment')->nullable();
            $table->timestamps();
        });

        Schema::create('todos', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('owner_id')->nullable()->constrained('users')->nullOnDelete();
            $table->uuid('parent_id')->nullable();
            $table->string('title');
            $table->boolean('completed')->default(false)->index();
            $table->unsignedInteger('sort_order')->default(0);
            $table->timestamps();
        });

        // parent_id o'z-o'ziga (todos.id) ishora qiladi. PostgreSQL'da bunday
        // o'z-o'ziga bog'langan tashqi kalitni jadval to'liq yaratilgach,
        // ALOHIDA ustunda qo'shish kerak (aks holda "no unique constraint"
        // xatosi chiqadi).
        Schema::table('todos', function (Blueprint $table) {
            $table->foreign('parent_id')->references('id')->on('todos')->nullOnDelete();
        });

        Schema::create('offline_tests', function (Blueprint $table) {
            $table->string('id', 100)->primary();
            $table->string('name');
            $table->boolean('is_test')->default(false);
            $table->timestamp('test_time')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('offline_tests');
        Schema::dropIfExists('todos');
        Schema::dropIfExists('ratings');
    }
};
