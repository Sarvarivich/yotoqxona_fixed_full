<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('payment_checks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('student_id')->constrained('users')->cascadeOnUpdate()->restrictOnDelete();
            $table->decimal('amount', 14, 2);
            $table->string('file_name')->nullable();
            $table->string('file_type', 100)->nullable();
            $table->string('storage_path');
            $table->timestamp('payment_date')->nullable();
            $table->string('status', 30)->default('pending')->index(); // pending, approved, rejected
            $table->text('review_note')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->foreignUuid('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->boolean('sent_to_finance')->default(false)->index();
            $table->timestamp('uploaded_at')->nullable();
            $table->timestamps();

            $table->index(['student_id', 'status']);
        });
    }

    public function down(): void {
        Schema::dropIfExists('payment_checks');
    }
};
