<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
return new class extends Migration {
 public function up(): void {
  Schema::create('rooms', function (Blueprint $table) {
   $table->uuid('id')->primary();
   $table->foreignUuid('hostel_id')->constrained('hostels')->cascadeOnUpdate()->restrictOnDelete();
   $table->string('room_number',50);
   $table->string('hostel_type',20)->nullable();
   $table->unsignedSmallInteger('floor')->nullable();
   $table->unsignedSmallInteger('capacity')->default(0);
   $table->unsignedSmallInteger('current_occupants')->default(0);
   $table->decimal('price_per_month',14,2)->default(0);
   $table->string('status',30)->default('empty')->index();
   $table->jsonb('facilities')->nullable();
   $table->jsonb('amenities')->nullable();
   $table->timestamp('last_payment_date')->nullable();
   $table->text('notes')->nullable();
   $table->timestamps();
   $table->unique(['hostel_id','room_number']);
  });
 }
 public function down(): void { Schema::dropIfExists('rooms'); }
};