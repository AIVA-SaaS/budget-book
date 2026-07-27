package com.budgetbook.reconciliation.service

import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transfer.domain.TransferKind
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.shouldBe

/**
 * "무엇이 정산 대상인가" 규칙 고정.
 *
 * 규칙 자체는 한 줄짜리지만, **정의가 두 벌로 갈라지는 것**이 실제 사고였다
 * (집계는 잔액 수정을 뺐는데 목록·건수는 그대로 → 미기록이 영원히 0 이 되지 않음).
 * 그래서 여기서는 판정뿐 아니라 **쿼리용 제외 목록이 판정에서 파생되는지**도 검증한다.
 */
class ReconciliationScopeTest : FunSpec({

    val scope = ReconciliationScope()

    test("잔액 수정만 정산 대상에서 빠진다") {
        scope.isReconcilable(TransactionType.EXPENSE) shouldBe true
        scope.isReconcilable(TransactionType.INCOME) shouldBe true
        scope.isReconcilable(TransactionType.ADJUSTMENT) shouldBe false
    }

    test("이체는 종류와 무관하게 전부 대상 — 카드 결제도 실제 출금이라 대조 대상") {
        TransferKind.entries.forEach { kind ->
            scope.isReconcilable(kind) shouldBe true
        }
    }

    test("쿼리용 제외 목록은 판정에서 파생된다 (손으로 관리하지 않는다)") {
        scope.excludedTransactionTypes shouldContainExactly setOf(TransactionType.ADJUSTMENT)
        // Specification 이 참조하는 정적 사본도 같은 값이어야 한다.
        ReconciliationScope.EXCLUDED_TRANSACTION_TYPES shouldBe scope.excludedTransactionTypes
    }

    test("모든 거래 타입은 대상/비대상 중 하나로 분류돼야 한다") {
        // when 이 exhaustive 이므로 컴파일 타임에도 강제되지만, 새 타입이 들어왔을 때
        // "일단 false 로 두고 잊는" 실수를 이 테스트가 드러낸다.
        val classified = TransactionType.entries.partition { scope.isReconcilable(it) }
        (classified.first.size + classified.second.size) shouldBe TransactionType.entries.size
        classified.first.isNotEmpty() shouldBe true
    }
})
