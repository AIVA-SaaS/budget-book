package com.budgetbook.budget.dto

import java.util.UUID

data class WeeklyOverviewResponse(
    val yearMonth: String,
    val weeks: List<WeeklySnapshotResponse>
)

data class WeeklySnapshotResponse(
    val weekNumber: Int,
    val weekStart: String,
    val weekEnd: String,
    val budgetAmount: Long,
    val spentAmount: Long,
    val remainingAmount: Long,
    val usageRate: Double,
    val status: String
)

data class CurrentWeekSummaryResponse(
    val yearMonth: String,
    val weekNumber: Int,
    val weekStart: String,
    val weekEnd: String,
    val groups: List<WeeklyGroupSummary>
)

data class WeeklyGroupSummary(
    val groupId: UUID,
    val groupName: String,
    val budgetAmount: Long,
    val spentAmount: Long,
    val remainingAmount: Long,
    val usageRate: Double
)
