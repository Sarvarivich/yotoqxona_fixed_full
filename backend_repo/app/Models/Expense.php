<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Expense extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'amount',
        'category',
        'description',
        'date',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'date' => 'date',
        ];
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
