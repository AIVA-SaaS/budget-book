package com.budgetbook.recurring.repository

import com.budgetbook.recurring.domain.RecurringTransaction
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.LocalDate
import java.util.UUID

interface RecurringTransactionRepository : JpaRepository<RecurringTransaction, UUID> {
    fun findByCoupleIdAndIsActiveTrue(coupleId: UUID): List<RecurringTransaction>
    fun findByCoupleId(coupleId: UUID): List<RecurringTransaction>
    fun findByNextRunDateLessThanEqualAndIsActiveTrue(date: LocalDate): List<RecurringTransaction>

    @Query("""
        SELECT r FROM RecurringTransaction r
        WHERE r.couple.id = :coupleId
        AND (r.visibility = com.budgetbook.common.entity.Visibility.SHARED OR r.author.id = :userId)
    """)
    fun findByCoupleIdAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<RecurringTransaction>
}
