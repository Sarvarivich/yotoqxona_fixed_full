<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('notifications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnUpdate()->cascadeOnDelete();
            $table->string('title');
            $table->text('message')->nullable();
            $table->string('type', 50)->nullable(); // general, payment, room, application, warning
            $table->boolean('is_read')->default(false)->index();
            $table->timestamps();

            $table->index(['user_id', 'is_read']);
        });

        Schema::create('announcements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('title');
            $table->text('message')->nullable();
            $table->string('target_hostel', 20)->nullable(); // boys, girls, all
            $table->string('target_role', 50)->nullable(); // all, talaba, mudir, etc.
            $table->foreignUuid('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('announcements');
        Schema::dropIfExists('notifications');
    }
};
