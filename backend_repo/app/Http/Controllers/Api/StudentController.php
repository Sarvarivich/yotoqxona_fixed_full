<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class StudentController extends Controller
{
    /**
     * Talabalar va foydalanuvchilar ro'yxati
     */
    public function index(Request $request)
    {
        $query = User::with(['activeRoomAssignment.room.hostel']);

        if ($request->filled('role')) {
            $query->where('role', $request->role);
        }

        if ($request->filled('hostel')) {
            $query->where('hostel', $request->hostel);
        }

        if ($request->filled('course')) {
            $query->where('course', $request->course);
        }

        if ($request->filled('faculty')) {
            $query->where('faculty', 'like', '%' . $request->faculty . '%');
        }

        if ($request->filled('search')) {
            $search = trim($request->search);
            $query->where(function ($q) use ($search) {
                $q->where('full_name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%")
                  ->orWhere('phone', 'like', "%{$search}%")
                  ->orWhere('passport_id', 'like', "%{$search}%")
                  ->orWhere('jshshir', 'like', "%{$search}%");
            });
        }

        $students = $query->orderBy('full_name', 'asc')->get();

        return response()->json([
            'success' => true,
            'data' => $students,
        ]);
    }

    /**
     * Yangi foydalanuvchi qo'shish (Admin / Mudir)
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'full_name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email',
            'password' => 'required|string|min:6',
            'role' => 'required|string|in:talaba,mudir,moliyachi,admin,superAdmin',
            'hostel' => 'nullable|string|in:boys,girls',
            'phone' => 'nullable|string|max:30',
            'faculty' => 'nullable|string',
            'course' => 'nullable|integer',
            'group_name' => 'nullable|string',
            'passport_id' => 'nullable|string',
            'jshshir' => 'nullable|string',
            'region' => 'nullable|string',
            'district' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Ma\'lumotlar xato kiritildi.',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = User::create([
            'full_name' => trim($request->full_name),
            'email' => trim(strtolower($request->email)),
            'password' => Hash::make($request->password),
            'role' => $request->role,
            'hostel' => $request->hostel ?? 'boys',
            'phone' => $request->phone ?? '+998900000000',
            'faculty' => $request->faculty,
            'course' => $request->course,
            'group_name' => $request->group_name,
            'passport_id' => $request->passport_id,
            'jshshir' => $request->jshshir,
            'region' => $request->region,
            'district' => $request->district,
            'registered_by' => 'admin',
            'is_active' => true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Foydalanuvchi muvaffaqiyatli yaratildi.',
            'data' => $user,
        ], 201);
    }

    /**
     * Bitta foydalanuvchini ko'rish
     */
    public function show($id)
    {
        $user = User::with([
            'activeRoomAssignment.room.hostel',
            'payments',
            'applications',
            'complaints'
        ])->find($id);

        if (!$user) {
            return response()->json(['message' => 'Foydalanuvchi topilmadi.'], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $user,
        ]);
    }

    /**
     * Foydalanuvchini tahrirlash
     */
    public function update(Request $request, $id)
    {
        $user = User::find($id);
        if (!$user) {
            return response()->json(['message' => 'Foydalanuvchi topilmadi.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'full_name' => 'sometimes|string|max:255',
            'email' => 'sometimes|email|unique:users,email,' . $user->id,
            'phone' => 'nullable|string|max:30',
            'faculty' => 'nullable|string',
            'course' => 'nullable|integer',
            'group_name' => 'nullable|string',
            'hostel' => 'nullable|string',
            'role' => 'nullable|string',
            'passport_id' => 'nullable|string',
            'jshshir' => 'nullable|string',
            'region' => 'nullable|string',
            'district' => 'nullable|string',
            'is_active' => 'nullable|boolean',
            'password' => 'nullable|string|min:6',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $data = $request->except(['password']);
        if ($request->filled('password')) {
            $data['password'] = Hash::make($request->password);
        }

        $user->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Ma\'lumotlar muvaffaqiyatli yangilandi.',
            'data' => $user,
        ]);
    }

    /**
     * Foydalanuvchini o'chirish
     */
    public function destroy($id)
    {
        $user = User::find($id);
        if (!$user) {
            return response()->json(['message' => 'Foydalanuvchi topilmadi.'], 404);
        }

        $user->tokens()->delete();
        $user->delete();

        return response()->json([
            'success' => true,
            'message' => 'Foydalanuvchi o\'chirildi.'
        ]);
    }

    /**
     * Admin tomonidan foydalanuvchi parolini yangilash
     */
    public function updatePassword(Request $request, $id)
    {
        $user = User::find($id);
        if (!$user) {
            return response()->json(['message' => 'Foydalanuvchi topilmadi.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'new_password'              => 'required|string|min:6|confirmed',
            'new_password_confirmation' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors'  => $validator->errors(),
            ], 422);
        }

        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Parol muvaffaqiyatli yangilandi.',
        ]);
    }
}
