<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Expense;
use App\Models\FinanceBudget;
use App\Models\Payment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class FinanceController extends Controller
{
    /**
     * Xarajatlar ro'yxati
     */
    public function expenses(Request $request)
    {
        $query = Expense::with('creator');

        if ($request->filled('category')) {
            $query->where('category', $request->category);
        }

        $expenses = $query->orderBy('date', 'desc')->get();

        return response()->json([
            'success' => true,
            'data' => $expenses,
        ]);
    }

    /**
     * Yangi xarajat qo'shish
     */
    public function storeExpense(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'amount' => 'required|numeric|min:0',
            'category' => 'required|string|max:100',
            'description' => 'nullable|string',
            'date' => 'nullable|date',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();

        $expense = Expense::create([
            'amount' => $request->amount,
            'category' => $request->category,
            'description' => $request->description,
            'date' => $request->date ?? date('Y-m-d'),
            'created_by' => $user->id,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Xarajat muvaffaqiyatli saqlandi.',
            'data' => $expense,
        ], 201);
    }

    /**
     * Xarajatni o'chirish
     */
    public function destroyExpense($id)
    {
        $expense = Expense::find($id);

        if (!$expense) {
            return response()->json([
                'success' => false,
                'message' => 'Xarajat topilmadi.',
            ], 404);
        }

        $expense->delete();

        return response()->json([
            'success' => true,
            'message' => 'Xarajat o\'chirildi.',
        ]);
    }

    /**
     * Oylik budjetlar ro'yxati
     */
    public function budgets(Request $request)
    {
        $budgets = FinanceBudget::with('creator')
            ->orderBy('year', 'desc')
            ->orderBy('month_key', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $budgets,
        ]);
    }

    /**
     * Oylik budjet belgilash / yangilash
     */
    public function setBudget(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'month_key' => 'required|string',
            'year' => 'required|integer',
            'amount' => 'required|numeric|min:0',
            'description' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors()
            ], 422);
        }

        $user = $request->user();

        $budget = FinanceBudget::updateOrCreate(
            [
                'month_key' => $request->month_key,
                'year' => $request->year,
            ],
            [
                'amount' => $request->amount,
                'description' => $request->description,
                'created_by' => $user->id,
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Oylik budjet saqlandi.',
            'data' => $budget,
        ]);
    }
}
