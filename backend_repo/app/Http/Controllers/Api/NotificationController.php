<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Announcement;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class NotificationController extends Controller
{
    /**
     * Foydalanuvchi bildirishnomalari
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $notifications = Notification::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $notifications,
        ]);
    }

    /**
     * O'qilgan deb belgilash
     */
    public function markAsRead(Request $request, $id)
    {
        $user = $request->user();
        $notification = Notification::where('user_id', $user->id)->find($id);

        if (!$notification) {
            return response()->json(['message' => 'Bildirishnoma topilmadi.'], 404);
        }

        $notification->update(['is_read' => true]);

        return response()->json([
            'success' => true,
            'message' => 'O\'qildi deb belgilandi.'
        ]);
    }

    /**
     * Yangi bildirishnoma yuborish (Admin / Mudir)
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'user_id' => 'required|exists:users,id',
            'title' => 'required|string|max:255',
            'message' => 'required|string',
            'type' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        $notification = Notification::create([
            'user_id' => $request->user_id,
            'title' => $request->title,
            'message' => $request->message,
            'type' => $request->type ?? 'info',
            'is_read' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Bildirishnoma yuborildi.',
            'data' => $notification,
        ], 201);
    }

    /**
     * Bildirishnomani o'chirish (faqat egasi)
     */
    public function destroy(Request $request, $id)
    {
        $notification = Notification::where('user_id', $request->user()->id)->find($id);

        if (!$notification) {
            return response()->json(['message' => 'Bildirishnoma topilmadi.'], 404);
        }

        $notification->delete();

        return response()->json([
            'success' => true,
            'message' => 'Bildirishnoma o'chirildi.',
        ]);
    }

    /**
     * E'lonlar ro'yxati
     */
    public function announcements(Request $request)
    {
        $user = $request->user();

        $query = Announcement::with('creator');

        if ($user->role === 'talaba' && $user->hostel) {
            $query->where(function ($q) use ($user) {
                $q->whereNull('target_hostel')
                  ->orWhere('target_hostel', 'all')
                  ->orWhere('target_hostel', $user->hostel);
            });
        }

        $announcements = $query->orderBy('created_at', 'desc')->get();

        return response()->json([
            'success' => true,
            'data' => $announcements,
        ]);
    }

    /**
     * Yangi e'lon yaratish
     */
    public function storeAnnouncement(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'message' => 'required|string',
            'target_hostel' => 'nullable|string|in:boys,girls,all',
            'target_role' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();

        $announcement = Announcement::create([
            'title' => $request->title,
            'message' => $request->message,
            'target_hostel' => $request->target_hostel ?? 'all',
            'target_role' => $request->target_role ?? 'all',
            'created_by' => $user->id,
        ]);

        // Talabalarga bildirishnoma tarqatish
        $studentsQuery = User::where('role', 'talaba');
        if ($request->filled('target_hostel') && $request->target_hostel !== 'all') {
            $studentsQuery->where('hostel', $request->target_hostel);
        }

        $students = $studentsQuery->get();
        foreach ($students as $student) {
            Notification::create([
                'user_id' => $student->id,
                'title' => $request->title,
                'message' => $request->message,
                'type' => 'announcement',
                'is_read' => false,
            ]);
        }

        $announcement->load('creator');

        return response()->json([
            'success' => true,
            'message' => 'E\'lon muvaffaqiyatli chop etildi va bildirishnomalar yuborildi.',
            'data' => $announcement,
        ], 201);
    }
}
