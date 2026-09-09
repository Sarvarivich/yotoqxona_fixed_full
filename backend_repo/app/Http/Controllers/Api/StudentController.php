<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserListResource;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class StudentController extends Controller
{
    /**
     * Tahrirlashda ruxsat etilgan maydonlar.
     *
     * MUHIM: 'role' va 'is_active' bu ro'yxatda ATAYLAB yo'q — ular
     * alohida tekshiruvdan keyin qo'shiladi. Ilgari bu metod
     * $request->except(['password']) bilan barcha maydonni ko'r-ko'rona
     * yozardi, shuning uchun mudir {"role":"superAdmin"} yuborib o'zini
     * ko'tara olardi.
     */
    private const TAHRIRLASH_MUMKIN = [
        'full_name',
        'email',
        'phone',
        'faculty',
        'course',
        'group_name',
        'hostel',
        'passport_id',
        'jshshir',
        'region',
        'district',
    ];

    /**
     * Paginatsiyasiz so'rovda qaytariladigan eng ko'p yozuv soni.
     *
     * Eski Flutter ekranlari 'per_page' yubormaydi va to'liq massiv
     * kutadi. Ular buzilmasin uchun massiv qaytaramiz, lekin 2500 ta
     * yozuv bir so'rovda kelmasligi uchun cheklab qo'yamiz.
     *
     * Frontend cheksiz aylantirishga o'tgach bu shart olib tashlanadi
     * va paginatsiya majburiy qilinadi.
     */
    private const CHEKSIZ_SORAGANDA_LIMIT = 100;

    /**
     * Talabalar va foydalanuvchilar ro'yxati.
     *
     * Mudir faqat o'z binosidagi foydalanuvchilarni ko'radi.
     * Javobda shaxsiy maydonlar (JSHSHIR, pasport, manzil) yo'q —
     * ular faqat show() da, UserResource orqali beriladi.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        if ($user->cannot('viewAny', User::class)) {
            return response()->json([
                'success' => false,
                'message' => 'Ro\'yxatni ko\'rish uchun ruxsat yo\'q.',
            ], 403);
        }

        $query = User::with(['activeRoomAssignment.room']);

        // Mudir o'z binosi bilan cheklanadi. Moliyachi to'lovlar uchun
        // barchani ko'rishi kerak, admin va superAdmin uchun cheklov yo'q.
        if ($user->role === 'mudir' && !empty($user->hostel)) {
            $query->where('hostel', $user->hostel);
        }

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
            // PostgreSQL'da LIKE katta-kichik harfni farqlaydi,
            // SQLite'da esa yo'q. LOWER() bilan ikkala bazada ham
            // bir xil, registrga sezgir bo'lmagan qidiruv olamiz.
            $kichik = '%' . mb_strtolower($search) . '%';

            $query->where(function ($q) use ($kichik) {
                $q->whereRaw('LOWER(full_name) LIKE ?', [$kichik])
                  ->orWhereRaw('LOWER(email) LIKE ?', [$kichik])
                  ->orWhereRaw('LOWER(phone) LIKE ?', [$kichik])
                  ->orWhereRaw('LOWER(passport_id) LIKE ?', [$kichik])
                  ->orWhereRaw('LOWER(jshshir) LIKE ?', [$kichik]);
            });
        }

        $query->orderBy('full_name', 'asc');

        // per_page berilsa — to'liq sahifalangan javob (meta bilan).
        if ($request->filled('per_page')) {
            $perPage = min(max($request->integer('per_page'), 1), 100);
            $sahifa = $query->paginate($perPage);

            return response()->json([
                'success' => true,
                'data' => UserListResource::collection($sahifa->items()),
                'meta' => [
                    'current_page' => $sahifa->currentPage(),
                    'last_page' => $sahifa->lastPage(),
                    'per_page' => $sahifa->perPage(),
                    'total' => $sahifa->total(),
                ],
            ]);
        }

        // per_page berilmasa — eski shakl (oddiy massiv), lekin cheklangan.
        $jami = (clone $query)->count();
        $royxat = $query->limit(self::CHEKSIZ_SORAGANDA_LIMIT)->get();

        return response()->json([
            'success' => true,
            'data' => UserListResource::collection($royxat),
            'meta' => [
                'total' => $jami,
                'returned' => $royxat->count(),
                'limited' => $jami > self::CHEKSIZ_SORAGANDA_LIMIT,
                'hint' => $jami > self::CHEKSIZ_SORAGANDA_LIMIT
                    ? 'Barcha yozuvlarni olish uchun ?per_page=50&page=1 ishlating.'
                    : null,
            ],
        ]);
    }

    /**
     * Yangi foydalanuvchi qo'shish.
     *
     * Talaba hisobini mudir ham ocha oladi, xodim hisobini esa
     * faqat superAdmin.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'full_name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email',
            'password' => 'required|string|min:8',
            'role' => 'required|string|in:talaba,mudir,moliyachi,admin,superAdmin',
            'hostel' => 'nullable|string|in:boys,girls',
            'phone' => 'nullable|string|max:30',
            'faculty' => 'nullable|string',
            'course' => 'nullable|integer',
            'group_name' => 'nullable|string',
            'passport_id' => 'nullable|string|unique:users,passport_id',
            'jshshir' => 'nullable|string|unique:users,jshshir',
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

        $actor = $request->user();

        if ($actor->cannot('create', [User::class, $request->role])) {
            return response()->json([
                'success' => false,
                'message' => $request->role === 'talaba'
                    ? 'Foydalanuvchi yaratish uchun ruxsat yo\'q.'
                    : 'Xodim hisobini faqat superAdmin ocha oladi.',
            ], 403);
        }

        // Mudir faqat o'z binosiga talaba qo'sha oladi.
        $hostel = $request->hostel ?? 'boys';
        if ($actor->role === 'mudir' && !empty($actor->hostel)) {
            $hostel = $actor->hostel;
        }

        $user = User::create([
            'full_name' => trim($request->full_name),
            'email' => trim(strtolower($request->email)),
            'password' => Hash::make($request->password),
            'role' => $request->role,
            'hostel' => $hostel,
            'phone' => $request->phone ?? '+998900000000',
            'faculty' => $request->faculty,
            'course' => $request->course,
            'group_name' => $request->group_name,
            'passport_id' => $request->passport_id,
            'jshshir' => $request->jshshir,
            'region' => $request->region,
            'district' => $request->district,
            'registered_by' => $actor->role,
            'is_active' => true,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Foydalanuvchi muvaffaqiyatli yaratildi.',
            'data' => new UserResource($user),
        ], 201);
    }

    /**
     * Bitta foydalanuvchini ko'rish.
     */
    public function show(Request $request, $id)
    {
        $user = User::with([
            'activeRoomAssignment.room.hostel',
            'payments',
            'applications',
            'complaints'
        ])->find($id);

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Foydalanuvchi topilmadi.',
            ], 404);
        }

        if ($request->user()->cannot('view', $user)) {
            return response()->json([
                'success' => false,
                'message' => 'Bu foydalanuvchini ko\'rish uchun ruxsat yo\'q.',
            ], 403);
        }

        return response()->json([
            'success' => true,
            'data' => new UserResource($user),
        ]);
    }

    /**
     * Foydalanuvchini tahrirlash.
     */
    public function update(Request $request, $id)
    {
        $user = User::find($id);
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Foydalanuvchi topilmadi.',
            ], 404);
        }

        $actor = $request->user();

        if ($actor->cannot('update', $user)) {
            return response()->json([
                'success' => false,
                'message' => 'Bu foydalanuvchini tahrirlash uchun ruxsat yo\'q.',
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'full_name' => 'sometimes|string|max:255',
            'email' => 'sometimes|email|unique:users,email,' . $user->id,
            'phone' => 'nullable|string|max:30',
            'faculty' => 'nullable|string',
            'course' => 'nullable|integer',
            'group_name' => 'nullable|string',
            'hostel' => 'nullable|string|in:boys,girls',
            'role' => 'nullable|string|in:talaba,mudir,moliyachi,admin,superAdmin',
            'passport_id' => 'nullable|string|unique:users,passport_id,' . $user->id,
            'jshshir' => 'nullable|string|unique:users,jshshir,' . $user->id,
            'region' => 'nullable|string',
            'district' => 'nullable|string',
            'is_active' => 'nullable|boolean',
            'password' => 'nullable|string|min:8',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        // Faqat ruxsat etilgan maydonlar olinadi. Bu yerda 'role',
        // 'is_active' va 'password' YO'Q — ular quyida alohida
        // tekshiruvdan o'tadi.
        $data = $request->only(self::TAHRIRLASH_MUMKIN);

        // Rolni o'zgartirish — faqat superAdmin.
        if ($request->filled('role') && $request->role !== $user->role) {
            if ($actor->cannot('changeRole', User::class)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Rolni faqat superAdmin o\'zgartira oladi.',
                ], 403);
            }
            $data['role'] = $request->role;
        }

        // Hisobni bloklash yoki ochish.
        if ($request->has('is_active')) {
            if ($actor->id === $user->id) {
                return response()->json([
                    'success' => false,
                    'message' => 'O\'z hisobingiz holatini o\'zgartira olmaysiz.',
                ], 403);
            }
            if (!in_array($actor->role, ['mudir', 'admin', 'superAdmin'], true)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Hisob holatini o\'zgartirish uchun ruxsat yo\'q.',
                ], 403);
            }
            $data['is_active'] = $request->boolean('is_active');
        }

        // Parolni bu yo'l bilan o'zgartirish mumkin emas.
        // O'z paroli uchun: POST /api/change-password (joriy parol so'raladi)
        // Boshqa foydalanuvchi uchun: PUT /api/students/{id}/password
        if ($request->filled('password')) {
            return response()->json([
                'success' => false,
                'message' => 'Parolni bu yerda o\'zgartirib bo\'lmaydi. '
                    . '/api/change-password yoki /api/students/{id}/password dan foydalaning.',
            ], 422);
        }

        // Mudir talabani boshqa binoga ko'chira olmaydi.
        if (
            isset($data['hostel'])
            && $actor->role === 'mudir'
            && !empty($actor->hostel)
            && $data['hostel'] !== $actor->hostel
        ) {
            unset($data['hostel']);
        }

        $user->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Ma\'lumotlar muvaffaqiyatli yangilandi.',
            'data' => new UserResource($user->fresh()->load('activeRoomAssignment.room')),
        ]);
    }

    /**
     * Foydalanuvchini o'chirish.
     */
    public function destroy(Request $request, $id)
    {
        $user = User::find($id);
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Foydalanuvchi topilmadi.',
            ], 404);
        }

        if ($request->user()->cannot('delete', $user)) {
            return response()->json([
                'success' => false,
                'message' => 'Bu foydalanuvchini o\'chirish uchun ruxsat yo\'q.',
            ], 403);
        }

        $user->tokens()->delete();
        $user->delete();

        return response()->json([
            'success' => true,
            'message' => 'Foydalanuvchi o\'chirildi.'
        ]);
    }

    /**
     * Admin tomonidan foydalanuvchi parolini majburan yangilash.
     */
    public function updatePassword(Request $request, $id)
    {
        $user = User::find($id);
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Foydalanuvchi topilmadi.',
            ], 404);
        }

        if ($request->user()->cannot('resetPassword', $user)) {
            return response()->json([
                'success' => false,
                'message' => 'Bu foydalanuvchining parolini almashtirish uchun ruxsat yo\'q.',
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'new_password'              => 'required|string|min:8|confirmed',
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

        // Parol almashgach eski tokenlar bekor qilinadi.
        $user->tokens()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Parol muvaffaqiyatli yangilandi.',
        ]);
    }
}
