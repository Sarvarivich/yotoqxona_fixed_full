<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Announcement;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class NotificationController extends Controller
{
    /**
     * Foydalanuvchining barcha bildirishnomalari.
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $notifications = Notification::where('user_id', $user->id)
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $notifications,
        ]);
    }

    /**
     * Bitta bildirishnomani o'qilgan deb belgilash.
     */
    public function markAsRead(Request $request, $id)
    {
        $user = $request->user();

        $notification = Notification::where('user_id', $user->id)
            ->find($id);

        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => "Bildirishnoma topilmadi.",
            ], 404);
        }

        $notification->update([
            'is_read' => true,
        ]);

        return response()->json([
            'success' => true,
            'message' => "O'qildi deb belgilandi.",
            'data' => $notification->fresh(),
        ]);
    }

    /**
     * Barcha bildirishnomalarni o'qilgan deb belgilash.
     */
    public function markAllAsRead(Request $request)
    {
        $user = $request->user();

        Notification::where('user_id', $user->id)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
            ]);

        return response()->json([
            'success' => true,
            'message' => "Barcha bildirishnomalar o'qilgan deb belgilandi.",
        ]);
    }

    /**
     * Yangi bildirishnoma yuborish.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
            'title' => 'required|string|max:255',
            'message' => 'required|string',
            'type' => 'nullable|string|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $notification = Notification::create([
            'user_id' => $request->input('user_id'),
            'title' => $request->input('title'),
            'message' => $request->input('message'),
            'type' => $request->input('type', 'info'),
            'is_read' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => "Bildirishnoma muvaffaqiyatli yuborildi.",
            'data' => $notification,
        ], 201);
    }

    /**
     * Bildirishnomani o'chirish.
     * Faqat bildirishnoma egasi o'chira oladi.
     */
    public function destroy(Request $request, $id)
    {
        $user = $request->user();

        $notification = Notification::where('user_id', $user->id)
            ->find($id);

        if (!$notification) {
            return response()->json([
                'success' => false,
                'message' => "Bildirishnoma topilmadi.",
            ], 404);
        }

        $notification->delete();

        return response()->json([
            'success' => true,
            'message' => "Bildirishnoma o'chirildi.",
        ]);
    }

    /**
     * E'lonlar ro'yxati.
     */
    public function announcements(Request $request)
    {
        $user = $request->user();

        $query = Announcement::with('creator');

        if ($user && $user->role === 'talaba' && !empty($user->hostel)) {
            $query->where(function ($q) use ($user) {
                $q->whereNull('target_hostel')
                    ->orWhere('target_hostel', 'all')
                    ->orWhere('target_hostel', $user->hostel);
            });
        }

        $announcements = $query
            ->orderByDesc('created_at')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $announcements,
        ]);
    }

    /**
     * Yangi e'lon yaratish.
     */
    public function storeAnnouncement(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'message' => 'required|string',
            'target_hostel' => 'nullable|string|in:boys,girls,all',
            'target_role' => 'nullable|string|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = $request->user();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => "Foydalanuvchi aniqlanmadi.",
            ], 401);
        }

        $announcement = Announcement::create([
            'title' => $request->input('title'),
            'message' => $request->input('message'),
            'target_hostel' => $request->input('target_hostel', 'all'),
            'target_role' => $request->input('target_role', 'all'),
            'created_by' => $user->id,
        ]);

        $studentsQuery = User::query();

        /*
         * Agar tizimdagi talabalar role = talaba bo'lsa,
         * shu foydalanuvchilar tanlanadi.
         */
        $studentsQuery->where('role', 'talaba');

        /*
         * Hostel bo'yicha filtrlash.
         */
        if (
            $request->filled('target_hostel') &&
            $request->input('target_hostel') !== 'all'
        ) {
            $studentsQuery->where(
                'hostel',
                $request->input('target_hostel')
            );
        }

        /*
         * Role bo'yicha qo'shimcha filtrlash.
         */
        if (
            $request->filled('target_role') &&
            $request->input('target_role') !== 'all'
        ) {
            $studentsQuery->where(
                'role',
                $request->input('target_role')
            );
        }

        $users = $studentsQuery->get();

        foreach ($users as $targetUser) {
            Notification::create([
                'user_id' => $targetUser->id,
                'title' => $announcement->title,
                'message' => $announcement->message,
                'type' => 'announcement',
                'is_read' => false,
            ]);
        }

        $announcement->load('creator');

        return response()->json([
            'success' => true,
            'message' => "E'lon muvaffaqiyatli yaratildi va bildirishnomalar yuborildi.",
            'data' => $announcement,
        ], 201);
    }
}