package com.budgetbook.transaction.repository

import com.budgetbook.common.entity.Visibility
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
        types: Set<TransactionType> = emptySet()
    ): Specification<Transaction> {
        return Specification { root: Root<Transaction>, _: CriteriaQuery<*>, cb: CriteriaBuilder ->
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
