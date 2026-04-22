package com.budgetbook.transfer.domain

/**
 * Phase 22 — `TransferKind` 의 자주 쓰이는 집합 상수.
 *
 * 집계 경로에서 "어떤 kind 를 포함할지" 를 호출부가 매번 Set 리터럴로 만들면 실수가 잦아진다.
 * 의미 기반 상수를 여기에 고정해두고, `ExpenseCalculator` 와 통계 서비스에서 일관되게 사용한다.
 */
object TransferKinds {

    /** 카드 결제를 제외한 모든 kind. 과거 `!isCardSettlement` 필터의 대체. */
    val NON_CARD_SETTLEMENT: Set<TransferKind> = setOf(
        TransferKind.EXPENSE_TRANSFER,
        TransferKind.INCOME_TRANSFER,
        TransferKind.GENERIC,
    )

    /** 지출 집계에 포함되는 Transfer 종류 (OUT 기준 합산 대상). */
    val EXPENSE_AFFECTING: Set<TransferKind> = setOf(TransferKind.EXPENSE_TRANSFER)

    /** 수입 집계에 포함되는 Transfer 종류 (IN 기준 합산 대상). */
    val INCOME_AFFECTING: Set<TransferKind> = setOf(TransferKind.INCOME_TRANSFER)

    /** 순수 내부 이체 (totalTransfer 전용). */
    val TRANSFER_ONLY: Set<TransferKind> = setOf(TransferKind.GENERIC)
}
