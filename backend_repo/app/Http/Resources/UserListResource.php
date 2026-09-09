<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Ro'yxatlar uchun yengil variant.
 *
 * Bu yerda JSHSHIR, pasport, tug'ilgan sana va manzil ATAYLAB yo'q —
 * ro'yxatda ular kerak emas, tafsilot ekranida esa UserResource
 * ishlatiladi. 2500 talabada bu javob hajmini bir necha barobar
 * kamaytiradi va shaxsiy ma'lumot keraksiz joyda tarqalmaydi.
 */
class UserListResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $assignment = $this->whenLoaded('activeRoomAssignment');

        return [
            'id' => $this->id,
            'full_name' => $this->full_name,
            'email' => $this->email,
            'phone' => $this->phone,
            'role' => $this->role,
            'hostel' => $this->hostel,
            'faculty' => $this->faculty,
            'course' => $this->course,
            'group_name' => $this->group_name,
            'is_active' => $this->is_active,
            'created_at' => $this->created_at,

            // Flutter'dagi UserModel xona ID'sini shu yerdan o'qiydi.
            // Faqat kerakli maydonlar qoldirilgan - to'liq bog'langan
            // obyekt emas.
            'active_room_assignment' => $this->when(
                $assignment instanceof \App\Models\RoomStudent,
                fn () => [
                    'id' => $assignment->id,
                    'room_id' => $assignment->room_id,
                    'status' => $assignment->status,
                    'room' => $assignment->relationLoaded('room') && $assignment->room
                        ? [
                            'id' => $assignment->room->id,
                            'room_number' => $assignment->room->room_number,
                            'floor' => $assignment->room->floor,
                        ]
                        : null,
                ]
            ),
        ];
    }
}
