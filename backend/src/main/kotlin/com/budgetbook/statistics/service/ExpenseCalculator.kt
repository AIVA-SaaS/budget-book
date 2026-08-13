package com.budgetbook.statistics.service

import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.domain.Transfer
import com.budgetbook.transfer.domain.TransferKind
import com.budgetbook.transfer.domain.TransferKinds
import com.budgetbook.transfer.repository.TransferRepository
import com.budgetbook.transfer.service.TransferGating
import org.springframework.stereotype.Component
import java.time.LocalDate
import java.util.UUID

/**
 * 이체 집계 결과의 kind 별 버킷.
 *
 * - [income] : `INCOME_TRANSFER` 합 (수입 총액에 더한다)
 * - [expense]: `EXPENSE_TRANSFER` 합 (지출 총액에 더한다)
 * - [generic]: `GENERIC` 합 (합계바의 "이체" 칸 전용, 수입/지출과 disjoint)
 * - [count]  : 집계에 포함된 이체 건수 (`CARD_SETTLEMENT` 제외)
 */
data class TransferBuckets(
    val income: Long,
    val expense: Long,
    val generic: Long,
    val count: Int,
) {
    companion object {
        val EMPTY = TransferBuckets(income = 0L, expense = 0L, generic = 0L, count = 0)
    }
}

/**
 * Phase 22 S1 — 통계 집계의 단일 진입점.
 *
 * **원칙**
 * - Transaction 과 Transfer 를 합산해 수입/지출/이체 총액을 계산하는 모든 경로는 반드시 이 컴포넌트를 사용한다.
 * - 인라인 sum (`totalExpense += transferOutTotal` 등) 은 금지.
 * - `TransactionType.ADJUSTMENT` 는 모든 통계에서 **제외** 된다 (잔액 전용).
 * - `TransferKind.CARD_SETTLEMENT` 은 모든 통계에서 **제외** 된다 (원본 EXPENSE 로 이미 집계됨).
 *
 * **집계식** (plan §2.2)
 * ```
 * totalExpense  = sum(Transaction WHERE type=EXPENSE)
 *               + sum(Transfer.amount WHERE kind=EXPENSE_TRANSFER)
 * totalIncome   = sum(Transaction WHERE type=INCOME)
 *               + sum(Transfer.amount WHERE kind=INCOME_TRANSFER)
 * totalTransfer = sum(Transfer.amount WHERE kind=GENERIC)
 * ```
 */
