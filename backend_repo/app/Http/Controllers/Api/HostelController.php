<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Hostel;
use Illuminate\Http\Request;

class HostelController extends Controller
{
    public function index()
    {
        $hostels = Hostel::withCount(['rooms'])->where('is_active', true)->get();

        return response()->json([
            'success' => true,
            'data' => $hostels,
        ]);
    }

    public function show($id)
    {
        $hostel = Hostel::with(['rooms.activeStudents'])->find($id);

        if (!$hostel) {
            return response()->json(['message' => 'Yotoqxona binosi topilmadi.'], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $hostel,
        ]);
    }
}
