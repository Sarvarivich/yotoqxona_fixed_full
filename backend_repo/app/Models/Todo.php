<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Todo extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'owner_id',
        'parent_id',
        'title',
        'completed',
        'sort_order',
    ];

    protected function casts(): array
    {
        return [
            'completed' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function owner()
    {
        return $this->belongsTo(User::class, 'owner_id');
    }
}
