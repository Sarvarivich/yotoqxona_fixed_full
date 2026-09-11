<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Room;
use App\Models\Hostel;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class RoomController extends Controller
{
    /**
     * Xonalar ro'yxati
     */
    public function index(Request $request)
    {
        $query = Room::with(['hostel', 'activeStudents']);

        if ($request->filled('hostel_id')) {
            $query->where('hostel_id', $request->hostel_id);
        }

        if ($request->filled('hostel_type')) {
            $query->where('hostel_type', $request->hostel_type);
        }

        if ($request->filled('floor')) {
            $query->where('floor', $request->floor);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('search')) {
            $search = trim($request->search);
            $query->where('room_number', 'like', "%{$search}%");
        }

        $rooms = $query->orderBy('room_number', 'asc')->get();

        return response()->json([
            'success' => true,
            'data' => $rooms,
        ]);
    }

    /**
     * Yangi xona qo'shish
     */
    public function store(Request $request)
    {
        if (!$request->filled('hostel_id')) {
            $hostelCode = $request->input('hostel', $request->input('hostel_type', 'boys'));
            $matchedHostel = Hostel::where('code', $hostelCode)->first() ?? Hostel::first();
            if ($matchedHostel) {
                $request->merge(['hostel_id' => $matchedHostel->id]);
            }
        }

        $validator = Validator::make($request->all(), [
            'hostel_id' => 'required|exists:hostels,id',
            'room_number' => 'required|string|max:50',
            'hostel_type' => 'nullable|string',
            'floor' => 'nullable|integer',
            'capacity' => 'required|integer|min:1',
            'price_per_month' => 'nullable|numeric|min:0',
            'facilities' => 'nullable|array',
            'amenities' => 'nullable|array',
            'notes' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Ma\'lumotlar xato kiritildi.',
                'errors' => $validator->errors()
            ], 422);
        }

        // Takroriy xona raqamini oldindan tekshiramiz.
        //
        // Bazada unique(['hostel_id', 'hostel_type', 'room_number'])
        // sharti bor. Uni tekshirmasdan Room::create() chaqirsak,
        // baza xatosi 500 bo'lib chiqadi va foydalanuvchi
        // 'Server Error' ko'radi. Bu yerda 422 va tushunarli
        // xabar beramiz.
        $turi = $request->hostel_type ?? 'boys';

        $mavjud = Room::where('hostel_id', $request->hostel_id)
            ->where('hostel_type', $turi)
            ->where('room_number', $request->room_number)
            ->exists();

        if ($mavjud) {
            return response()->json([
                'success' => false,
                'message' => "Bu yotoqxonada {$request->room_number}-xona allaqachon mavjud.",
                'errors' => [
                    'room_number' => [
                        "{$request->room_number}-xona allaqachon ro'yxatda bor.",
                    ],
                ],
            ], 422);
        }

        $room = Room::create([
            'hostel_id' => $request->hostel_id,
            'room_number' => $request->room_number,
            'hostel_type' => $request->hostel_type ?? 'boys',
            'floor' => $request->floor ?? 1,
            'capacity' => $request->capacity,
            'current_occupants' => 0,
            'price_per_month' => $request->price_per_month ?? 0,
            'status' => 'empty',
            'facilities' => $request->facilities,
            'amenities' => $request->amenities,
            'notes' => $request->notes,
        ]);

        $room->load('hostel');

        return response()->json([
            'success' => true,
            'message' => 'Xona muvaffaqiyatli qo\'shildi.',
            'data' => $room,
        ], 201);
    }

    /**
     * Bitta xonani ko'rish
     */
    public function show($id)
    {
        $room = Room::with(['hostel', 'activeStudents'])->find($id);

        if (!$room) {
            return response()->json(['message' => 'Xona topilmadi.'], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $room,
        ]);
    }

    /**
     * Xonani tahrirlash
     */
    public function update(Request $request, $id)
    {
        $room = Room::find($id);
        if (!$room) {
            return response()->json(['message' => 'Xona topilmadi.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'room_number' => 'sometimes|string|max:50',
            'floor' => 'nullable|integer',
            'capacity' => 'sometimes|integer|min:1',
            'price_per_month' => 'nullable|numeric|min:0',
            'status' => 'nullable|string',
            'facilities' => 'nullable|array',
            'amenities' => 'nullable|array',
            'notes' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $room->update($request->all());
        $room->updateOccupancy();
        $room->load(['hostel', 'activeStudents']);

        return response()->json([
            'success' => true,
            'message' => 'Xona muvaffaqiyatli yangilandi.',
            'data' => $room,
        ]);
    }

    /**
     * Xonani o'chirish
     */
    public function destroy($id)
    {
        $room = Room::find($id);
        if (!$room) {
            return response()->json(['message' => 'Xona topilmadi.'], 404);
        }

        if ($room->current_occupants > 0) {
            return response()->json([
                'success' => false,
                'message' => 'Xonada talabalar bor. Avval ularni boshqa xonaga o\'tkazing yoki chiqaring.'
            ], 400);
        }

        $room->delete();

        return response()->json([
            'success' => true,
            'message' => 'Xona muvaffaqiyatli o\'chirildi.'
        ]);
    }
}
