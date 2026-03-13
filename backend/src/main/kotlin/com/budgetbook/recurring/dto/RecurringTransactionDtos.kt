package com.budgetbook.recurring.dto

import com.budgetbook.recurring.domain.RecurringTransaction
import com.budgetbook.transaction.dto.CategorySummary
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import java.time.Instant
import java.util.UUID

data class RecurringTransactionResponse(
    val id: UUID,
    val coupleId: UUID,
    val authorId: UUID,
    val type: String,
    val amount: Long,
    val description: String,
    val memo: String?,
    val frequency: String,
    val dayOfMonth: Int?,
    val dayOfWeek: Int?,
    val nextRunDate: String,
    val lastRunDate: String?,
    val isActive: Boolean,
    val category: CategorySummary?,
    val paymentMethodId: UUID?,
    val paymentMethodName: String?,
    val createdAt: Instant,
    val updatedAt: Instant
)

data class CreateRecurringTransactionRequest(
    @field:NotBlank
    val type: String,

    @field:NotNull
    @field:Min(1)
    @field:Max(999_999_999)
    val amount: Long,

    @field:NotBlank
    val description: String,

    val memo: String? = null,

    val categoryId: UUID? = null,

    val paymentMethodId: UUID? = null,

    @field:NotBlank
    val frequency: String,

    val dayOfMonth: Int? = null,

    val dayOfWeek: Int? = null
)

data class UpdateRecurringTransactionRequest(
    @field:Min(1)
    @field:Max(999_999_999)
    val amount: Long? = null,
    val description: String? = null,
    val memo: String? = null,
    val categoryId: UUID? = null,
    val paymentMethodId: UUID? = null,
    val dayOfMonth: Int? = null,
    val dayOfWeek: Int? = null,
    val isActive: Boolean? = null
)

fun RecurringTransaction.toResponse() = RecurringTransactionResponse(
    id = id,
    coupleId = couple.id,
    authorId = author.id,
    type = type.name,
    amount = amount,
    description = description,
    memo = memo,
    frequency = frequency.name,
    dayOfMonth = dayOfMonth,
    dayOfWeek = dayOfWeek,
    nextRunDate = nextRunDate.toString(),
    lastRunDate = lastRunDate?.toString(),
    isActive = isActive,
    category = category?.let {
        CategorySummary(
            id = it.id,
            name = it.name,
            type = it.type.name,
            icon = it.icon,
            color = it.color
        )
    },
    paymentMethodId = paymentMethod?.id,
    paymentMethodName = paymentMethod?.name,
    createdAt = createdAt,
    updatedAt = updatedAt
)
