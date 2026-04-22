package com.budgetbook.transfer.domain

/**
 * 이체의 의미 분류. Phase 22 도입.
 *
 * 기존 `Transfer.isCardSettlement: Boolean` 을 일반화 + 의미 기반 4값으로 확장.
 *
 * 집계 정책:
 * - `CARD_SETTLEMENT`: 지출/수입 양쪽 모두 **제외** (원본 EXPENSE 가 이미 집계됨)
 * - `EXPENSE_TRANSFER`: **지출** 에 포함 (수입엔 영향 없음)
 * - `INCOME_TRANSFER`: **수입** 에 포함 (지출엔 영향 없음)
 * - `GENERIC`: 지출/수입 모두 제외, `totalTransfer` 별도 집계
 */
enum class TransferKind {
    /**
     * 은행 → 카드. 카드 사용 거래의 지급 완료.
     * - 원본 Transaction(EXPENSE) 이 이미 해당 월 지출로 집계됨
     * - 이 이체는 지출/수입 양쪽 집계 모두 **제외**
     * - `markAsPaid` 로 원본의 `paid_at` 만 업데이트
     */
    CARD_SETTLEMENT,

    /**
     * "이체로 기록된 지출" (Phase 22 신규).
     * - 예: 카드로 쓴 것처럼 돈이 나갔지만 은행↔다른계좌 흐름으로 1건 기록 선호
     * - EXPENSE+INCOME 2건 분리 대신 이체 1건 → 수입 과장 방지
     * - 지출 총액에 OUT 금액이 **포함**, 수입엔 영향 없음
     */
    EXPENSE_TRANSFER,

    /**
     * "이체로 기록된 수입" (Phase 22 신규, 대칭).
     * - 예: 환급성 이체이지만 수입으로 반영하고 싶은 경우
     * - 수입 총액에 IN 금액이 **포함**, 지출엔 영향 없음
     */
    INCOME_TRANSFER,

    /**
     * 순수 내부 이동 (은행↔은행, 현금↔은행 등).
     * - 지출/수입 통계 모두 제외
     * - 이체 별도 집계 항목(`totalTransfer`) 에만 합산
     */
    GENERIC,
}
