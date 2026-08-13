package com.budgetbook.common.filter

/**
 * 장부 필터(`CommonFilterParams`)의 **축 1개 = enum 1개** 대응.
 *
 * ## 왜 이 enum 이 있는가 (2026-08-12, filter_propagation 4회 재발 후 구조적 봉인)
 *
 * 장부 목록은 거래(`transactions`)와 이체(`transfers`) 두 테이블을 합쳐 보여준다.
 * 필터 축이 추가될 때마다 **한쪽 스트림에서만 축이 누락**되는 사고가 반복됐다:
 *  - 이체에 `needsReviewOnly` / 카테고리 / 포켓 / 금액이 미적용
 *  - 결제수단은 복수 선택인데 첫 1개만 적용
 *  - 합계는 이체를 빼는데 목록에는 이체가 남음 ("합계 ≠ 행")
 *
 * 그래서 축을 enum 으로 열거하고 [com.budgetbook.transfer.service.TransferGating.handling] 이
 * `when` 을 **exhaustive** 로 처리한다. 축을 추가하면 그 `when` 이 **컴파일 실패**하므로
 * "이체에서 이 축을 어떻게 다루는지" 를 선언하지 않고는 빌드가 되지 않는다.
 *
 * [propertyName] 은 `CommonFilterParams` 의 프로퍼티명과 1:1 이어야 하며,
 * `LedgerFilterAxisGuardTest` 가 리플렉션으로 그 대응을 고정한다.
 */
enum class LedgerFilterAxis(val propertyName: String) {
    DATE_FROM("dateFrom"),
    DATE_TO("dateTo"),
    YEAR("year"),
    MONTH("month"),
    CATEGORY_ID("categoryId"),
    PAYMENT_METHOD_ID("paymentMethodId"),
    POCKET_ID("pocketId"),
    CATEGORY_IDS("categoryIds"),
    CATEGORY_GROUP_IDS("categoryGroupIds"),
    PAYMENT_METHOD_IDS("paymentMethodIds"),
    POCKET_IDS("pocketIds"),
    AMOUNT_MIN("amountMin"),
    AMOUNT_MAX("amountMax"),
    KEYWORD("keyword"),
    VISIBILITY("visibility"),
    TYPE("type"),
    TRANSACTION_TYPES("transactionTypes"),
    STATUS("status"),
    NEEDS_REVIEW_ONLY("needsReviewOnly"),
    RECONCILED("reconciled"),
}

/**
 * 각 축을 **이체 스트림**에서 어떻게 다루는지의 분류.
 *
 * 이체(`Transfer`)에는 카테고리 / 포켓 / needsReview / visibility 필드가 없다.
 * 그런 축이 켜지면 이체는 논리적으로 매칭 불가이므로 전량 제외가 정답이다
 * (과거에는 필터를 무시하고 그대로 노출해서 "거래는 맞는데 이체만 남는" 비대칭을 만들었다).
 */
enum class TransferAxisHandling {
    /** 이체에도 그대로 적용된다 (기간·결제수단·금액·검색어·정산 여부). */
    APPLIES,

    /** 이체에 없는 축 → 활성 시 이체를 **전량 제외**한다. */
    EXCLUDES_WHOLESALE,

    /** 집계·조회 **범위**를 결정하는 축. 거래·이체·합계가 같은 범위를 본다. */
    RANGE,

    /** 장부 게이팅과 무관한 축 (다른 화면 전용). */
    IRRELEVANT,
}
