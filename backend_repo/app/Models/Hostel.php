<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Hostel extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'code',
        'name',
        'address',
        'total_rooms',
        'total_capacity',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'total_rooms' => 'integer',
            'total_capacity' => 'integer',
        ];
    }

    public function rooms()
    {
        return $this->hasMany(Room::class);
    }
}
