package com.budgetbook.statistics.dto

import com.budgetbook.transaction.dto.CategorySummary

data class StatisticsSummaryResponse(
    val yearMonth: String,
    val totalIncome: Long,
    val totalExpense: Long,
    /**
     * Phase 22 신규 — 순수 내부 이체(TransferKind.GENERIC) 합계.
     * 지출/수입 통계와 분리된 별도 지표.
     */
    val totalTransfer: Long,
    val balance: Long,
    val transactionCount: Int
)

data class CategoryStatisticsResponse(
    val category: CategorySummary,
    val amount: Long,
    val percentage: Double,
    val transactionCount: Int
)

data class MonthlyTrendResponse(
    val yearMonth: String,
    val totalIncome: Long,
    val totalExpense: Long,
    /** Phase 22 신규 — 해당 월의 GENERIC 이체 합계. */
    val totalTransfer: Long,
    val balance: Long
)

data class PaymentMethodStatResponse(
    val paymentMethodId: String,
    val paymentMethodName: String,
    val paymentMethodType: String? = null,
    val totalAmount: Long,
    val transactionCount: Int,
    val percentage: Double,
    val transferOut: Long? = null,
    val transferIn: Long? = null
)

// --- Period Summary DTOs ---

data class PeriodSummaryResponse(
    val dateFrom: String,
    val dateTo: String,
    val totalIncome: Long,
    val totalExpense: Long,
    /**
     * Phase 22 신규 — 순수 내부 이체(TransferKind.GENERIC) 합계.
     * 필터 활성 시 0 (이체는 카테고리/결제수단/포켓 필터와 무관).
     */
    val totalTransfer: Long,
    val balance: Long,
    val byCategory: List<CategorySpending>,
    val byBudget: List<BudgetSpending>,
    val byPaymentMethod: List<PaymentMethodSpending>,
    val byDate: List<DailySpending>
)

data class CategorySpending(
    val categoryId: java.util.UUID?,
    val categoryName: String,
    val groupId: java.util.UUID?,
    val groupName: String?,
    val icon: String?,
    val color: String?,
    val amount: Long,
    val count: Int,
    val percentage: Double
)

data class BudgetSpending(
    val budgetId: java.util.UUID,
    val budgetName: String,
    val budgetAmount: Long,
    val spent: Long,
    val planned: Long,
    val remaining: Long,
    val usageRate: Double
)

data class PaymentMethodSpending(
    val methodId: java.util.UUID,
    val methodName: String,
    val methodType: String,
    val amount: Long,
    val count: Int
)

data class DailySpending(
    val date: String,
    val income: Long,
    val expense: Long
)
