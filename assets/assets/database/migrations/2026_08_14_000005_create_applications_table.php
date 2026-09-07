<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
 public function up(): void {
  Schema::create('applications', function (Blueprint $table) {
   $table->uuid('id')->primary();
   $table->foreignUuid('user_id')->nullable()->constrained('users')->nullOnDelete();
   $table->string('status',40)->default('pending')->index();
   $table->unsignedSmallInteger('step')->default(1);
   $table->foreignUuid('hostel_id')->nullable()->constrained('hostels')->nullOnDelete();
   $table->foreignUuid('room_id')->nullable()->constrained('rooms')->nullOnDelete();
   $table->string('assignment_type',50)->nullable();
   $table->text('assignment_message')->nullable();
   $table->timestamp('assigned_at')->nullable();
   $table->string('benefit_type',100)->nullable();
   $table->boolean('has_social_benefit')->default(false);
   $table->string('benefit_document_path')->nullable();
   $table->text('note')->nullable();
   $table->foreignUuid('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
   $table->timestamp('reviewed_at')->nullable();
   $table->timestamps();
   $table->index(['status','created_at']);
   $table->index(['hostel_id','status']);
  });
 }
 public function down(): void { Schema::dropIfExists('applications'); }
};