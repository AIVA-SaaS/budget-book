package com.budgetbook.reconciliation.service

import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transfer.domain.TransferKind
import org.springframework.stereotype.Component

/**
 * "무엇이 정산 대상인가" 의 **단일 정의**.
 *
 * 정산(reconciliation)은 통장·카드 명세와 장부를 1:1 로 대조하는 작업이다. 따라서
 * **실제로 돈이 오간 사건만** 대상이다. 금액 집계 규칙(`ReconciliationAggregator`) 과는
 * 별개의 질문이라 분리한다 — 집계에서 0 원 취급하는 것과, 목록에서 아예 빼는 것은 다르다.
 *
 * ## 왜 별도 컴포넌트인가 (하네스 amount_calculation, 구조적 강제)
 *
 * 같은 규칙이 요약 계산·목록 쿼리·스냅샷 생성 세 군데에 필요하다. 각자 `!= ADJUSTMENT`
 * 를 적으면 한 곳만 고치는 사고가 난다(과거 6회). `when` 을 **`else` 없이** 전부 나열해
 * 두었으므로 `TransactionType`/`TransferKind` 에 값이 추가되면 **컴파일이 깨진다** →
 * "이 새 종류는 정산 대상인가" 판단을 강제한다.
 *
 * 쿼리(JPA Criteria)에서 쓰는 제외 목록도 손으로 적지 않고 [excludedTransactionTypes] 로
 * **파생**시킨다. 정의가 두 벌이 될 수 없다.
 */
@Component
class ReconciliationScope {

    /**
     * `ADJUSTMENT` 는 실잔액 보정 항목이다 — 통장에 대응하는 사건이 없으므로 대조할 것이
     * 없고, 미기록 목록에 남으면 "이 달 정산 완료" 에 영원히 도달하지 못한다.
     */
    fun isReconcilable(type: TransactionType): Boolean = when (type) {
        TransactionType.INCOME -> true
        TransactionType.EXPENSE -> true
        TransactionType.ADJUSTMENT -> false
    }

    /**
     * 이체는 전부 대상이다.
     *
     * `CARD_SETTLEMENT` 는 소계 집계에서만 제외된다(원본 지출이 이미 잡혀 이중 계상이 되므로).
     * 그러나 **계좌에서 실제로 돈이 빠져나간 사건**이라 통장 대조 대상이다 — 목록에서 빼면
     * 카드 결제일 출금이 영원히 미대조로 남는다.
     */
    fun isReconcilable(kind: TransferKind): Boolean = when (kind) {
        TransferKind.GENERIC -> true
        TransferKind.EXPENSE_TRANSFER -> true
        TransferKind.INCOME_TRANSFER -> true
        TransferKind.CARD_SETTLEMENT -> true
    }

    /** 쿼리용 제외 목록. [isReconcilable] 에서 **파생** — 별도로 관리하지 않는다. */
    val excludedTransactionTypes: Set<TransactionType> =
        TransactionType.entries.filterNot { isReconcilable(it) }.toSet()

    companion object {
        /**
         * JPA Specification 처럼 스프링 빈 주입이 어려운 지점을 위한 정적 사본.
         * 인스턴스 메서드와 같은 정의를 쓰도록 [ReconciliationScope] 를 그대로 사용한다.
         */
        private val INSTANCE = ReconciliationScope()

        val EXCLUDED_TRANSACTION_TYPES: Set<TransactionType> = INSTANCE.excludedTransactionTypes
    }
}
