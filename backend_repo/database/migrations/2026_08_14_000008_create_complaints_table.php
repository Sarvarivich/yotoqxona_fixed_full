<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('complaints', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('student_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignUuid('hostel_id')->nullable()->constrained('hostels')->nullOnDelete();
            $table->string('target_role', 50)->nullable()->index(); // mudir, admin, moliyachi
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('category', 100)->nullable(); // texnik, tozalik, shovqin, xona, boshqa
            $table->string('priority', 30)->default('medium'); // low, medium, high, urgent
            $table->string('status', 30)->default('open')->index(); // open, in_progress, resolved, closed
            $table->boolean('is_anonymous')->default(false);
            $table->foreignUuid('assigned_to')->nullable()->constrained('users')->nullOnDelete();
            $table->text('response')->nullable();
            $table->foreignUuid('responded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('responded_by_role', 50)->nullable();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['student_id', 'created_at']);
        });

        Schema::create('complaint_attachments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('complaint_id')->constrained('complaints')->cascadeOnUpdate()->cascadeOnDelete();
            $table->string('category')->nullable();
            $table->string('storage_path');
            $table->string('file_name')->nullable();
            $table->string('file_type', 100)->nullable();
            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('complaint_attachments');
        Schema::dropIfExists('complaints');
    }
};
