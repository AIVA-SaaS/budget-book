package com.budgetbook.transfer.dto

import com.budgetbook.common.dto.PatchValue
import com.budgetbook.common.dto.StringPatchValueDeserializer
import com.budgetbook.common.dto.UUIDPatchValueDeserializer
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.transfer.domain.TransferKind
import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
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

    val memo: String? = null,

    /**
     * 이체 종류. null 이면 src/dst 타입으로 자동 판정 (§2.1 표).
     * - BANK → CREDIT: CARD_SETTLEMENT 기본
     * - 나머지: GENERIC 기본
     * EXPENSE_TRANSFER / INCOME_TRANSFER 는 사용자 명시 필요.
     */
    val kind: TransferKind? = null
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

data class UpdateCardSettlementRequest(
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
     * 결제 처리할 거래 ID 목록. 빈 리스트면 모든 기존 연결을 해제하고 이체만 남긴다.
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
    val memo: PatchValue<String>? = null,

    /**
     * 이체 종류 변경 (Phase 22).
     * - 필드 미포함: 변경 없음 (null)
     * - 필드 포함 + null: 허용되지 않음 (kind 는 nullable 아님)
     * - 필드 포함 + 값: 해당 값으로 변경
     */
    @JsonDeserialize(using = TransferKindPatchValueDeserializer::class)
    val kind: PatchValue<TransferKind>? = null
)

class TransferKindPatchValueDeserializer : JsonDeserializer<PatchValue<TransferKind>>() {
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext): PatchValue<TransferKind> {
        val text = p.valueAsString
        return PatchValue(
            if (text != null) {
                try {
                    TransferKind.valueOf(text)
                } catch (e: IllegalArgumentException) {
                    throw ctxt.weirdStringException(text, TransferKind::class.java, "Invalid TransferKind: $text")
                }
            } else null
        )
    }

    override fun getNullValue(ctxt: DeserializationContext): PatchValue<TransferKind> {
        return PatchValue(null)
    }
}

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
    val kind: TransferKind,
    // V65 (2026-07-27) — 정산 스냅샷 소속. TransactionResponse 와 동일 3필드.
    val reconciliationId: UUID? = null,
    val reconciliationSeq: Int? = null,
    val reconciledAt: Instant? = null,
    val createdAt: Instant
)
