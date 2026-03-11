package com.budgetbook.recurring.repository

import com.budgetbook.recurring.domain.RecurringTransaction
import org.springframework.data.jpa.repository.JpaRepository
import java.time.LocalDate
import java.util.UUID

interface RecurringTransactionRepository : JpaRepository<RecurringTransaction, UUID> {
    fun findByCoupleIdAndIsActiveTrue(coupleId: UUID): List<RecurringTransaction>
    fun findByCoupleId(coupleId: UUID): List<RecurringTransaction>
    fun findByNextRunDateLessThanEqualAndIsActiveTrue(date: LocalDate): List<RecurringTransaction>
}
