package com.budgetbook.spendingplan.dto

import com.budgetbook.common.dto.PatchValue
import com.budgetbook.common.dto.StringPatchValueDeserializer
import com.budgetbook.common.dto.UUIDPatchValueDeserializer
import com.budgetbook.spendingplan.domain.SpendingPlan
import com.budgetbook.spendingplan.domain.SpendingPlanFrequency
import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
import com.fasterxml.jackson.databind.annotation.JsonDeserialize
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

// ── Create Request ──

data class CreateSpendingPlanRequest(
    @field:NotBlank
    @field:Size(max = 100)
    val name: String,

    @field:NotNull
    @field:Min(1)
    val amount: Long,

    @field:NotNull
    val targetDate: LocalDate,

    val memo: String? = null,
    val categoryId: UUID? = null,
    val paymentMethodId: UUID? = null,
    val budgetId: UUID? = null,
    val isRecurring: Boolean = false,
    val frequency: SpendingPlanFrequency? = null,
    val visibility: String? = null
)

// ── Update Request (PatchValue semantics) ──

data class UpdateSpendingPlanRequest(
    @field:Size(max = 100)
    val name: String? = null,

    @field:Min(1)
    val amount: Long? = null,

    val targetDate: LocalDate? = null,

    @JsonDeserialize(using = StringPatchValueDeserializer::class)
    val memo: PatchValue<String>? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val categoryId: PatchValue<UUID>? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val paymentMethodId: PatchValue<UUID>? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val budgetId: PatchValue<UUID>? = null,

    val isRecurring: Boolean? = null,

    @JsonDeserialize(using = SpendingPlanFrequencyPatchValueDeserializer::class)
    val frequency: PatchValue<SpendingPlanFrequency>? = null,

    val visibility: String? = null
)

// ── Complete Request ──

data class CompleteSpendingPlanRequest(
    val linkedTransactionId: UUID? = null,
    val actualAmount: Long? = null,
    val completedDate: LocalDate? = null
)

// ── Response ──

data class SpendingPlanResponse(
    val id: UUID,
    val coupleId: UUID,
    val authorId: UUID,
    val authorNickname: String?,
    val name: String,
    val amount: Long,
    val targetDate: LocalDate,
    val memo: String?,
    val category: CategorySummary?,
    val paymentMethod: PaymentMethodSummary?,
    val budgetId: UUID?,
    val linkedTransactionId: UUID?,
    val status: String,
    val actualAmount: Long?,
    val completedDate: LocalDate?,
    val variance: Long?,
    val varianceRate: Double?,
    val isRecurring: Boolean,
    val frequency: SpendingPlanFrequency?,
    val recurringSourceId: UUID?,
    val visibility: String,
    val ownerId: UUID?,
    val createdAt: Instant,
    val updatedAt: Instant
)

data class CategorySummary(
    val id: UUID,
    val name: String,
    val groupName: String?
)

data class PaymentMethodSummary(
    val id: UUID,
    val name: String
)

// ── List Response with Summary ──

data class SpendingPlanListResponse(
    val plans: List<SpendingPlanResponse>,
    val summary: SpendingPlanSummary
)

data class SpendingPlanSummary(
    val totalPlanned: Long,
    val totalCompleted: Long,
    val totalSkipped: Long,
    val plannedCount: Int,
    val completedCount: Int,
    val skippedCount: Int,
    val overdueCount: Int
)

// ── Suggestion Response ──

data class SpendingPlanSuggestion(
    val planId: UUID,
    val name: String,
    val plannedAmount: Long,
    val matchScore: Double,
    val matchReasons: List<String>
)

// ── Mapping ──

fun SpendingPlan.toResponse(): SpendingPlanResponse {
    val variance = if (status.name == "COMPLETED" && actualAmount != null) actualAmount!! - amount else null
    val varianceRate = if (variance != null && amount > 0) (variance.toDouble() / amount) * 100 else null

    return SpendingPlanResponse(
        id = id,
        coupleId = couple.id,
        authorId = author.id,
        authorNickname = author.nickname,
        name = name,
        amount = amount,
        targetDate = targetDate,
        memo = memo,
        category = category?.let {
            CategorySummary(
                id = it.id,
                name = it.name,
                groupName = it.group?.name
            )
        },
        paymentMethod = paymentMethod?.let {
            PaymentMethodSummary(id = it.id, name = it.name)
        },
        budgetId = budget?.id,
        linkedTransactionId = linkedTransaction?.id,
        status = status.name,
        actualAmount = actualAmount,
        completedDate = completedDate,
        variance = variance,
        varianceRate = varianceRate?.let { Math.round(it * 10) / 10.0 },
        isRecurring = isRecurring,
        frequency = frequency,
        recurringSourceId = recurringSource?.id,
        visibility = visibility.name,
        ownerId = owner?.id,
        createdAt = createdAt,
        updatedAt = updatedAt
    )
}

// ── Custom PatchValue deserializer ──

class SpendingPlanFrequencyPatchValueDeserializer : JsonDeserializer<PatchValue<SpendingPlanFrequency>>() {
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext): PatchValue<SpendingPlanFrequency> {
        val text = p.valueAsString
        return PatchValue(if (text != null) SpendingPlanFrequency.valueOf(text) else null)
    }

    override fun getNullValue(ctxt: DeserializationContext): PatchValue<SpendingPlanFrequency> {
        return PatchValue(null)
    }
}
