<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FinanceBudget extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'month_key',
        'year',
        'amount',
        'description',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'float',
            'year' => 'integer',
        ];
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
