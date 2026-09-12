<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Payment;
use App\Models\PaymentCheck;
use App\Models\Room;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;

class PaymentController extends Controller
{
    /**
     * To'lovlar ro'yxati
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $query = Payment::with(['student', 'room.hostel', 'reviewer']);

        // Talaba faqat o'z to'lovlarini ko'radi
        if ($user->role === 'talaba') {
            $query->where('student_id', $user->id);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->status);
        }

        if ($request->filled('period')) {
            $query->where('period', $request->period);
        }

        $payments = $query->orderBy('created_at', 'desc')->get();

        // Receipt URL'larni formatlash
        $formatted = $payments->map(function ($p) {
            $data = $p->toArray();
            if ($p->receipt_path) {
                $data['receipt_url'] = asset('storage/' . $p->receipt_path);
            }
            return $data;
        });

        return response()->json([
            'success' => true,
            'data' => $formatted,
        ]);
    }

    /**
     * Yangi to'lov yuborish (Talaba kvitansiya yuklashi)
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'room_id' => 'required|exists:rooms,id',
            'amount' => 'required|numeric|min:1',
            'method' => 'nullable|string',
            'period' => 'nullable|string',
            'payment_date' => 'nullable|date',
            'note' => 'nullable|string',
            'receipt' => 'required|file|mimes:jpeg,png,jpg,pdf,webp|max:10240', // max 10MB
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'To\'lov ma\'lumotlari xato yoki kvitansiya fayli yuklanmadi.',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();
        $room = Room::findOrFail($request->room_id);

        $receiptPath = $request->file('receipt')->store('receipts', 'public');
        $fileName = $request->file('receipt')->getClientOriginalName();
        $fileType = $request->file('receipt')->getClientMimeType();

        // 1. PaymentCheck yozish (kvitansiya tekshiruvi)
        $paymentCheck = PaymentCheck::create([
            'student_id' => $user->id,
            'amount' => $request->amount,
            'file_name' => $fileName,
            'file_type' => $fileType,
            'storage_path' => $receiptPath,
            'payment_date' => $request->payment_date ? date('Y-m-d H:i:s', strtotime($request->payment_date)) : now(),
            'status' => 'pending',
            'sent_to_finance' => true,
            'uploaded_at' => now(),
        ]);

        // 2. Payment yozish
        $payment = Payment::create([
            'student_id' => $user->id,
            'payment_check_id' => $paymentCheck->id,
            'hostel_id' => $room->hostel_id,
            'room_id' => $room->id,
            'amount' => $request->amount,
            'method' => $request->method ?? 'bank_transfer',
            'period' => $request->period ?? date('F Y'),
            'status' => 'pending',
            'note' => $request->note,
            'receipt_path' => $receiptPath,
            'paid_at' => $request->payment_date ? date('Y-m-d H:i:s', strtotime($request->payment_date)) : now(),
        ]);

        $payment->load(['student', 'room.hostel']);
        $res = $payment->toArray();
        $res['receipt_url'] = asset('storage/' . $receiptPath);

        return response()->json([
            'success' => true,
            'message' => 'To\'lov cheki muvaffaqiyatli yuborildi va ko\'rib chiqilmoqda.',
            'data' => $res,
        ], 201);
    }

    /**
     * Bitta to'lovni ko'rish
     */
    public function show($id)
    {
        $payment = Payment::with(['student', 'room.hostel', 'reviewer', 'paymentCheck'])->find($id);

        if (!$payment) {
            return response()->json(['message' => 'To\'lov topilmadi.'], 404);
        }

        $res = $payment->toArray();
        if ($payment->receipt_path) {
            $res['receipt_url'] = asset('storage/' . $payment->receipt_path);
        }

        return response()->json([
            'success' => true,
            'data' => $res,
        ]);
    }

    /**
     * To'lovni tasdiqlash / rad etish (Moliyachi)
     */
    public function update(Request $request, $id)
    {
        $payment = Payment::find($id);

        if (!$payment) {
            return response()->json(['message' => 'To\'lov topilmadi.'], 404);
        }

        $validator = Validator::make($request->all(), [
            'status' => 'required|string|in:pending,approved,rejected',
            // Moliyachi kiritadigan qoldiq qarz. Ixtiyoriy:
            // kiritilmasa oldingi qiymat saqlanib qoladi.
            'remaining_amount' => 'nullable|numeric|min:0',
            'note' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $reviewer = $request->user();

        $payment->status = $request->status;
        $payment->reviewed_by = $reviewer->id;

        // Qoldiq qarzni faqat moliyachi kiritganda yozamiz.
        // Kiritmasa eski qiymat o'zgarmaydi.
        if ($request->filled('remaining_amount')) {
            $payment->remaining_amount = $request->remaining_amount;
        }
        if ($request->filled('note')) {
            $payment->note = $request->note;
        }
        $payment->save();

        if ($payment->payment_check_id) {
            $check = PaymentCheck::find($payment->payment_check_id);
            if ($check) {
                $check->status = $request->status;
                $check->reviewed_by = $reviewer->id;
                $check->reviewed_at = now();
                if ($request->filled('note')) {
                    $check->review_note = $request->note;
                }
                $check->save();
            }
        }

        $payment->load(['student', 'room.hostel', 'reviewer']);

        return response()->json([
            'success' => true,
            'message' => $request->status === 'approved' ? 'To\'lov tasdiqlandi.' : 'To\'lov bekor qilindi.',
            'data' => $payment,
        ]);
    }

    /**
     * To'lovni o'chirish
     */
    public function destroy($id)
    {
        $payment = Payment::find($id);

        if (!$payment) {
            return response()->json(['message' => 'To\'lov topilmadi.'], 404);
        }

        if ($payment->receipt_path) {
            Storage::disk('public')->delete($payment->receipt_path);
        }

        $payment->delete();

        return response()->json([
            'success' => true,
            'message' => 'To\'lov o\'chirildi.'
        ]);
    }

    /**
     * To'lovlar bo'yicha umumiy hisobot (Summary)
     */
    public function summary()
    {
        $totalApproved = Payment::where('status', 'approved')->sum('amount');
        $totalPending = Payment::where('status', 'pending')->count();
        $totalApprovedCount = Payment::where('status', 'approved')->count();
        $totalRejectedCount = Payment::where('status', 'rejected')->count();

        // Oylik to'lovlar
        $thisMonth = date('Y-m');
        $thisMonthSum = Payment::where('status', 'approved')
            ->where('created_at', 'like', "{$thisMonth}%")
            ->sum('amount');

        return response()->json([
            'success' => true,
            'data' => [
                'total_amount' => (float)$totalApproved,
                'this_month_amount' => (float)$thisMonthSum,
                'pending_count' => $totalPending,
                'approved_count' => $totalApprovedCount,
                'rejected_count' => $totalRejectedCount,
            ]
        ]);
    }
}
