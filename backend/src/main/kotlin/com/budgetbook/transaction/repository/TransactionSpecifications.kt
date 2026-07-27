package com.budgetbook.transaction.repository

import com.budgetbook.common.entity.Visibility
import com.budgetbook.reconciliation.domain.ReconciliationItem
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import jakarta.persistence.criteria.CriteriaBuilder
import jakarta.persistence.criteria.CriteriaQuery
import jakarta.persistence.criteria.Predicate
import jakarta.persistence.criteria.Root
import org.springframework.data.jpa.domain.Specification
import java.time.LocalDate
import java.util.UUID

object TransactionSpecifications {

    fun withFilters(
        coupleId: UUID,
        startDate: LocalDate,
        endDate: LocalDate,
        type: TransactionType?,
        categoryId: UUID?,
        keyword: String?,
        paymentMethodId: UUID?,
        pocketId: UUID?,
        amountMin: Long?,
        amountMax: Long?,
        userId: UUID? = null,
        // null/"ALL": 기본 동작(공유 + 본인 개인). "SHARED": 공유 거래만. "PRIVATE": 본인 개인만.
        // 호출자(Service) 단계에서 이미 uppercase 정규화 + 유효성 검증된 값.
        visibility: String? = null,
        // PR-C2 다중/그룹 필터. 빈 Set 은 무조건부 (필터 없음). 단수 categoryId/paymentMethodId/pocketId 와
        // 병존 시 호출자(Service) 에서 합집합 Set 을 만들어 단수는 null 로 넘기고 Set 만 사용하도록 권장.
        categoryIds: Set<UUID> = emptySet(),
        paymentMethodIds: Set<UUID> = emptySet(),
        pocketIds: Set<UUID> = emptySet(),
        // Phase 22 T10 다중 타입 필터. 단수 `type` 과 병존 시 호출자(Service) 에서 단수를 null 로 넘김.
        types: Set<TransactionType> = emptySet(),
        // V61 (2026-05-06) — true 면 needs_review=true 거래만 (확인/입력 필요만 보기).
        // null/false 모두 미적용으로 처리 — "false 만 보기" 시나리오는 현재 요구 없음.
        needsReviewOnly: Boolean? = null,
        // V65 (2026-07-27) 정산 스냅샷 필터.
        //   false = 미기록만 (어떤 스냅샷에도 없는 거래), true = 기록된 것만, null = 전체.
        // 목록은 페이지네이션되므로 미기록 판정을 클라이언트에서 하면 미로드 페이지 항목이
        // 누락된다 → 반드시 서버(이 조건)에서 걸러야 한다.
        reconciled: Boolean? = null
    ): Specification<Transaction> {
        return Specification { root: Root<Transaction>, query: CriteriaQuery<*>, cb: CriteriaBuilder ->
            val predicates = mutableListOf<Predicate>()

            predicates.add(cb.equal(root.get<Any>("couple").get<UUID>("id"), coupleId))
            predicates.add(cb.between(root.get("transactionDate"), startDate, endDate))

            type?.let {
                predicates.add(cb.equal(root.get<TransactionType>("type"), it))
            }

            if (types.isNotEmpty()) {
                predicates.add(root.get<TransactionType>("type").`in`(types))
            }

            categoryId?.let {
                predicates.add(cb.equal(root.get<Any>("category").get<UUID>("id"), it))
            }

            if (categoryIds.isNotEmpty()) {
                predicates.add(root.get<Any>("category").get<UUID>("id").`in`(categoryIds))
            }

            keyword?.takeIf { it.isNotBlank() }?.let {
                predicates.add(cb.like(cb.lower(root.get("description")), "%${it.lowercase()}%"))
            }

            paymentMethodId?.let {
                predicates.add(cb.equal(root.get<Any>("paymentMethod").get<UUID>("id"), it))
            }

            if (paymentMethodIds.isNotEmpty()) {
                predicates.add(root.get<Any>("paymentMethod").get<UUID>("id").`in`(paymentMethodIds))
            }

            pocketId?.let {
                predicates.add(cb.equal(root.get<Any>("pocket").get<UUID>("id"), it))
            }

            if (pocketIds.isNotEmpty()) {
                predicates.add(root.get<Any>("pocket").get<UUID>("id").`in`(pocketIds))
            }

            amountMin?.let {
                predicates.add(cb.greaterThanOrEqualTo(root.get("amount"), it))
            }

            amountMax?.let {
                predicates.add(cb.lessThanOrEqualTo(root.get("amount"), it))
            }

            // V61 — 확인/입력 필요만 보기. true 일 때만 조건 추가.
            if (needsReviewOnly == true) {
                predicates.add(cb.isTrue(root.get("needsReview")))
            }

            // V65 — 정산 스냅샷 소속 여부. reconciliation_items 에 이 거래를 참조하는 행이
            // 있는지로 판정한다. partial unique index `uk_recon_items_transaction` 가
            // (transaction_id) 를 덮으므로 인덱스 스캔 1회로 끝난다.
            reconciled?.let { wantReconciled ->
                val subquery = query.subquery(UUID::class.java)
                val itemRoot = subquery.from(ReconciliationItem::class.java)
                subquery.select(itemRoot.get("id"))
                subquery.where(cb.equal(itemRoot.get<UUID>("transactionId"), root.get<UUID>("id")))
                predicates.add(
                    if (wantReconciled) cb.exists(subquery) else cb.not(cb.exists(subquery))
                )
            }

            // Visibility 필터:
            //   - "SHARED": 커플 공유 거래만
            //   - "PRIVATE": 본인 소유 개인 거래만 (커플 모드에서 상대방 PRIVATE 은 자연스럽게 제외)
            //   - null/"ALL": 기본 정책(공유 + 본인 개인)
            when (visibility) {
                "SHARED" -> {
                    predicates.add(cb.equal(root.get<Visibility>("visibility"), Visibility.SHARED))
                }
                "PRIVATE" -> {
                    predicates.add(cb.equal(root.get<Visibility>("visibility"), Visibility.PRIVATE))
                    userId?.let { uid ->
                        predicates.add(cb.equal(root.get<Any>("owner").get<UUID>("id"), uid))
                    }
                }
                else -> {
                    userId?.let { uid ->
                        predicates.add(
                            cb.or(
                                cb.equal(root.get<Visibility>("visibility"), Visibility.SHARED),
                                cb.equal(root.get<Any>("owner").get<UUID>("id"), uid)
                            )
                        )
                    }
                }
            }

            cb.and(*predicates.toTypedArray())
        }
    }
}
