package com.budgetbook.reconciliation.service

import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transfer.domain.TransferKind
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.kotest.property.Arb
import io.kotest.property.arbitrary.enum
import io.kotest.property.arbitrary.int
import io.kotest.property.arbitrary.list
import io.kotest.property.arbitrary.long
import io.kotest.property.arbitrary.map
import io.kotest.property.checkAll

/**
 * 정산 소계 집계 규칙 고정.
 *
 * 금액 로직을 한 곳만 고쳐 나머지를 빠뜨리는 사고가 6회 반복됐다. 이 테스트는 규칙 자체
 * (어떤 종류가 어느 버킷으로 가는지)와 **분할 정합성**(미기록 + Σ스냅샷 = 전체)을 고정한다.
 */
class ReconciliationAggregatorTest : FunSpec({

    val aggregator = ReconciliationAggregator()

    fun entry(kind: String, amount: Long) = ReconciliationAggregator.Entry(kind, amount)

    test("Transaction INCOME/EXPENSE 는 각 버킷으로 간다") {
        val totals = aggregator.aggregateEntries(
            listOf(
                entry(TransactionType.INCOME.name, 30000),
                entry(TransactionType.EXPENSE.name, 10000)
            )
        )
        totals.totalIncome shouldBe 30000
        totals.totalExpense shouldBe 10000
        totals.totalTransfer shouldBe 0
        totals.itemCount shouldBe 2
    }

    test("ADJUSTMENT 는 수입/지출 어디에도 들어가지 않는다") {
        val totals = aggregator.aggregateEntries(
            listOf(entry(TransactionType.ADJUSTMENT.name, -5000))
        )
        totals.totalIncome shouldBe 0
        totals.totalExpense shouldBe 0
        totals.totalTransfer shouldBe 0
        // 항목 수에는 포함된다 (정산 대상 항목이긴 하다).
        totals.itemCount shouldBe 1
    }

    test("CARD_SETTLEMENT 이체는 전 버킷에서 제외된다 (원본 지출 이중 계상 방지)") {
        val totals = aggregator.aggregateEntries(
            listOf(entry(TransferKind.CARD_SETTLEMENT.name, 500000))
        )
        totals.totalIncome shouldBe 0
        totals.totalExpense shouldBe 0
        totals.totalTransfer shouldBe 0
    }

    test("EXPENSE_TRANSFER→지출, INCOME_TRANSFER→수입, GENERIC→이체") {
        val totals = aggregator.aggregateEntries(
            listOf(
                entry(TransferKind.EXPENSE_TRANSFER.name, 7000),
                entry(TransferKind.INCOME_TRANSFER.name, 8000),
                entry(TransferKind.GENERIC.name, 9000)
            )
        )
        totals.totalExpense shouldBe 7000
        totals.totalIncome shouldBe 8000
        totals.totalTransfer shouldBe 9000
    }

    test("빈 입력은 0") {
        aggregator.aggregateEntries(emptyList()) shouldBe ReconciliationAggregator.Totals.ZERO
    }

    // ── 분할 정합성 (property) ────────────────────────────────────────────────
    //
    // "미기록 + Σ스냅샷 = 월 전체" 는 정산 화면의 상단/하단이 MECE 라는 전제 그 자체다.
    // 임의의 항목 집합을 임의로 쪼개도 합이 보존되는지 확인한다.

    test("항목 집합을 어떻게 쪼개도 소계 합은 전체와 같다") {
        val kindArb = Arb.enum<SplitKind>().map { it.wire }
        val entriesArb = Arb.list(
            Arb.long(0L..1_000_000L).map { amount -> amount },
            0..40
        )

        checkAll(entriesArb, Arb.list(kindArb, 0..40), Arb.int(0..40)) { amounts, kinds, splitAt ->
            val entries = amounts.zip(kinds) { amount, kind -> entry(kind, amount) }
            val whole = aggregator.aggregateEntries(entries)

            val cut = splitAt.coerceIn(0, entries.size)
            val left = aggregator.aggregateEntries(entries.take(cut))
            val right = aggregator.aggregateEntries(entries.drop(cut))

            (left.itemCount + right.itemCount) shouldBe whole.itemCount
            (left.totalIncome + right.totalIncome) shouldBe whole.totalIncome
            (left.totalExpense + right.totalExpense) shouldBe whole.totalExpense
            (left.totalTransfer + right.totalTransfer) shouldBe whole.totalTransfer
        }
    }

    test("알 수 없는 종류는 어느 버킷에도 더해지지 않는다 (미래 enum 추가 시 오염 방지)") {
        val totals = aggregator.aggregateEntries(listOf(entry("SOME_FUTURE_KIND", 12345)))
        totals.totalIncome shouldBe 0
        totals.totalExpense shouldBe 0
        totals.totalTransfer shouldBe 0
        totals.itemCount shouldBe 1
    }
})

/** property 테스트용 종류 목록 (거래 타입 + 이체 kind 전체). */
private enum class SplitKind(val wire: String) {
    INCOME("INCOME"),
    EXPENSE("EXPENSE"),
    ADJUSTMENT("ADJUSTMENT"),
    CARD_SETTLEMENT("CARD_SETTLEMENT"),
    EXPENSE_TRANSFER("EXPENSE_TRANSFER"),
    INCOME_TRANSFER("INCOME_TRANSFER"),
    GENERIC("GENERIC")
}
