package com.budgetbook.transaction.domain

import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.collections.shouldContain
import io.kotest.matchers.shouldBe

/**
 * Phase 22 — TransactionType.ADJUSTMENT 의 의미 확인 테스트.
 *
 * 이 테스트는 ADJUSTMENT 가:
 *   1. TransactionType enum 에 존재
 *   2. 통계 집계 도메인 모델 상 EXPENSE/INCOME 과 다른 범주임을 명시
 *
 * 실제 집계 로직은 [com.budgetbook.statistics.service.ExpenseCalculatorTest] 와
 * [com.budgetbook.statistics.service.StatisticsServiceTest] 에서 검증.
 * 잔액 포함은 TransactionRepository 쿼리 레벨에서 보장됨(V54 + netAmountByPaymentMethodForCouple 업데이트).
 */
class AdjustmentTransactionTest : FunSpec({

    test("ADJUSTMENT is a valid TransactionType") {
        TransactionType.entries.map { it.name } shouldContain "ADJUSTMENT"
    }

    test("TransactionType has exactly three values in Phase 22") {
        TransactionType.entries.size shouldBe 3
    }

    test("ADJUSTMENT is distinct from EXPENSE and INCOME") {
        TransactionType.ADJUSTMENT shouldBe TransactionType.ADJUSTMENT
        (TransactionType.ADJUSTMENT == TransactionType.EXPENSE) shouldBe false
        (TransactionType.ADJUSTMENT == TransactionType.INCOME) shouldBe false
    }
})
