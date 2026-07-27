package com.budgetbook.reconciliation.dto

import com.budgetbook.couple.dto.UserSummary
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

/** 스냅샷 헤더. 소계는 조회자 게이팅 후 재계산된 값이다 (표시 행과 합계 일치 보장). */
data class ReconciliationResponse(
    val id: UUID,
    val yearMonth: String,
    val seq: Int,
    val label: String?,
    val itemCount: Int,
    val totalIncome: Long,
    val totalExpense: Long,
    val totalTransfer: Long,
    val reconciledAt: Instant,
    val reconciledBy: UserSummary,
    /** 정산 후 원본 금액/날짜가 바뀐 항목이 하나라도 있으면 true (⚠ 표시용). */
    val hasChangedItems: Boolean = false,
    /** 원본이 삭제된 항목이 하나라도 있으면 true. */
    val hasDeletedItems: Boolean = false
)

data class ReconciliationDetailResponse(
    val id: UUID,
    val yearMonth: String,
    val seq: Int,
    val label: String?,
    val itemCount: Int,
    val totalIncome: Long,
    val totalExpense: Long,
    val totalTransfer: Long,
    val reconciledAt: Instant,
    val reconciledBy: UserSummary,
    val hasChangedItems: Boolean,
    val hasDeletedItems: Boolean,
    val items: List<ReconciliationItemResponse>
)

data class ReconciliationItemResponse(
    /** 스냅샷 항목 id. 제외(remove) 요청에 사용. */
    val itemId: UUID,
    val itemKind: String,
    /** 원본 거래/이체 id. 원본이 삭제되면 null. */
    val refId: UUID?,
    val snapshotAmount: Long,
    val snapshotDate: LocalDate,
    val snapshotDescription: String?,
    val snapshotKind: String,
    /** 현재 원본 금액. 삭제됐으면 null. */
    val currentAmount: Long?,
    val currentDate: LocalDate?,
    /** 금액 또는 날짜가 스냅샷과 다르면 true. */
    val changedAfterReconcile: Boolean,
    val originDeleted: Boolean
)

data class CreateReconciliationRequest(
    @field:Pattern(regexp = "^\\d{4}-(0[1-9]|1[0-2])$", message = "yearMonth must be in yyyy-MM format")
    val yearMonth: String,

    @field:Size(max = 100)
    val label: String? = null,

    val transactionIds: List<UUID> = emptyList(),
    val transferIds: List<UUID> = emptyList()
)

data class UpdateReconciliationRequest(
    @field:Size(max = 100)
    val label: String? = null,
    val addTransactionIds: List<UUID> = emptyList(),
    val addTransferIds: List<UUID> = emptyList(),
    /** 제외할 **스냅샷 항목 id** (`items[].itemId`). 제외된 항목은 미기록으로 복귀. */
    val removeItemIds: List<UUID> = emptyList()
)

/** 월말 누락 점검용 요약. "미기록 N건" 배지가 사용. */
data class ReconciliationSummaryResponse(
    val yearMonth: String,
    val snapshotCount: Int,
    val recordedCount: Int,
    val unrecordedCount: Int,
    val unrecordedIncome: Long,
    val unrecordedExpense: Long,
    val unrecordedTransfer: Long,
    /** 미기록 항목 중 needs_review=true 인 거래 수 (정산 확정 시 경고용). */
    val needsReviewCount: Int
)

/**
 * 거래/이체 응답에 실어 보내는 정산 상태.
 *
 * `TransactionResponse` 와 `TransferResponse` **양쪽** 에 같은 필드를 붙인다. 장부 목록은 두
 * 스트림을 FE 에서 병합하므로 한쪽만 채우면 이체 배지가 영구 미표시되는 drift 가 난다.
 */
data class ReconciliationRef(
    val reconciliationId: UUID,
    val reconciliationSeq: Int,
    val reconciledAt: Instant
)
