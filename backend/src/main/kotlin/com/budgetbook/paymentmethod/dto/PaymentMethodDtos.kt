package com.budgetbook.paymentmethod.dto

import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class PaymentMethodResponse(
    val id: UUID,
    val name: String,
    val type: String,
    val settlementDay: Int?,
    val closingDay: Int?,
    val isActive: Boolean,
    val isDefault: Boolean,
    val displayOrder: Int,
    val createdAt: Instant
)

data class CreatePaymentMethodRequest(
    @field:NotBlank
    @field:Size(max = 100)
    val name: String,
    @field:NotBlank
    val type: String,
    @field:Min(1)
    @field:Max(31)
    val settlementDay: Int? = null,
    @field:Min(1)
    @field:Max(31)
    val closingDay: Int? = null
)

data class UpdatePaymentMethodRequest(
    @field:Size(max = 100)
    val name: String? = null,
    @field:Min(1)
    @field:Max(31)
    val settlementDay: Int? = null,
    @field:Min(1)
    @field:Max(31)
    val closingDay: Int? = null,
    val isActive: Boolean? = null,
    val displayOrder: Int? = null
)

data class CardPendingResponse(
    val paymentMethod: PaymentMethodResponse,
    val pendingAmount: Long,
    val settlementDate: LocalDate?,
    val transactionCount: Int
)
