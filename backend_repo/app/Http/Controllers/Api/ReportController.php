<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Expense;
use App\Models\FinanceBudget;
use App\Models\Payment;
use App\Models\Room;
use App\Models\User;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function summary(Request $request)
    {
        $hostelId = $request->query('hostel_id');

        $rooms = Room::query();
        $students = User::query()->where('role', 'student');
        $payments = Payment::query();

        if ($hostelId) {
            $rooms->where('hostel_id', $hostelId);
            $students->where('hostel', $hostelId);
            $payments->where('hostel_id', $hostelId);
        }

        $roomCount = (clone $rooms)->count();
        $capacity = (clone $rooms)->sum('capacity');
        $occupied = (clone $rooms)->sum('current_occupants');

        $totalPayments = (clone $payments)->where('status', 'approved')->sum('amount');
        if ((float) $totalPayments === 0.0) {
            $totalPayments = (clone $payments)->sum('amount');
        }

        $totalExpenses = Expense::query()->sum('amount');
        $totalBudget = FinanceBudget::query()->sum('amount');

        return response()->json([
            'success' => true,
            'data' => [
                'students' => (clone $students)->count(),
                'rooms' => $roomCount,
                'capacity' => (int) $capacity,
                'occupied' => (int) $occupied,
                'available' => max(0, (int) $capacity - (int) $occupied),
                'occupancy_percent' => $capacity > 0
                    ? round(($occupied / $capacity) * 100, 2)
                    : 0,
                'payments_total' => (float) $totalPayments,
                'expenses_total' => (float) $totalExpenses,
                'budget_total' => (float) $totalBudget,
                'balance' => (float) $totalPayments - (float) $totalExpenses,
            ],
        ]);
    }
}
