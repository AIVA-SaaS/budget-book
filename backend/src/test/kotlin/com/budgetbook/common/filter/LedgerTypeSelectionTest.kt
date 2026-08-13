package com.budgetbook.common.filter

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.transaction.domain.TransactionType
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe

/**
 * 타입 선택 파싱 규칙.
 *
 * 핵심은 세 상태를 구분하는 것이다:
 *  - 필터 없음(전체)
 *  - 거래 타입이 선택됨
 *  - 필터는 켜졌으나 거래 타입이 하나도 없음("이체만 보기") → 거래는 0건
 *
 * 마지막 상태를 "필터 없음" 과 혼동하면 이체만 보기에서 거래 합계가 그대로 남는다
 * (구현 중 실제로 한 번 발생 — 회귀 가드).
 */
class LedgerTypeSelectionTest : FunSpec({

    test("null and empty mean no filter") {
        listOf(null, emptyList(), listOf("", "  ")).forEach { raw ->
            val selection = LedgerTypeSelection.parse(raw)
            selection.hasSelection shouldBe false
            selection.matchesNoTransaction shouldBe false
            selection.includesTransfers shouldBe true
        }
    }

    test("TRANSFER alone selects no transaction type but keeps transfers") {
        val selection = LedgerTypeSelection.parse(listOf("TRANSFER"))

        selection.hasSelection shouldBe true
        selection.transactionTypes shouldBe emptySet()
        selection.matchesNoTransaction shouldBe true
        selection.includesTransfers shouldBe true
    }

    test("EXPENSE alone excludes transfers") {
        val selection = LedgerTypeSelection.parse(listOf("EXPENSE"))

        selection.transactionTypes shouldBe setOf(TransactionType.EXPENSE)
        selection.matchesNoTransaction shouldBe false
        selection.includesTransfers shouldBe false
    }

    test("EXPENSE + TRANSFER keeps both streams") {
        val selection = LedgerTypeSelection.parse(listOf("EXPENSE", "TRANSFER"))

        selection.transactionTypes shouldBe setOf(TransactionType.EXPENSE)
        selection.includesTransfers shouldBe true
        selection.matchesNoTransaction shouldBe false
    }

    test("values are case-insensitive and trimmed") {
        val selection = LedgerTypeSelection.parse(listOf(" expense ", "transfer"))

        selection.transactionTypes shouldBe setOf(TransactionType.EXPENSE)
        selection.includesTransfers shouldBe true
    }

    test("an unknown value is still a validation error") {
        shouldThrow<BusinessException> {
            LedgerTypeSelection.parse(listOf("EXPENSE", "BOGUS"))
        }.code shouldBe "VALIDATION_ERROR"
    }
})
