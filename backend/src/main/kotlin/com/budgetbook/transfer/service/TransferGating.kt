package com.budgetbook.transfer.service

import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.common.filter.LedgerFilterAxis
import com.budgetbook.common.filter.LedgerTypeSelection
import com.budgetbook.common.filter.TransferAxisHandling
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.transfer.domain.Transfer
import jakarta.persistence.criteria.Predicate
import org.springframework.data.jpa.domain.Specification
import java.time.LocalDate
import java.util.UUID

/**
 * 장부 필터를 **이체 스트림**에 적용하는 단일 판정 지점.
 *
 * ## 이 파일이 유일한 판정이다
 *
 * 이체 **목록 조회**([spec])와 이체 **집계**(`ExpenseCalculator.transferBuckets`)가
 * 같은 함수를 쓴다. 한쪽만 고치는 것이 구조적으로 불가능하다 —
 * 그것이 "합계 ≠ 행" 불일치의 재발 메커니즘이었다.
 *
 * 과거에는 같은 판정이 FE `ledger_gating.dart` 에도 있었다(총 2곳).
 * 2026-08-12 회차에서 판정을 서버로 모으고 FE 는 서버 결과를 그대로 소비한다.
 *
 * 축을 추가하면 [handling] 의 `when` 이 컴파일 실패한다 → 분류 선언을 강제한다.
 */
object TransferGating {

    /**
     * 축별 처리 분류. **exhaustive `when`** — 축이 늘면 여기서 컴파일이 막힌다.
     *
     * 이 함수는 문서이자 게이트다. 실제 판정은 [excludedWholesale] 과 [spec] 이 수행하며,
     * `TransferGatingAxisTest` 가 둘의 분류 일치를 검증한다.
     */
    fun handling(axis: LedgerFilterAxis): TransferAxisHandling = when (axis) {
        // 범위 — 거래·이체·합계가 같은 기간을 본다.
        LedgerFilterAxis.DATE_FROM,
        LedgerFilterAxis.DATE_TO,
        LedgerFilterAxis.YEAR,
        LedgerFilterAxis.MONTH -> TransferAxisHandling.RANGE

        // 이체에도 적용되는 축.
        LedgerFilterAxis.PAYMENT_METHOD_ID,
        LedgerFilterAxis.PAYMENT_METHOD_IDS,
        LedgerFilterAxis.AMOUNT_MIN,
        LedgerFilterAxis.AMOUNT_MAX,
        LedgerFilterAxis.KEYWORD,
        LedgerFilterAxis.RECONCILED -> TransferAxisHandling.APPLIES

        // 이체에 없는 축 → 활성 시 전량 제외.
        // (VISIBILITY 는 'PRIVATE' 일 때만, TRANSACTION_TYPES 는 TRANSFER 미포함일 때만)
        LedgerFilterAxis.CATEGORY_ID,
        LedgerFilterAxis.CATEGORY_IDS,
        LedgerFilterAxis.CATEGORY_GROUP_IDS,
        LedgerFilterAxis.POCKET_ID,
        LedgerFilterAxis.POCKET_IDS,
        LedgerFilterAxis.NEEDS_REVIEW_ONLY,
        LedgerFilterAxis.VISIBILITY,
        LedgerFilterAxis.TYPE,
        LedgerFilterAxis.TRANSACTION_TYPES -> TransferAxisHandling.EXCLUDES_WHOLESALE

        // 장부 게이팅과 무관 (지출계획 등 다른 화면 전용).
        LedgerFilterAxis.STATUS -> TransferAxisHandling.IRRELEVANT
    }

