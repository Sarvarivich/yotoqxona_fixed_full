<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('users', function (Blueprint $table) {
            $table->string('student_card_path')->nullable()->after('additional_data');
            $table->string('payment_receipt_doc_path')->nullable()->after('student_card_path');
            $table->string('medical_certificate_path')->nullable()->after('payment_receipt_doc_path');
        });
    }

    public function down(): void {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'student_card_path',
                'payment_receipt_doc_path',
                'medical_certificate_path',
            ]);
        });
    }
};
