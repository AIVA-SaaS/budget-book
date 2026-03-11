package com.budgetbook.report.dto

import com.budgetbook.transaction.dto.CategorySummary
import java.util.UUID

// Weekly Report
data class WeeklyReportResponse(
    val yearMonth: String,
    val weekNumber: Int,
    val weekStart: String,
    val weekEnd: String,
    val totalBudget: Long,
    val totalSpent: Long,
    val remainingAmount: Long,
    val usageRate: Double,
    val status: String,
    val topOverspendCategories: List<CategorySpendingItem>,
    val dailySpending: List<DailySpendingItem>,
    val peakSpendingDay: String?
)

data class CategorySpendingItem(
    val category: CategorySummary?,
    val amount: Long,
    val averageAmount: Long,
    val deviation: Long,
    val transactionCount: Int
)

data class DailySpendingItem(
    val date: String,
    val dayOfWeek: String,
    val amount: Long,
    val transactionCount: Int
)

// Monthly Report
data class MonthlyReportResponse(
    val yearMonth: String,
    val totalIncome: Long,
    val totalExpense: Long,
    val balance: Long,
    val groupSummaries: List<GroupSpendingSummary>,
    val topCategories: List<CategorySpendingItem>,
    val previousMonthComparison: MonthComparisonResponse?,
    val cardPendingSummary: CardPendingReportSummary?,
    val dayOfWeekPattern: List<DayOfWeekPattern>
)

data class GroupSpendingSummary(
    val groupId: UUID?,
    val groupName: String,
    val budgetType: String,
    val totalBudget: Long,
    val totalSpent: Long,
    val usageRate: Double
)

data class MonthComparisonResponse(
    val previousYearMonth: String,
    val incomeChange: Long,
    val expenseChange: Long,
    val incomeChangeRate: Double,
    val expenseChangeRate: Double
)

data class CardPendingReportSummary(
    val totalPendingAmount: Long,
    val cardCount: Int
)

data class DayOfWeekPattern(
    val dayOfWeek: String,
    val averageSpending: Long,
    val totalSpending: Long,
    val transactionCount: Int
)
