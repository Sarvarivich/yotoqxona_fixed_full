<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Room;
use App\Models\RoomStudent;
use App\Models\Application;
use App\Models\Payment;
use App\Models\PaymentCheck;
use App\Models\Complaint;
use App\Models\Expense;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $hostelFilter = $request->input('hostel');

        // Talabalar statistikasi
        $studentsQuery = User::where('role', 'talaba');
        if ($hostelFilter) {
            $studentsQuery->where('hostel', $hostelFilter);
        }

        $totalStudents = (clone $studentsQuery)->count();
        $boysStudents = User::where('role', 'talaba')->where('hostel', 'boys')->count();
        $girlsStudents = User::where('role', 'talaba')->where('hostel', 'girls')->count();

        $course1 = (clone $studentsQuery)->where('course', 1)->count();
        $course2 = (clone $studentsQuery)->where('course', 2)->count();
        $course3 = (clone $studentsQuery)->where('course', 3)->count();
        $course4 = (clone $studentsQuery)->where('course', 4)->count();

        // Xonalar statistikasi
        $roomsQuery = Room::query();
        if ($hostelFilter) {
            $roomsQuery->where('hostel_type', $hostelFilter);
        }

        $totalRooms = (clone $roomsQuery)->count();
        $emptyRooms = (clone $roomsQuery)->where('status', 'empty')->count();
        $partiallyFilledRooms = (clone $roomsQuery)->where('status', 'partially_filled')->count();
        $fullRooms = (clone $roomsQuery)->where('status', 'full')->count();

        $totalCapacity = (clone $roomsQuery)->sum('capacity');
        $occupiedBeds = (clone $roomsQuery)->sum('current_occupants');
        $availableBeds = max(0, $totalCapacity - $occupiedBeds);

        // Arizalar statistikasi
        $appsQuery = Application::query();
        $totalApps = (clone $appsQuery)->count();
        $pendingApps = (clone $appsQuery)->whereIn('status', ['submitted', 'pending', 'reviewing'])->count();
        $approvedApps = (clone $appsQuery)->where('status', 'approved')->count();
        $rejectedApps = (clone $appsQuery)->where('status', 'rejected')->count();

        // To'lovlar statistikasi
        $paymentsQuery = Payment::query();
        $totalPaymentsSum = (clone $paymentsQuery)->where('status', 'approved')->sum('amount');
        $totalPaymentsCount = (clone $paymentsQuery)->count();
        $pendingPaymentsCount = (clone $paymentsQuery)->where('status', 'pending')->count();
        $approvedPaymentsCount = (clone $paymentsQuery)->where('status', 'approved')->count();
        $rejectedPaymentsCount = (clone $paymentsQuery)->where('status', 'rejected')->count();

        // To'lov cheklari (kutilayotgan)
        $pendingChecksCount = PaymentCheck::where('status', 'pending')->count();

        // Murojaatlar statistikasi
        $complaintsQuery = Complaint::query();
        if ($hostelFilter) {
            $complaintsQuery->whereHas('hostel', function ($q) use ($hostelFilter) {
                $q->where('code', $hostelFilter);
            });
        }
        $totalComplaints = (clone $complaintsQuery)->count();
        $openComplaints = (clone $complaintsQuery)->whereIn('status', ['open', 'in_progress'])->count();
        $resolvedComplaints = (clone $complaintsQuery)->where('status', 'resolved')->count();

        // Moliya xarajatlari
        $totalExpenses = Expense::sum('amount');
        $netBalance = $totalPaymentsSum - $totalExpenses;

        $data = [
            'students' => [
                'total' => $totalStudents,
                'boys' => $boysStudents,
                'girls' => $girlsStudents,
                'course_1' => $course1,
                'course_2' => $course2,
                'course_3' => $course3,
                'course_4' => $course4,
            ],
            'rooms' => [
                'total' => $totalRooms,
                'empty' => $emptyRooms,
                'partially_filled' => $partiallyFilledRooms,
                'full' => $fullRooms,
                'total_capacity' => (int)$totalCapacity,
                'occupied_beds' => (int)$occupiedBeds,
                'available_beds' => (int)$availableBeds,
            ],
            'applications' => [
                'total' => $totalApps,
                'pending' => $pendingApps,
                'approved' => $approvedApps,
                'rejected' => $rejectedApps,
            ],
            'payments' => [
                'total_sum' => (float)$totalPaymentsSum,
                'total_count' => $totalPaymentsCount,
                'pending_count' => $pendingPaymentsCount + $pendingChecksCount,
                'approved_count' => $approvedPaymentsCount,
                'rejected_count' => $rejectedPaymentsCount,
            ],
            'complaints' => [
                'total' => $totalComplaints,
                'open' => $openComplaints,
                'resolved' => $resolvedComplaints,
            ],
            'finance' => [
                'income' => (float)$totalPaymentsSum,
                'expense' => (float)$totalExpenses,
                'balance' => (float)$netBalance,
            ]
        ];

        return response()->json([
            'success' => true,
            'data' => $data,
        ]);
    }
}