@Component
class ExpenseCalculator(
    private val transactionRepository: TransactionRepository,
    private val transferRepository: TransferRepository,
) {

    /**
     * 기간 내 총 지출 = EXPENSE Transaction 합 + EXPENSE_TRANSFER Transfer 합.
     *
     * @param userId visibility 필터(기본 'ALL') 적용 시 본인 PRIVATE 을 보려는 요청자 ID
     * @param visibility 'ALL' / 'SHARED' / 'PRIVATE' (이미 검증된 값)
     */
    fun totalExpense(
        coupleId: UUID,
        from: LocalDate,
        to: LocalDate,
        userId: UUID,
        visibility: String = "ALL",
    ): Long {
        val txExpense = sumTransactionByType(coupleId, from, to, TransactionType.EXPENSE, userId, visibility)
        val transferExpense = transferRepository
            .sumAmountBySourceByKind(coupleId, from, to, TransferKinds.EXPENSE_AFFECTING)
            .sumOf { it[1] as Long }
        return txExpense + transferExpense
    }

    /**
     * 기간 내 총 수입 = INCOME Transaction 합 + INCOME_TRANSFER Transfer 합.
     */
    fun totalIncome(
        coupleId: UUID,
        from: LocalDate,
        to: LocalDate,
        userId: UUID,
        visibility: String = "ALL",
    ): Long {
        val txIncome = sumTransactionByType(coupleId, from, to, TransactionType.INCOME, userId, visibility)
        val transferIncome = transferRepository
            .sumAmountByDestinationByKind(coupleId, from, to, TransferKinds.INCOME_AFFECTING)
            .sumOf { it[1] as Long }
        return txIncome + transferIncome
    }

    /**
     * 기간 내 순수 내부 이체 총액. GENERIC kind 만 포함.
     * 지출/수입 통계와 분리된 별도 지표 (MonthSummaryBar 의 "이체" 칸).
     */
    fun totalTransfer(
        coupleId: UUID,
        from: LocalDate,
        to: LocalDate,
    ): Long {
        return transferRepository
            .sumAmountBySourceByKind(coupleId, from, to, TransferKinds.TRANSFER_ONLY)
            .sumOf { it[1] as Long }
    }

    /**
     * 장부 필터를 적용한 이체 집계.
     *
     * ## 왜 여기 있는가 (2026-08-12)
     *
     * 예전에는 통계 서비스가 "필터가 하나라도 켜지면 이체를 전량 제외"(`totalTransfer = 0`)
     * 했다. 그런데 목록에는 이체 행이 남아서 합계와 행이 다른 집합을 셌다.
     * 이제 **이체 목록 조회와 같은 판정**([TransferGating])으로 집계한다 —
     * `TransferService.listTransfers` 와 이 함수가 같은 spec 을 쓰므로 한쪽만 어긋날 수 없다.
     *
     * 주의: `filter.reconciled` 는 여기서 적용하지 않는다(스냅샷 테이블 조회가 필요).
     * 장부 합계바의 필터 VO 에는 정산 축이 없어 현재 도달하지 않는 경로다 —
     * 정산 필터를 합계에 쓰려면 `ReconciliationLookup` 을 함께 주입해야 한다.
     */
    fun transferBuckets(
        coupleId: UUID,
        from: LocalDate,
        to: LocalDate,
        filter: CommonFilterParams,
    ): TransferBuckets {
        if (TransferGating.excludedWholesale(filter)) return TransferBuckets.EMPTY
        val transfers = transferRepository.findAll(TransferGating.spec(coupleId, filter, from, to))
        return bucketsOf(transfers)
    }

    /**
     * kind 별 버킷 분류. 집계식은 클래스 KDoc 과 동일하며 FE `LedgerSummary` 규칙과 일치한다.
     * `CARD_SETTLEMENT` 는 모든 버킷에서 제외된다(원본 EXPENSE 로 이미 집계됨).
     */
    fun bucketsOf(transfers: List<Transfer>): TransferBuckets {
        var income = 0L
        var expense = 0L
        var generic = 0L
        var counted = 0
        for (transfer in transfers) {
            when (transfer.kind) {
                TransferKind.CARD_SETTLEMENT -> continue
                TransferKind.EXPENSE_TRANSFER -> expense += transfer.amount
                TransferKind.INCOME_TRANSFER -> income += transfer.amount
                TransferKind.GENERIC -> generic += transfer.amount
            }
            counted++
        }
        return TransferBuckets(income = income, expense = expense, generic = generic, count = counted)
    }

    /**
     * **거래만** 의 타입별 합계 (이체 미포함).
     *
     * 이체를 [transferBuckets] 로 따로 집계하는 호출부는 이 함수를 써야 한다 —
     * [totalIncome]/[totalExpense] 는 이체를 포함하므로 함께 쓰면 **이중 계산**이 된다.
     */
    fun transactionOnlyTotal(
        coupleId: UUID,
        from: LocalDate,
        to: LocalDate,
        type: TransactionType,
        userId: UUID,
        visibility: String = "ALL",
    ): Long = sumTransactionByType(coupleId, from, to, type, userId, visibility)

    // --- 내부 헬퍼 ---

    /**
     * type IN (EXPENSE, INCOME) 만 반환하는 `sumByTypeForCouple` 의 래퍼.
     * ADJUSTMENT 는 집계 범주 밖이므로 여기서 걸러진다.
     */
    private fun sumTransactionByType(
        coupleId: UUID,
        from: LocalDate,
        to: LocalDate,
        type: TransactionType,
        userId: UUID,
        visibility: String,
    ): Long {
        require(type == TransactionType.EXPENSE || type == TransactionType.INCOME) {
            "ExpenseCalculator 는 EXPENSE/INCOME 만 집계합니다. ADJUSTMENT 는 통계에서 제외됩니다."
        }
        val rows = transactionRepository.sumByTypeForCouple(coupleId, from, to, userId, visibility)
        return rows
            .filter { it[0] as TransactionType == type }
            .sumOf { it[1] as Long }
    }
}
