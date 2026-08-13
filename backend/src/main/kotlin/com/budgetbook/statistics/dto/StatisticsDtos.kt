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
    val transactionCount: Int,
    /**
     * 2026-08-12 신규 — 이 합계에 **집계된 이체 건수** (`CARD_SETTLEMENT` 제외).
     *
     * 합계와 목록이 같은 집합을 세는지 대조하기 위한 관측 값이다.
     * 합계는 서버가 전 범위를 세고 목록은 페이지 단위로 오므로, 클라이언트는 로드가
     * 끝난 뒤에만 이 값과 행 수를 비교해야 한다.
     */
    val transferCount: Int = 0
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
