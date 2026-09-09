<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Bitta foydalanuvchining to'liq kartasi.
 *
 * Shaxsiy maydonlar (JSHSHIR, pasport, tug'ilgan sana, manzil) faqat
 * quyidagilarga ko'rinadi:
 *   - foydalanuvchining o'ziga
 *   - mudir / moliyachi / admin / superAdmin ga
 *
 * Boshqa hollarda ular javobda umuman bo'lmaydi (null emas - yo'q).
 */
class UserResource extends JsonResource
{
    /** Shaxsiy ma'lumotni ko'rishga haqli rollar. */
    private const MASUL_XODIMLAR = ['mudir', 'moliyachi', 'admin', 'superAdmin'];

    public function toArray(Request $request): array
    {
        $viewer = $request->user();

        $ozi = $viewer && $viewer->id === $this->id;
        $xodim = $viewer && in_array($viewer->role, self::MASUL_XODIMLAR, true);
        $korishi_mumkin = $ozi || $xodim;

        $assignment = $this->whenLoaded('activeRoomAssignment');

        return [
            // --- Har doim ko'rinadigan ---
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
            'updated_at' => $this->updated_at,

            // --- Shaxsiy: faqat o'ziga va mas'ul xodimga ---
            'jshshir' => $this->when($korishi_mumkin, $this->jshshir),
            'passport_id' => $this->when($korishi_mumkin, $this->passport_id),
            'birth_date' => $this->when($korishi_mumkin, $this->birth_date),
            'region' => $this->when($korishi_mumkin, $this->region),
            'district' => $this->when($korishi_mumkin, $this->district),
            'additional_data' => $this->when($korishi_mumkin, $this->additional_data),

            // --- Hujjatlar: faqat o'ziga va mas'ul xodimga ---
            'student_card_path' => $this->when($korishi_mumkin, $this->student_card_path),
            'payment_receipt_doc_path' => $this->when($korishi_mumkin, $this->payment_receipt_doc_path),
            'medical_certificate_path' => $this->when($korishi_mumkin, $this->medical_certificate_path),

            // --- Texnik: faqat o'ziga ---
            // firebase_uid va fcm_token boshqalarga kerak emas.
            'firebase_uid' => $this->when($ozi, $this->firebase_uid),
            'fcm_token' => $this->when($ozi, $this->fcm_token),

            // --- Bog'langan ma'lumotlar ---
            'registered_by' => $this->when($xodim, $this->registered_by),

            'active_room_assignment' => $this->when(
                $assignment instanceof \App\Models\RoomStudent,
                fn () => [
                    'id' => $assignment->id,
                    'room_id' => $assignment->room_id,
                    'status' => $assignment->status,
                    'assigned_at' => $assignment->assigned_at ?? null,
                    'room' => $assignment->relationLoaded('room') && $assignment->room
                        ? [
                            'id' => $assignment->room->id,
                            'room_number' => $assignment->room->room_number,
                            'floor' => $assignment->room->floor,
                            'capacity' => $assignment->room->capacity,
                            'current_occupants' => $assignment->room->current_occupants,
                            'price_per_month' => $assignment->room->price_per_month,
                            'hostel' => $assignment->room->relationLoaded('hostel') && $assignment->room->hostel
                                ? [
                                    'id' => $assignment->room->hostel->id,
                                    'name' => $assignment->room->hostel->name,
                                ]
                                : null,
                        ]
                        : null,
                ]
            ),

            // show() metodida yuklanadi, index() da yo'q.
            'payments' => $this->whenLoaded('payments'),
            'applications' => $this->whenLoaded('applications'),
            'complaints' => $this->whenLoaded('complaints'),
        ];
    }
}
