<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PaymentCheck extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'student_id',
        'amount',
        'file_name',
        'file_type',
        'storage_path',
        'payment_date',
        'status',
        'review_note',
        'reviewed_at',
        'reviewed_by',
        'sent_to_finance',
        'uploaded_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'sent_to_finance' => 'boolean',
            'payment_date' => 'datetime',
            'reviewed_at' => 'datetime',
            'uploaded_at' => 'datetime',
        ];
    }

    public function student()
    {
        return $this->belongsTo(User::class, 'student_id');
    }

    public function reviewer()
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function payment()
    {
        return $this->hasOne(Payment::class);
    }
}
