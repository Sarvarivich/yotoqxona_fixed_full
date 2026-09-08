<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Application;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

/**
 * Yotoqxona arizalari.
 *
 * Ariza bosqichlari (docs/yotoqxona_ariza_workflow.md ga mos):
 *   step 1 — ariza to'ldirilmoqda
 *   step 2 — submitted        (ko'rib chiqilmoqda)
 *   step 3 — assigned         (yotoqxona/xona ajratildi)
 *   step 4 — payment_pending  (chek moliyaga yuborildi)
 *   step 5 — completed        (moliyachi tasdiqladi)
 *
 * DIQQAT: bu fayl ilgari xato bilan NotificationController klassini
 * saqlab turgan edi, shuning uchun /api/applications endpointlari
 * ishlamay qolgan. Endi klass nomi fayl nomiga mos keladi.
 */
class ApplicationController extends Controller
{
    /** Arizalarni ko'rib chiqadigan rollar. */
    private const REVIEWERS = ['mudir', 'admin', 'superAdmin'];

    private function isReviewer(Request $request): bool
    {
        return in_array($request->user()->role, self::REVIEWERS, true);
    }

    /**
     * Arizalar ro'yxati.
     * Talaba faqat o'z arizalarini ko'radi.
     * Mudir faqat o'z binosidagi arizalarni ko'radi.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $query = Application::with(['user', 'hostel', 'room', 'reviewer']);

        if (!$this->isReviewer($request)) {
            $query->where('user_id', $user->id);
        } elseif ($user->role === 'mudir' && !empty($user->hostel)) {
            // Mudir o'z binosiga tegishli talabalarning arizalarini ko'radi.
            $query->whereHas('user', function ($q) use ($user) {
                $q->where('hostel', $user->hostel);
            });
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('step')) {
            $query->where('step', $request->integer('step'));
        }

        // Ijtimoiy imtiyozga ega arizalarni filtrlash (mudir ekranidagi filtr).
        if ($request->filled('has_social_benefit')) {
            $query->where(
                'has_social_benefit',
                $request->boolean('has_social_benefit')
            );
        }

        $perPage = min($request->integer('per_page', 25), 100);

        return response()->json([
            'success' => true,
            'data' => $query->orderByDesc('created_at')->paginate($perPage),
        ]);
    }

    /**
     * Yangi ariza yaratish (talaba o'zi uchun).
     */
    public function store(Request $request)
    {
        $user = $request->user();

        $validator = Validator::make($request->all(), [
            'has_social_benefit' => 'nullable|boolean',
            'benefit_type' => 'nullable|string|max:100',
            'note' => 'nullable|string|max:2000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Ariza ma\'lumotlari to\'g\'ri kiritilmadi.',
                'errors' => $validator->errors(),
            ], 422);
        }

        // Bir talabada bir vaqtda faqat bitta ochiq ariza bo'lishi mumkin.
        $existing = Application::where('user_id', $user->id)
            ->whereNotIn('status', ['completed', 'rejected'])
            ->first();

        if ($existing) {
            return response()->json([
                'success' => false,
                'message' => 'Sizda allaqachon ko\'rib chiqilayotgan ariza mavjud.',
                'data' => $existing,
            ], 409);
        }

        $application = Application::create([
            'user_id' => $user->id,
            'status' => 'submitted',
            'step' => 2,
            'has_social_benefit' => $request->boolean('has_social_benefit'),
            'benefit_type' => $request->benefit_type,
            'note' => $request->note,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Arizangiz qabul qilindi.',
            'data' => $application->load(['user', 'hostel', 'room']),
        ], 201);
    }

    /**
     * Bitta arizani ko'rish.
     */
    public function show(Request $request, string $id)
    {
        $application = Application::with(['user', 'hostel', 'room', 'reviewer'])
            ->find($id);

        if (!$application) {
            return response()->json([
                'success' => false,
                'message' => 'Ariza topilmadi.',
            ], 404);
        }

        if (
            !$this->isReviewer($request)
            && $application->user_id !== $request->user()->id
        ) {
            return response()->json([
                'success' => false,
                'message' => 'Bu arizani ko\'rish uchun ruxsat yo\'q.',
            ], 403);
        }

        return response()->json([
            'success' => true,
            'data' => $application,
        ]);
    }

    /**
     * Arizani ko'rib chiqish — status/bosqich o'zgartirish (mudir).
     */
    public function update(Request $request, string $id)
    {
        $application = Application::find($id);

        if (!$application) {
            return response()->json([
                'success' => false,
                'message' => 'Ariza topilmadi.',
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'status' => 'required|string|in:submitted,reviewing,assigned,payment_pending,approved,rejected,completed',
            'step' => 'nullable|integer|min:1|max:5',
            'hostel_id' => 'nullable|uuid|exists:hostels,id',
            'room_id' => 'nullable|uuid|exists:rooms,id',
            'assignment_type' => 'nullable|string|in:university,avto_yol,med_college,navoi_object',
            'assignment_message' => 'nullable|string|max:2000',
            'note' => 'nullable|string|max:2000',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Ma\'lumotlar xato kiritildi.',
                'errors' => $validator->errors(),
            ], 422);
        }

        // Status bo'yicha bosqichni avtomatik hisoblaymiz, agar
        // frontend uni alohida yubormagan bo'lsa.
        $stepByStatus = [
            'submitted' => 2,
            'reviewing' => 2,
            'assigned' => 3,
            'payment_pending' => 4,
            'approved' => 4,
            'completed' => 5,
        ];

        $data = $request->only([
            'status',
            'hostel_id',
            'room_id',
            'assignment_type',
            'assignment_message',
            'note',
        ]);

        $data['step'] = $request->filled('step')
            ? $request->integer('step')
            : ($stepByStatus[$request->status] ?? $application->step);

        $data['reviewed_by'] = $request->user()->id;
        $data['reviewed_at'] = now();

        if ($request->status === 'assigned') {
            $data['assigned_at'] = now();
        }

        $application->update($data);

        return response()->json([
            'success' => true,
            'message' => 'Ariza holati yangilandi.',
            'data' => $application->fresh()->load(['user', 'hostel', 'room', 'reviewer']),
        ]);
    }

    /**
     * Arizani o'chirish.
     */
    public function destroy(Request $request, string $id)
    {
        $application = Application::find($id);

        if (!$application) {
            return response()->json([
                'success' => false,
                'message' => 'Ariza topilmadi.',
            ], 404);
        }

        $application->delete();

        return response()->json([
            'success' => true,
            'message' => 'Ariza o\'chirildi.',
        ]);
    }
}
