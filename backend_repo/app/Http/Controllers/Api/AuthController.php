<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Application;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * Tizimga kirish (Login)
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string',
            'password' => 'required|string',
            'hostel' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Email yoki parol kiritilmadi.',
                'errors' => $validator->errors()
            ], 422);
        }

        $email = trim(strtolower($request->email));
        $user = User::where('email', $email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Email yoki parol noto\'g\'ri.'
            ], 401);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Ushbu hisob bloklangan yoki nofaol.'
            ], 403);
        }

        // Agar hostel tekshiruvi so'ralgan bo'lsa (admin va superAdmin uchun istisno)
        $reqHostel = $request->input('hostel');
        $isHostelExempt = in_array($user->role, ['superAdmin', 'admin']) || empty($user->hostel);

        if ($reqHostel && !$isHostelExempt && $user->hostel !== $reqHostel) {
            return response()->json([
                'success' => false,
                'message' => $reqHostel === 'boys'
                    ? "Bu hisob O'g'il bolalar yotoqxonasiga tegishli emas."
                    : "Bu hisob Qiz bolalar yotoqxonasiga tegishli emas."
            ], 403);
        }

        // Sanctum API Token yaratish
        $token = $user->createToken('ku_hostel_token')->plainTextToken;

        // Active room ma'lumotini biriktirish
        $user->load(['activeRoomAssignment.room.hostel']);

        return response()->json([
            'success' => true,
            'message' => 'Tizimga muvaffaqiyatli kirildi.',
            'token' => $token,
            'user' => $user,
            'data' => $user,
        ]);
    }

    /**
     * Talabaning ro'yxatdan o'tishi (Register)
     */
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'full_name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email',
            'password' => 'required|string|min:6',
            'phone' => 'nullable|string|max:30',
            'hostel' => 'required|string|in:boys,girls',
            'faculty' => 'nullable|string|max:255',
            'course' => 'nullable|integer',
            'group_name' => 'nullable|string|max:100',
            'passport_id' => 'nullable|string|max:50',
            'jshshir' => 'nullable|string|max:50',
            'birth_date' => 'nullable|date',
            'region' => 'nullable|string|max:150',
            'district' => 'nullable|string|max:150',
            'has_social_benefit' => 'nullable|boolean',
            'benefit_type' => 'nullable|string',
            'lost_parent_type' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Ma\'lumotlar to\'liq yoki to\'g\'ri kiritilmadi.',
                'errors' => $validator->errors()
            ], 422);
        }

        $benefitDocPath = null;
        $deathCertPath = null;

        if ($request->hasFile('benefit_document')) {
            $benefitDocPath = $request->file('benefit_document')->store('benefits', 'public');
        }

        if ($request->hasFile('death_certificate')) {
            $deathCertPath = $request->file('death_certificate')->store('death_certificates', 'public');
        }

        $hasBenefit = filter_var($request->input('has_social_benefit', false), FILTER_VALIDATE_BOOLEAN);

        $additionalData = [];
        if ($hasBenefit) {
            $additionalData['hasSocialBenefit'] = true;
            if ($request->benefit_type) $additionalData['benefitType'] = $request->benefit_type;
            if ($request->lost_parent_type) $additionalData['lostParentType'] = $request->lost_parent_type;
            if ($benefitDocPath) $additionalData['benefitDocumentUrl'] = asset('storage/' . $benefitDocPath);
            if ($deathCertPath) $additionalData['deathCertificateUrl'] = asset('storage/' . $deathCertPath);
        }

        $user = User::create([
            'full_name' => trim($request->full_name),
            'email' => trim(strtolower($request->email)),
            'phone' => $request->phone ?? '+998900000000',
            'password' => Hash::make($request->password),
            'role' => 'talaba',
            'hostel' => $request->hostel,
            'faculty' => $request->faculty,
            'course' => $request->course,
            'group_name' => $request->group_name,
            'passport_id' => $request->passport_id,
            'jshshir' => $request->jshshir,
            'birth_date' => $request->birth_date,
            'region' => $request->region,
            'district' => $request->district,
            'registered_by' => 'self',
            'additional_data' => $additionalData,
            'is_active' => true,
        ]);

        // Talaba uchun avtomatik ariza yaratish (2-bosqich - ko'rib chiqilmoqda)
        Application::create([
            'user_id' => $user->id,
            'status' => 'submitted',
            'step' => 2,
            'has_social_benefit' => $hasBenefit,
            'benefit_type' => $request->benefit_type,
            'benefit_document_path' => $benefitDocPath,
            'death_certificate_path' => $deathCertPath,
        ]);

        $token = $user->createToken('ku_hostel_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Ro\'yxatdan muvaffaqiyatli o\'tdingiz.',
            'token' => $token,
            'user' => $user,
            'data' => $user,
        ], 201);
    }

    /**
     * Joriy foydalanuvchi ma'lumotlari (Me)
     */
    public function me(Request $request)
    {
        $user = $request->user();
        $user->load(['activeRoomAssignment.room.hostel', 'applications' => function ($q) {
            $q->latest()->limit(1);
        }]);

        // Talabaning joriy qarzi: eng oxirgi TASDIQLANGAN
        // to'lovda moliyachi kiritgan qoldiq summa.
        //
        // Har bir to'lovdan keyin moliyachi qolgan qarzni
        // qo'lda kiritadi, chunki umumiy summa talabaga
        // qarab turlicha bo'lishi mumkin (imtiyoz, qisman
        // to'lov, kelishuv va hokazo).
        $oxirgiTolov = \App\Models\Payment::where('student_id', $user->id)
            ->where('status', 'approved')
            ->whereNotNull('remaining_amount')
            ->orderByDesc('paid_at')
            ->orderByDesc('created_at')
            ->first();

        $user->setAttribute(
            'current_debt',
            $oxirgiTolov?->remaining_amount
        );

        return response()->json([
            'success' => true,
            'user' => $user,
            'data' => $user,
        ]);
    }

    /**
     * Chiqish (Logout)
     */
    /**
     * Foydalanuvchi o'z profilini tahrirlaydi.
     *
     * PUT /api/students/{id} dan farqi: bu yerda faqat o'z
     * yozuvi o'zgartiriladi va faqat xavfsiz maydonlar qabul
     * qilinadi. Rol, bino va hisob holati bu yo'l bilan
     * o'zgartirilmaydi - ular xodimlar ixtiyorida.
     */
    public function updateProfile(Request $request)
    {
        $user = $request->user();

        $validator = Validator::make($request->all(), [
            'full_name' => 'sometimes|string|max:255',
            'phone' => 'nullable|string|max:30',
            'faculty' => 'nullable|string',
            'course' => 'nullable|integer|min:1|max:6',
            'group_name' => 'nullable|string|max:50',
            'student_id' => 'nullable|string|max:50',
            'region' => 'nullable|string',
            'district' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Ma\'lumotlar xato kiritildi.',
                'errors' => $validator->errors(),
            ], 422);
        }

        // Faqat ruxsat etilgan maydonlar. 'role', 'hostel',
        // 'is_active', 'jshshir', 'passport_id' bu yerda
        // ATAYLAB yo'q.
        $data = $request->only([
            'full_name',
            'phone',
            'faculty',
            'course',
            'group_name',
            'region',
            'district',
        ]);

        $user->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Profil yangilandi.',
            'data' => $user->fresh()->load('activeRoomAssignment.room'),
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Tizimdan muvaffaqiyatli chiqildi.'
        ]);
    }

    /**
     * Parolni o'zgartirish
     */
    public function changePassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:6',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Parol talablari to\'g\'ri kelmadi.',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Joriy parol noto\'g\'ri.'
            ], 400);
        }

        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Parol muvaffaqiyatli yangilandi.'
        ]);
    }

    /**
     * Admin tomonidan parolni tiklash / yangilash
     */
    public function adminResetPassword(Request $request)
    {
        $currentUser = $request->user();
        if (!in_array($currentUser->role, ['superAdmin', 'admin'])) {
            return response()->json(['message' => 'Ruxsat berilmagan.'], 403);
        }

        $validator = Validator::make($request->all(), [
            'uid' => 'required|string',
            'newPassword' => 'required|string|min:6',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $targetUser = User::where('id', $request->uid)
            ->orWhere('firebase_uid', $request->uid)
            ->first();

        if (!$targetUser) {
            return response()->json(['message' => 'Foydalanuvchi topilmadi.'], 404);
        }

        $targetUser->password = Hash::make($request->newPassword);
        $targetUser->save();

        return response()->json([
            'success' => true,
            'message' => 'Foydalanuvchi paroli yangilandi.'
        ]);
    }

    /**
     * Admin tomonidan hisobni o'chirish
     */
    public function deleteUser(Request $request)
    {
        $currentUser = $request->user();
        if (!in_array($currentUser->role, ['superAdmin', 'admin'])) {
            return response()->json(['message' => 'Ruxsat berilmagan.'], 403);
        }

        $uid = $request->input('uid') ?? $request->input('id');
        $targetUser = User::where('id', $uid)
            ->orWhere('firebase_uid', $uid)
            ->first();

        if (!$targetUser) {
            return response()->json(['message' => 'Foydalanuvchi topilmadi.'], 404);
        }

        // Tokenlarini bekor qilish va o'chirish
        $targetUser->tokens()->delete();
        $targetUser->delete();

        return response()->json([
            'success' => true,
            'message' => 'Foydalanuvchi muvaffaqiyatli o\'chirildi.'
        ]);
    }
}
