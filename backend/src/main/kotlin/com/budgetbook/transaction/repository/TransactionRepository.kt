package com.budgetbook.transaction.repository

import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.LocalDate
import java.util.UUID

interface TransactionRepository : JpaRepository<Transaction, UUID> {

    @Query("""
        SELECT t FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND (:type IS NULL OR t.type = :type)
        AND (:categoryId IS NULL OR t.category.id = :categoryId)
        ORDER BY t.transactionDate DESC, t.createdAt DESC
    """)
    fun findByCoupleIdAndFilters(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType?,
        @Param("categoryId") categoryId: UUID?,
        pageable: Pageable
    ): Page<Transaction>
}
