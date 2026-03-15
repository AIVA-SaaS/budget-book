package com.budgetbook.budget.dto

import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.transaction.dto.CategorySummary
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Pattern
import java.time.Instant
import java.util.UUID

data class BudgetRequest(
    val categoryId: UUID? = null,

    @field:NotBlank
    @field:Pattern(regexp = "^\\d{4}-(?:0[1-9]|1[0-2])$", message = "yearMonth must be in YYYY-MM format")
    val yearMonth: String,

    @field:NotNull
    @field:Min(0)
    @field:Max(999_999_999)
    val amount: Long,

    val budgetPeriod: String? = "MONTHLY"
)

data class BudgetUpdateRequest(
    @field:NotNull
    @field:Min(0)
    @field:Max(999_999_999)
    val amount: Long,

    val budgetPeriod: String? = null,

    val weeklyAmount: Long? = null
)

data class BudgetResponse(
    val id: UUID,
    val coupleId: UUID,
    val category: CategorySummary?,
    val yearMonth: String,
    val amount: Long,
    val budgetPeriod: String,
    val weeklyAmount: Long?,
    val createdAt: Instant,
    val updatedAt: Instant
)

data class BudgetSummaryResponse(
    val yearMonth: String,
    val totalBudget: Long,
    val totalSpent: Long,
    val items: List<BudgetSummaryItemResponse>
)

data class CopyBudgetRequest(
    @field:NotNull
    @field:Min(2000)
    @field:Max(2100)
    val sourceYear: Int,

    @field:NotNull
    @field:Min(1)
    @field:Max(12)
    val sourceMonth: Int,

    @field:NotNull
    @field:Min(2000)
    @field:Max(2100)
    val targetYear: Int,

    @field:NotNull
    @field:Min(1)
    @field:Max(12)
    val targetMonth: Int
)

data class BudgetSummaryItemResponse(
    val category: CategorySummary?,
    val budgetAmount: Long,
    val spentAmount: Long,
    val remainingAmount: Long,
    val usageRate: Double
)

data class BudgetAlertResponse(
    val categoryId: String,
    val categoryName: String,
    val budgetAmount: Long,
    val spentAmount: Long,
    val percentage: Int,
    val alertLevel: String  // "SAFE", "WARNING" (>=80%), "EXCEEDED" (>=100%)
)

fun MonthlyBudget.toResponse() = BudgetResponse(
    id = id,
    coupleId = couple.id,
    category = category?.let {
        CategorySummary(
            id = it.id,
            name = it.name,
            type = it.type.name,
            icon = it.icon,
            color = it.color
        )
    },
    yearMonth = yearMonth,
    amount = amount,
    budgetPeriod = budgetPeriod.name,
    weeklyAmount = weeklyAmount,
    createdAt = createdAt,
    updatedAt = updatedAt
)
