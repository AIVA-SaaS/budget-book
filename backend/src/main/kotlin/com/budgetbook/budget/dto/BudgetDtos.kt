package com.budgetbook.budget.dto

import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.transaction.dto.CategorySummary
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Pattern
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class BudgetRequest(
    val categoryId: UUID? = null,
    val groupId: UUID? = null,

    @field:NotBlank
    @field:Pattern(regexp = "^\\d{4}-(?:0[1-9]|1[0-2])$", message = "yearMonth must be in YYYY-MM format")
    val yearMonth: String,

    /**
     * Phase 25 후속 C-2 — 예산 종료월 (null=무기한, TEMPLATE).
     * 미지정 시 단일월 OVERRIDE 로 동작 (기존 동작과 호환).
     * yearMonth == endYearMonth 또는 endYearMonth=null 이면 OVERRIDE/TEMPLATE 자동 결정.
     */
    @field:Pattern(regexp = "^\\d{4}-(?:0[1-9]|1[0-2])$", message = "endYearMonth must be in YYYY-MM format")
    val endYearMonth: String? = null,

    @field:NotNull
    @field:Min(0)
    @field:Max(999_999_999)
    val amount: Long,

    val budgetPeriod: String? = "MONTHLY",

    val weeklyAmount: Long? = null,

    val periodType: String? = null,  // NONE, DAILY, WEEKLY, MONTHLY
    val startDate: LocalDate? = null,
    val endDate: LocalDate? = null,

    val pocketId: UUID? = null,

    val visibility: String? = "SHARED"
)

data class BudgetUpdateRequest(
    @field:NotNull
    @field:Min(0)
    @field:Max(999_999_999)
    val amount: Long,

    val categoryId: UUID? = null,
    val groupId: UUID? = null,

    val budgetPeriod: String? = null,

    val weeklyAmount: Long? = null,

    val periodType: String? = null,
    val startDate: LocalDate? = null,
    val endDate: LocalDate? = null,

    val pocketId: UUID? = null,

    val visibility: String? = null,

    /**
     * Phase 25 후속 C-2.7 — 사용자가 편집 화면을 열 때 보고 있던 월 ("YYYY-MM").
     * - TEMPLATE 행 편집 시 split semantic 의 기준 월로 사용.
     * - null 이면 split 비활성 (기존 단순 update).
     */
    val yearMonth: String? = null,

    /**
     * Phase 25 후속 C-2 — 사용자가 "이후 모든 일정에 반영" 체크 시 true.
     * - false (default): 단일월 OVERRIDE 만 추가/갱신 (기존 동작)
     * - true: 기존 TEMPLATE 의 endYearMonth = (대상월-1) 로 종료 + 새 TEMPLATE
     *   (대상월부터 무기한). 그 사이 OVERRIDE 들은 영향 없음.
     */
    val applyToFuture: Boolean = false
)

data class BudgetResponse(
    val id: UUID,
    val coupleId: UUID,
    val category: CategorySummary?,
    val groupId: UUID? = null,
    val groupName: String? = null,
    val yearMonth: String,
    /** Phase 25 후속 C-2 — TEMPLATE 종료월 (null=무기한, OVERRIDE 시 yearMonth 와 동일). */
    val endYearMonth: String? = null,
    /** Phase 25 후속 C-2 — TEMPLATE | OVERRIDE. */
    val rowKind: String = "OVERRIDE",
    val amount: Long,
    val budgetPeriod: String,
    val weeklyAmount: Long?,
    val periodType: String,
    val startDate: String?,  // ISO date format (YYYY-MM-DD)
    val endDate: String?,    // ISO date format (YYYY-MM-DD)
    val pocketId: UUID? = null,
    val pocketName: String? = null,
    val visibility: String = "SHARED",
    val ownerId: UUID? = null,
    val createdAt: Instant,
    val updatedAt: Instant
)

data class BudgetSummaryResponse(
    val yearMonth: String,
    val totalBudget: Long,
    val totalSpent: Long,
    val totalPlanned: Long = 0,
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
    val groupId: UUID? = null,
    val groupName: String? = null,
    val budgetAmount: Long,
    val spentAmount: Long,
    val plannedAmount: Long = 0,
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
            color = it.color,
            groupId = it.group?.id,
            groupName = it.group?.name
        )
    },
    groupId = group?.id,
    groupName = group?.name,
    yearMonth = yearMonth,
    endYearMonth = endYearMonth,
    rowKind = rowKind.name,
    amount = amount,
    budgetPeriod = budgetPeriod.name,
    weeklyAmount = weeklyAmount,
    periodType = periodType.name,
    startDate = startDate?.toString(),
    endDate = endDate?.toString(),
    pocketId = pocket?.id,
    pocketName = pocket?.name,
    visibility = visibility.name,
    ownerId = owner?.id,
    createdAt = createdAt,
    updatedAt = updatedAt
)
