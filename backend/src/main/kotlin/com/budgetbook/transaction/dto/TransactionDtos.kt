package com.budgetbook.transaction.dto

import com.budgetbook.common.dto.PatchValue
import com.budgetbook.common.dto.StringPatchValueDeserializer
import com.budgetbook.common.dto.UUIDPatchValueDeserializer
import com.budgetbook.couple.dto.UserSummary
import com.fasterxml.jackson.databind.annotation.JsonDeserialize
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class TransactionResponse(
    val id: UUID,
    val coupleId: UUID,
    val author: UserSummary,
    val category: CategorySummary?,
    val type: String,
    val amount: Long,
    val description: String,
    val memo: String?,
    val transactionDate: LocalDate,
    val paymentMethodId: UUID? = null,
    val paymentMethodName: String? = null,
    val paymentMethodType: String? = null,
    val settlementDate: String? = null,
    val pocketId: UUID? = null,
    val pocketName: String? = null,
    val visibility: String = "SHARED",
    val ownerId: UUID? = null,
    // V61 (2026-05-06) — 확인/입력 필요 플래그
    val needsReview: Boolean = false,
    // V65 (2026-07-27) — 정산 스냅샷 소속. 미기록이면 전부 null.
    // TransferResponse 에도 **같은 3필드**가 있다 (장부 목록이 두 스트림 병합이라 한쪽만
    // 채우면 이체 배지가 영구 미표시되는 drift 가 난다).
    val reconciliationId: UUID? = null,
    val reconciliationSeq: Int? = null,
    val reconciledAt: Instant? = null,
    val createdAt: Instant,
    val updatedAt: Instant
)

data class CategorySummary(
    val id: UUID,
    val name: String,
    val type: String,
    val icon: String?,
    val color: String?,
    val groupId: UUID? = null,
    val groupName: String? = null
)

data class CreateTransactionRequest(
    @field:NotBlank
    val type: String,

    // Phase 22 T11: @Min(0) 제거. ADJUSTMENT 는 잔액 하향 조정 시 음수 필요.
    // 부호 검증은 TransactionService 에서 type 별로 수행한다.
    @field:NotNull
    @field:Min(-999_999_999)
    @field:Max(999_999_999)
    val amount: Long,

    @field:NotBlank
    @field:Size(max = 255)
    val description: String,

    val categoryId: UUID? = null,

    @field:NotNull
    val transactionDate: LocalDate,

    @field:Size(max = 1000)
    val memo: String? = null,

    val paymentMethodId: UUID? = null,

    val pocketId: UUID? = null,

    val visibility: String? = "SHARED",

    // V61 (2026-05-06) — 확인/입력 필요 플래그. 미지정 시 false.
    val needsReview: Boolean = false
)

data class UpdateTransactionRequest(
    /**
     * 거래 유형 변경 (2026-07-27). null = 미변경.
     *
     * `EXPENSE` ↔ `INCOME` 만 가능하다. `ADJUSTMENT` 는 잔액 보정 전용이라 일반 거래와
     * 상호 전환하지 않고, **이체로의 변경은 테이블이 달라** 별도 엔드포인트를 쓴다
     * (`POST /transactions/{id}/convert-to-transfer`).
     */
    val type: String? = null,

    // Phase 22 T11: @Min(0) 제거. ADJUSTMENT 는 잔액 하향 조정 시 음수 필요.
    // 부호 검증은 TransactionService 에서 type 별로 수행한다.
    @field:Min(-999_999_999)
    @field:Max(999_999_999)
    val amount: Long? = null,

    @field:Size(max = 255)
    val description: String? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val categoryId: PatchValue<UUID>? = null,

    val transactionDate: LocalDate? = null,

    @JsonDeserialize(using = StringPatchValueDeserializer::class)
    val memo: PatchValue<String>? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val paymentMethodId: PatchValue<UUID>? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val pocketId: PatchValue<UUID>? = null,

    val visibility: String? = null,

    // V61 (2026-05-06) — null 이면 미변경, true/false 면 토글.
    val needsReview: Boolean? = null
)

data class PageResponse<T>(
    val content: List<T>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int,
    val first: Boolean,
    val last: Boolean
)

data class CsvImportResponse(
    val imported: Int,
    val skipped: Int,
    val errors: List<CsvImportError>
)

data class CsvImportError(
    val row: Int,
    val reason: String
)

data class SuggestionResponse(
    val description: String,
    val patterns: List<SuggestionPattern>
)

data class SuggestionPattern(
    val categoryId: UUID? = null,
    val categoryName: String? = null,
    // 회차 12 follow-up (2026-05-04) — 카테고리 표시 통일.
    // FE 가 "그룹 > 하위" 형식으로 표시할 때 group lookup 부하 없이 사용.
    val categoryGroupName: String? = null,
    val categoryIcon: String? = null,
    val categoryColor: String? = null,
    val paymentMethodId: UUID? = null,
    val paymentMethodName: String? = null,
    val count: Long
)

data class SettlementTransactionsResponse(
    val totalAmount: Long,
    val transactionCount: Int,
    val transactions: List<SettlementTransactionItem>
)

data class SettlementTransactionItem(
    val id: UUID,
    val transactionDate: LocalDate,
    val settlementDate: LocalDate?,
    val description: String,
    val amount: Long,
    val categoryName: String?,
    val categoryIcon: String?,
    val type: String = "TRANSACTION", // TRANSACTION or TRANSFER
    /**
     * V63: ID of the card-settlement transfer this transaction is currently linked to,
     * or null if unpaid/unlinked. Lets the edit screen pre-check transactions that belong
     * to the settlement being edited.
     */
    val settlementTransferId: UUID? = null
)

/**
 * 거래 → 이체 변환 요청 (2026-07-27).
 *
 * 거래와 이체는 테이블이 달라 `PATCH /transactions/{id}` 로는 유형을 바꿀 수 없다.
 * 이 요청은 **원본 거래를 지우고 같은 내용의 이체를 만드는** 한 번의 원자적 작업이다.
 * 금액·날짜·설명·메모를 생략하면 원본 값을 승계한다.
 */
data class ConvertToTransferRequest(
    @field:NotNull
    val sourcePaymentMethodId: UUID,

    @field:NotNull
    val destinationPaymentMethodId: UUID,

    /** 생략 시 결제수단 조합으로 자동 판정 (TransferKindResolver). */
    val kind: String? = null,

    @field:Min(1)
    @field:Max(999_999_999)
    val amount: Long? = null,

    val transferDate: LocalDate? = null,

    @field:Size(max = 255)
    val description: String? = null,

    @field:Size(max = 1000)
    val memo: String? = null
)
