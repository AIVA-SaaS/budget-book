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
        userId: UUID? = null
    ): Specification<Transaction> {
        return Specification { root: Root<Transaction>, _: CriteriaQuery<*>, cb: CriteriaBuilder ->
            val predicates = mutableListOf<Predicate>()

            predicates.add(cb.equal(root.get<Any>("couple").get<UUID>("id"), coupleId))
            predicates.add(cb.between(root.get("transactionDate"), startDate, endDate))

            type?.let {
                predicates.add(cb.equal(root.get<TransactionType>("type"), it))
            }

            categoryId?.let {
                predicates.add(cb.equal(root.get<Any>("category").get<UUID>("id"), it))
            }

            keyword?.takeIf { it.isNotBlank() }?.let {
                predicates.add(cb.like(cb.lower(root.get("description")), "%${it.lowercase()}%"))
            }

            paymentMethodId?.let {
                predicates.add(cb.equal(root.get<Any>("paymentMethod").get<UUID>("id"), it))
            }

            pocketId?.let {
                predicates.add(cb.equal(root.get<Any>("pocket").get<UUID>("id"), it))
            }

            amountMin?.let {
                predicates.add(cb.greaterThanOrEqualTo(root.get("amount"), it))
            }

            amountMax?.let {
                predicates.add(cb.lessThanOrEqualTo(root.get("amount"), it))
            }

            // Visibility filter: SHARED or owned by current user
            userId?.let { uid ->
                predicates.add(
                    cb.or(
                        cb.equal(root.get<Visibility>("visibility"), Visibility.SHARED),
                        cb.equal(root.get<Any>("owner").get<UUID>("id"), uid)
                    )
                )
            }

            cb.and(*predicates.toTypedArray())
        }
    }
}
