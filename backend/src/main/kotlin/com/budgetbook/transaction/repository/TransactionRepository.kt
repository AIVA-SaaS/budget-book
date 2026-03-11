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

    @Query("""
        SELECT t.type, SUM(t.amount), COUNT(t)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        GROUP BY t.type
    """)
    fun sumByTypeForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>

    @Query("""
        SELECT SUM(t.amount), COUNT(t),
               t.category.id, t.category.name, t.category.type, t.category.icon, t.category.color
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = :type
        AND t.category IS NOT NULL
        GROUP BY t.category.id, t.category.name, t.category.type, t.category.icon, t.category.color
        ORDER BY SUM(t.amount) DESC
    """)
    fun sumByCategoryForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType
    ): List<Array<Any>>

    @Query(
        value = """
            SELECT TO_CHAR(t.transaction_date, 'YYYY-MM') as ym, t.type, SUM(t.amount) as total
            FROM transactions t
            WHERE t.couple_id = :coupleId
            AND t.transaction_date BETWEEN :startDate AND :endDate
            GROUP BY ym, t.type
            ORDER BY ym
        """,
        nativeQuery = true
    )
    fun monthlyTrendForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>

    @Query("""
        SELECT SUM(t.amount), COUNT(t)
        FROM Transaction t
        WHERE t.paymentMethod.id = :paymentMethodId
        AND t.settlementDate BETWEEN :startDate AND :endDate
    """)
    fun sumByPaymentMethodAndSettlementDateRange(
        @Param("paymentMethodId") paymentMethodId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any?>>

    @Query("""
        SELECT t.paymentMethod.id, SUM(t.amount)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.paymentMethod.type = com.budgetbook.paymentmethod.domain.PaymentMethodType.CREDIT
        AND t.settlementDate BETWEEN :startDate AND :endDate
        GROUP BY t.paymentMethod.id
    """)
    fun sumBySettlementDateGroupedByPaymentMethod(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>
}
