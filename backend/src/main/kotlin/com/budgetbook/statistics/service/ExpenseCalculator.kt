package com.budgetbook.statistics.service

import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.domain.TransferKinds
import com.budgetbook.transfer.repository.TransferRepository
import org.springframework.stereotype.Component
import java.time.LocalDate
import java.util.UUID

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
