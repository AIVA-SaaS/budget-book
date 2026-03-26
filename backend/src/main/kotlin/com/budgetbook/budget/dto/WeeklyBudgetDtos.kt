package com.budgetbook.budget.dto

import java.util.UUID

data class WeeklyOverviewResponse(
    val yearMonth: String,
    val weeks: List<WeeklyWeekResponse>
)

data class WeeklyWeekResponse(
    val weekNumber: Int,
    val weekStart: String,
    val weekEnd: String,
    val totalBudget: Long,
    val totalSpent: Long,
    val totalRemaining: Long,
    val items: List<WeeklyBudgetItemResponse>
)

data class WeeklyBudgetItemResponse(
    val budgetId: UUID,
    val categoryId: UUID?,
    val categoryName: String?,
    val groupId: UUID?,
    val groupName: String?,
    val budgetAmount: Long,
    val spentAmount: Long,
    val remainingAmount: Long,
    val usageRate: Double
)

data class CurrentWeekSummaryResponse(
    val yearMonth: String,
    val weekNumber: Int,
    val weekStart: String,
    val weekEnd: String,
    val items: List<WeeklyBudgetItemResponse>
)
