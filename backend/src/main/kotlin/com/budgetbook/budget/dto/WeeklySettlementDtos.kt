package com.budgetbook.budget.dto

import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.Pattern
import java.time.Instant
import java.util.UUID

data class SettleWeekRequest(
    val budgetId: UUID,
    @field:Pattern(regexp = "\\d{4}-\\d{2}", message = "yearMonth must be YYYY-MM format")
    val yearMonth: String,
    @field:Min(1) @field:Max(6)
    val weekNumber: Int,
    val categoryIds: List<UUID>? = null
)

data class UnsettleWeekRequest(
    val budgetId: UUID,
    @field:Pattern(regexp = "\\d{4}-\\d{2}", message = "yearMonth must be YYYY-MM format")
    val yearMonth: String,
    @field:Min(1) @field:Max(6)
    val weekNumber: Int,
    val categoryIds: List<UUID>? = null
)

data class WeeklySettlementOverviewResponse(
    val yearMonth: String,
    val weeks: List<WeekSettlementResponse>
)

data class WeekSettlementResponse(
    val weekNumber: Int,
    val weekStart: String,
    val weekEnd: String,
    val items: List<SettlementItemResponse>,
    val allSettled: Boolean
)

data class SettlementItemResponse(
    val settlementId: UUID?,
    val budgetId: UUID,
    val categoryId: UUID?,
    val categoryName: String?,
    val amount: Long,
    val status: String,
    val settledAt: Instant?
)
