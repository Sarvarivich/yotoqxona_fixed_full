<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Complaint;
use App\Models\ComplaintAttachment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ComplaintController extends Controller
{
    /**
     * Murojaatlar ro'yxati
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $query = Complaint::with(['student', 'hostel', 'attachments', 'respondedBy']);

        if ($user->role === 'talaba') {
            $query->where('student_id', $user->id);
        }

        // Mudir faqat o'z binosidagi talabalarning murojaatlarini
        // ko'radi. Admin va superAdmin uchun cheklov yo'q.
        if ($user->role === 'mudir' && !empty($user->hostel)) {
            $query->whereHas('student', function ($q) use ($user) {
                $q->where('hostel', $user->hostel);
            });
        }

        // Kimga yo'naltirilgani bo'yicha filtr (mudir / admin / moliyachi).
        if ($request->filled('target_role')) {
            $query->where('target_role', $request->target_role);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }

        $complaints = $query->orderBy('created_at', 'desc')->get();

        return response()->json([
            'success' => true,
            'data' => $complaints,
        ]);
    }

    /**
     * Yangi murojaat qoldirish
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'description' => 'required|string',
            'category' => 'nullable|string',
            'priority' => 'nullable|string|in:low,medium,high,urgent',
            'target_role' => 'nullable|string',
            'is_anonymous' => 'nullable|boolean',
            'attachments.*' => 'nullable|file|max:10240',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();
        $activeRoom = $user->activeRoomAssignment;

        $complaint = Complaint::create([
            'student_id' => $request->boolean('is_anonymous') ? null : $user->id,
            'hostel_id' => $activeRoom ? $activeRoom->room->hostel_id : null,
            'target_role' => $request->target_role ?? 'mudir',
            'title' => $request->title,
            'description' => $request->description,
            'category' => $request->category ?? 'umumiy',
            'priority' => $request->priority ?? 'medium',
            'status' => 'open',
            'is_anonymous' => $request->boolean('is_anonymous'),
        ]);

        if ($request->hasFile('attachments')) {
            foreach ($request->file('attachments') as $file) {
                $path = $file->store('complaints', 'public');
                ComplaintAttachment::create([
                    'complaint_id' => $complaint->id,
                    'storage_path' => $path,
                    'file_name' => $file->getClientOriginalName(),
                    'file_type' => $file->getClientMimeType(),
                ]);
            }
        }

        $complaint->load(['attachments']);

        return response()->json([
            'success' => true,
            'message' => 'Murojaatingiz qabul qilindi.',
            'data' => $complaint,
        ], 201);
    }

    /**
     * Bitta murojaatni ko'rish
     */
    public function show($id)
    {
        $complaint = Complaint::with(['student', 'hostel', 'attachments', 'respondedBy'])->find($id);

        if (!$complaint) {
            return response()->json(['message' => 'Murojaat topilmadi.'], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $complaint,
        ]);
    }

    /**
     * Murojaatga javob berish / statusni yangilash
     */
    public function update(Request $request, $id)
    {
        $complaint = Complaint::find($id);

        if (!$complaint) {
            return response()->json(['message' => 'Murojaat topilmadi.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'status' => 'sometimes|string|in:open,in_progress,resolved,closed',
            'response' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();

        if ($request->filled('response')) {
            $complaint->response = $request->response;
            $complaint->responded_by = $user->id;
            $complaint->responded_by_role = $user->role;
        }

        if ($request->filled('status')) {
            $complaint->status = $request->status;
            if ($request->status === 'resolved') {
                $complaint->resolved_at = now();
            }
        }

        $complaint->save();
        $complaint->load(['student', 'hostel', 'attachments', 'respondedBy']);

        return response()->json([
            'success' => true,
            'message' => 'Murojaat holati yangilandi.',
            'data' => $complaint,
        ]);
    }
}
