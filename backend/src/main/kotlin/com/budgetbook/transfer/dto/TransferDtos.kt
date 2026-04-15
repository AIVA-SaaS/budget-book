package com.budgetbook.transfer.dto

import com.budgetbook.common.dto.PatchValue
import com.budgetbook.common.dto.StringPatchValueDeserializer
import com.budgetbook.common.dto.UUIDPatchValueDeserializer
import com.budgetbook.couple.dto.UserSummary
import com.fasterxml.jackson.databind.annotation.JsonDeserialize
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class CreateTransferRequest(
    @field:NotNull
    val sourcePaymentMethodId: UUID,

    @field:NotNull
    val destinationPaymentMethodId: UUID,

    @field:NotNull
    @field:Min(1)
    @field:Max(999_999_999)
    val amount: Long,

    @field:Size(max = 255)
    val description: String? = null,

    @field:NotNull
    val transferDate: LocalDate,

    val memo: String? = null
)

data class CreateCardSettlementRequest(
    @field:NotNull
    val sourcePaymentMethodId: UUID,

    @field:NotNull
    val destinationPaymentMethodId: UUID,

    @field:NotNull
    @field:Min(1)
    @field:Max(999_999_999)
    val amount: Long,

    @field:NotNull
    val transferDate: LocalDate,

    @field:Size(max = 255)
    val description: String? = null,

    /**
     * 결제 처리할 거래 ID 목록. 빈 리스트면 이체만 생성 (기존 거래에 연결 안 함).
     */
    val transactionIds: List<UUID> = emptyList()
)

data class UpdateTransferRequest(
    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val sourcePaymentMethodId: PatchValue<UUID>? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val destinationPaymentMethodId: PatchValue<UUID>? = null,

    @field:Min(1)
    @field:Max(999_999_999)
    val amount: Long? = null,

    @JsonDeserialize(using = StringPatchValueDeserializer::class)
    val description: PatchValue<String>? = null,

    val transferDate: LocalDate? = null,

    @JsonDeserialize(using = StringPatchValueDeserializer::class)
    val memo: PatchValue<String>? = null
)

data class PaymentMethodSummary(
    val id: UUID,
    val name: String,
    val type: String
)

data class TransferResponse(
    val id: UUID,
    val coupleId: UUID,
    val author: UserSummary,
    val sourcePaymentMethod: PaymentMethodSummary,
    val destinationPaymentMethod: PaymentMethodSummary,
    val amount: Long,
    val description: String?,
    val memo: String?,
    val transferDate: LocalDate,
    val createdAt: Instant
)
