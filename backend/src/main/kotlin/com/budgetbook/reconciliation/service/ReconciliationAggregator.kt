package com.budgetbook.reconciliation.service

import com.budgetbook.reconciliation.domain.ReconciliationItem
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transfer.domain.TransferKind
import org.springframework.stereotype.Component

/**
 * 정산 스냅샷 소계 집계의 **단일 진입점**.
 *
 * 금액 집계 로직이 여러 곳에 흩어져 "한 곳만 고치고 나머지를 빠뜨리는" 사고가 6회 반복됐다
 * (2026-04-02 19곳 누락, 2026-04-14 이체 이중 합산, 카드 요약 이체 미포함 …).
 * 그래서 정산 관련 합계는 반드시 이 컴포넌트만 사용한다 — 서비스·컨트롤러에서
 * `sumOf` 를 직접 쓰지 않는다.
 *
 * 규칙은 기존 장부 집계(`ExpenseCalculator`, FE `LedgerSummary.from`) 와 1:1 대응한다.
 * - Transaction INCOME → 수입 / EXPENSE → 지출 / **ADJUSTMENT → 양쪽 제외**
 * - Transfer EXPENSE_TRANSFER → 지출 / INCOME_TRANSFER → 수입 / GENERIC → 이체
 * - Transfer **CARD_SETTLEMENT → 전 버킷 제외** (원본 지출이 이미 집계됨)
 *
 * 집계는 항목의 `snapshotKind`/`snapshotAmount` 기준이다. 원본이 삭제된 뒤에도
 * 스냅샷 소계가 유지되어야 하기 때문이다(= 스냅샷의 존재 이유).
 */
@Component
class ReconciliationAggregator {

    data class Totals(
        val itemCount: Int,
        val totalIncome: Long,
        val totalExpense: Long,
        val totalTransfer: Long
    ) {
        companion object {
            val ZERO = Totals(0, 0, 0, 0)
        }
    }

    /**
     * 집계 입력의 최소 단위. 스냅샷 항목뿐 아니라 **미기록 항목**(아직 스냅샷이 아닌 거래/이체)도
     * 같은 규칙으로 집계하기 위한 표현이다 — 규칙이 두 벌로 갈라지면
     * "미기록 + Σ스냅샷 = 월 전체" 가 깨진다.
     */
    data class Entry(val kind: String, val amount: Long)

    fun aggregate(items: Collection<ReconciliationItem>): Totals =
        aggregateEntries(items.map { Entry(it.snapshotKind, it.snapshotAmount) })

    fun aggregateEntries(entries: Collection<Entry>): Totals {
        var income = 0L
        var expense = 0L
        var transfer = 0L

        for (entry in entries) {
            when (entry.kind) {
                TransactionType.INCOME.name -> income += entry.amount
                TransactionType.EXPENSE.name -> expense += entry.amount
                // ADJUSTMENT: 실잔액 보정용 — 수입/지출 어디에도 넣지 않는다.
                TransactionType.ADJUSTMENT.name -> Unit
                TransferKind.EXPENSE_TRANSFER.name -> expense += entry.amount
                TransferKind.INCOME_TRANSFER.name -> income += entry.amount
                TransferKind.GENERIC.name -> transfer += entry.amount
                // CARD_SETTLEMENT: 원본 EXPENSE 가 이미 집계됨 → 이중 계상 방지로 제외.
                TransferKind.CARD_SETTLEMENT.name -> Unit
                else -> Unit
            }
        }

        return Totals(
            itemCount = entries.size,
            totalIncome = income,
            totalExpense = expense,
            totalTransfer = transfer
        )
    }

    /** 거래/이체 원본으로부터 스냅샷에 저장할 분류 문자열을 만든다. */
    fun snapshotKindOf(type: TransactionType): String = type.name

    fun snapshotKindOf(kind: TransferKind): String = kind.name
}
