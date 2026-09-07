<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('student_id')->constrained('users')->cascadeOnUpdate()->restrictOnDelete();
            $table->foreignUuid('payment_check_id')->nullable()->constrained('payment_checks')->nullOnDelete();
            $table->foreignUuid('hostel_id')->nullable()->constrained('hostels')->nullOnDelete();
            $table->foreignUuid('room_id')->nullable()->constrained('rooms')->nullOnDelete();
            $table->decimal('amount', 14, 2);
            $table->string('method', 50)->default('bank_transfer'); // click, payme, bank_transfer, cash
            $table->string('period', 50)->nullable(); // e.g. "Sentabr 2026", "2026-2027"
            $table->string('status', 30)->default('pending')->index(); // pending, approved, rejected
            $table->text('note')->nullable();
            $table->string('receipt_path')->nullable();
            $table->foreignUuid('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->index(['student_id', 'period']);
            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void {
        Schema::dropIfExists('payments');
    }
};
