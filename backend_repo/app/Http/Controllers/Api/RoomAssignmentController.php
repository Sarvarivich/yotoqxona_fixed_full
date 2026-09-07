<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Room;
use App\Models\RoomStudent;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class RoomAssignmentController extends Controller
{
    /**
     * Barcha xonaga biriktirishlar ro'yxati
     */
    public function index(Request $request)
    {
        $query = RoomStudent::with(['room.hostel', 'student'])
            ->where('status', 'active');

        if ($request->filled('hostel')) {
            $query->whereHas('room', function ($q) use ($request) {
                $q->where('hostel_type', $request->hostel);
            });
        }

        $assignments = $query->orderBy('created_at', 'desc')->get();

        return response()->json([
            'success' => true,
            'data' => $assignments,
        ]);
    }

    /**
     * Talabani xonaga biriktirish
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'student_id' => 'required|exists:users,id',
            'room_id' => 'required|exists:rooms,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Talaba yoki xona tanlanmadi.',
                'errors' => $validator->errors()
            ], 422);
        }

        $room = Room::findOrFail($request->room_id);
        $student = User::findOrFail($request->student_id);

        if ($room->current_occupants >= $room->capacity) {
            return response()->json([
                'success' => false,
                'message' => 'Bu xonada bo\'sh joy qolmagan.'
            ], 400);
        }

        DB::transaction(function () use ($room, $student) {
            // Avvalgi aktiv xonasidan chiqarish
            $oldAssignments = RoomStudent::where('student_id', $student->id)
                ->where('status', 'active')
                ->get();

            foreach ($oldAssignments as $old) {
                $old->update([
                    'status' => 'moved',
                    'unassigned_at' => now(),
                ]);
                $old->room->updateOccupancy();
            }

            // Yangi xonaga biriktirish
            RoomStudent::create([
                'room_id' => $room->id,
                'student_id' => $student->id,
                'assigned_at' => now(),
                'status' => 'active',
            ]);

            $room->updateOccupancy();
        });

        $assignment = RoomStudent::with(['room.hostel', 'student'])
            ->where('student_id', $student->id)
            ->where('status', 'active')
            ->first();

        return response()->json([
            'success' => true,
            'message' => 'Talaba xonaga muvaffaqiyatli biriktirildi.',
            'data' => $assignment,
        ], 201);
    }

    /**
     * Talabani xonadan chiqarish
     */
    public function destroy($id)
    {
        $assignment = RoomStudent::where('id', $id)
            ->orWhere(function ($q) use ($id) {
                $q->where('student_id', $id)->where('status', 'active');
            })
            ->first();

        if (!$assignment) {
            return response()->json(['message' => 'Biriktirish topilmadi.'], 404);
        }

        $room = $assignment->room;

        $assignment->update([
            'status' => 'checked_out',
            'unassigned_at' => now(),
        ]);

        if ($room) {
            $room->updateOccupancy();
        }

        return response()->json([
            'success' => true,
            'message' => 'Talaba xonadan chiqarildi.'
        ]);
    }

    /**
     * Talabaning o'z xonasi (My Room)
     */
    public function myRoom(Request $request)
    {
        $user = $request->user();

        $assignment = RoomStudent::with(['room.hostel', 'room.activeStudents'])
            ->where('student_id', $user->id)
            ->where('status', 'active')
            ->first();

        if (!$assignment || !$assignment->room) {
            return response()->json([
                'success' => true,
                'data' => null,
                'message' => 'Sizga hali xona biriktirilmagan.'
            ]);
        }

        $room = $assignment->room;

        return response()->json([
            'success' => true,
            'data' => [
                'id' => $room->id,
                'room_number' => $room->room_number,
                'floor' => $room->floor,
                'capacity' => $room->capacity,
                'current_occupants' => $room->current_occupants,
                'price_per_month' => $room->price_per_month,
                'status' => $room->status,
                'facilities' => $room->facilities ?? [],
                'amenities' => $room->amenities ?? [],
                'notes' => $room->notes,
                'hostel' => $room->hostel,
                'assigned_at' => $assignment->assigned_at,
                'roommates' => $room->activeStudents->map(function ($s) {
                    return [
                        'id' => $s->id,
                        'full_name' => $s->full_name,
                        'faculty' => $s->faculty,
                        'course' => $s->course,
                        'phone' => $s->phone,
                    ];
                }),
            ]
        ]);
    }
}
