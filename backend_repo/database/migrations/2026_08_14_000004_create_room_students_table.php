<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('room_students', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('room_id')->constrained('rooms')->cascadeOnUpdate()->cascadeOnDelete();
            $table->foreignUuid('student_id')->constrained('users')->cascadeOnUpdate()->restrictOnDelete();
            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('unassigned_at')->nullable();
            $table->string('status', 30)->default('active')->index(); // active, moved, checked_out
            $table->timestamps();

            $table->index(['room_id', 'status']);
            $table->index(['student_id', 'status']);
        });
    }

    public function down(): void {
        Schema::dropIfExists('room_students');
    }
};