    /**
     * 이체에 **존재하지 않는 축**이 활성이면 이체는 매칭 불가 → 전량 제외.
     *
     * `Transfer` 에는 category / pocket / needsReview / visibility 필드가 없다.
     */
    fun excludedWholesale(filter: CommonFilterParams): Boolean {
        // 축: needsReviewOnly — 이체엔 "확인/입력 필요" 개념이 없다.
        if (filter.needsReviewOnly == true) return true
        // 축: category (단수·복수·그룹) — 이체엔 카테고리가 없다.
        if (filter.categoryId != null ||
            filter.categoryIds.isNotEmpty() ||
            filter.categoryGroupIds.isNotEmpty()
        ) {
            return true
        }
        // 축: pocket (단수·복수) — 이체엔 포켓이 없다(포켓 이체는 별도 기능).
        if (filter.pocketId != null || filter.pocketIds.isNotEmpty()) return true
        // 축: visibility — 이체엔 visibility 가 없어 전부 "공유" 취급. 개인 필터에서는 숨긴다.
        //     개인 자산(ASSET-PRIVATE) 도입 시 source/dest 자산의 visibility 로 파생하도록 여기를 고친다.
        if (filter.visibility?.uppercase() == "PRIVATE") return true
        // 축: type (단수) — 거래 타입 전용 필터. 이체는 대상이 아니다.
        if (filter.type != null) return true
        // 축: transactionTypes — 선택에 TRANSFER 가 없으면 이체 제외 (빈 선택 = 전체).
        if (!LedgerTypeSelection.parse(filter.transactionTypes).includesTransfers) return true
        return false
    }

    /**
     * 이체에 적용 가능한 축의 쿼리 조건.
     *
     * [from]/[to] 는 호출부가 해석한 **실효 범위**다
     * (`CommonFilterParams.getEffectiveDateRange()` 와 같은 규칙이어야 한다).
     *
     * `reconciled` 는 스냅샷 조회가 필요해 여기서 다루지 않는다 —
     * 호출부가 `ReconciliationLookup` 으로 후처리한다([reconciledMatches]).
     */
    fun spec(coupleId: UUID, filter: CommonFilterParams, from: LocalDate, to: LocalDate): Specification<Transfer> =
        Specification { root, _, cb ->
            val predicates = mutableListOf<Predicate>()

            predicates += cb.equal(root.get<Any>("couple").get<UUID>("id"), coupleId)
            predicates += cb.between(root.get("transferDate"), from, to)

            // 축: paymentMethodId / paymentMethodIds — 출금·입금 **어느 쪽이든** OR 매칭.
            // (과거 FE 는 복수 선택인데 첫 1개만 적용했다)
            val pmIds = filter.paymentMethodIds.toMutableSet().also { set ->
                filter.paymentMethodId?.let { set.add(it) }
            }
            if (pmIds.isNotEmpty()) {
                val source = root.get<PaymentMethod>("sourcePaymentMethod").get<UUID>("id")
                val destination = root.get<PaymentMethod>("destinationPaymentMethod").get<UUID>("id")
                predicates += cb.or(source.`in`(pmIds), destination.`in`(pmIds))
            }

            // 축: amountMin / amountMax.
            filter.amountMin?.let { predicates += cb.greaterThanOrEqualTo(root.get("amount"), it) }
            filter.amountMax?.let { predicates += cb.lessThanOrEqualTo(root.get("amount"), it) }

            // 축: keyword — 설명 + 출금/입금 결제수단명 (FE 판정과 동일한 필드 집합).
            val keyword = filter.keyword?.trim()
            if (!keyword.isNullOrEmpty()) {
                val pattern = "%${keyword.lowercase()}%"
                val sourceName = root.join<Transfer, PaymentMethod>("sourcePaymentMethod").get<String>("name")
                val destinationName =
                    root.join<Transfer, PaymentMethod>("destinationPaymentMethod").get<String>("name")
                predicates += cb.or(
                    cb.like(cb.lower(root.get("description")), pattern),
                    cb.like(cb.lower(sourceName), pattern),
                    cb.like(cb.lower(destinationName), pattern),
                )
            }

            cb.and(*predicates.toTypedArray())
        }

    /**
     * 축: reconciled — 정산 스냅샷 유무 판정. 스냅샷은 별도 테이블이라 쿼리 후처리한다.
     * `null` = 전체 / `true` = 기록된 것만 / `false` = 미기록만.
     */
    fun reconciledMatches(reconciled: Boolean?, hasSnapshot: Boolean): Boolean = when (reconciled) {
        null -> true
        true -> hasSnapshot
        false -> !hasSnapshot
    }
}
