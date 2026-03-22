package com.budgetbook.transaction.repository

import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.JpaSpecificationExecutor
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.LocalDate
import java.util.UUID

interface TransactionRepository : JpaRepository<Transaction, UUID>, JpaSpecificationExecutor<Transaction> {

    @Query("""
        SELECT t FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND (:type IS NULL OR t.type = :type)
        AND (:categoryId IS NULL OR t.category.id = :categoryId)
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
        ORDER BY t.transactionDate DESC, t.createdAt DESC
    """)
    fun findByCoupleIdAndFilters(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType?,
        @Param("categoryId") categoryId: UUID?,
        @Param("userId") userId: UUID,
        pageable: Pageable
    ): Page<Transaction>

    @Query("""
        SELECT t.type, SUM(t.amount), COUNT(t)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND (
            (:visFilter = 'ALL' AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId))
            OR (:visFilter = 'SHARED' AND t.visibility = com.budgetbook.common.entity.Visibility.SHARED)
            OR (:visFilter = 'PRIVATE' AND t.visibility = com.budgetbook.common.entity.Visibility.PRIVATE AND t.owner.id = :userId)
        )
        GROUP BY t.type
    """)
    fun sumByTypeForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID,
        @Param("visFilter") visFilter: String = "ALL"
    ): List<Array<Any>>

    @Query("""
        SELECT SUM(t.amount), COUNT(t),
               t.category.id, t.category.name, t.category.type, t.category.icon, t.category.color
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = :type
        AND t.category IS NOT NULL
        AND (
            (:visFilter = 'ALL' AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId))
            OR (:visFilter = 'SHARED' AND t.visibility = com.budgetbook.common.entity.Visibility.SHARED)
            OR (:visFilter = 'PRIVATE' AND t.visibility = com.budgetbook.common.entity.Visibility.PRIVATE AND t.owner.id = :userId)
        )
        GROUP BY t.category.id, t.category.name, t.category.type, t.category.icon, t.category.color
        ORDER BY SUM(t.amount) DESC
    """)
    fun sumByCategoryForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType,
        @Param("userId") userId: UUID,
        @Param("visFilter") visFilter: String = "ALL"
    ): List<Array<Any>>

    @Query(
        value = """
            SELECT TO_CHAR(t.transaction_date, 'YYYY-MM') as ym, t.type, SUM(t.amount) as total
            FROM transactions t
            WHERE t.couple_id = :coupleId
            AND t.transaction_date BETWEEN :startDate AND :endDate
            AND (
                (:visFilter = 'ALL' AND (t.visibility = 'SHARED' OR t.owner_id = CAST(:userId AS UUID)))
                OR (:visFilter = 'SHARED' AND t.visibility = 'SHARED')
                OR (:visFilter = 'PRIVATE' AND t.visibility = 'PRIVATE' AND t.owner_id = CAST(:userId AS UUID))
            )
            GROUP BY ym, t.type
            ORDER BY ym
        """,
        nativeQuery = true
    )
    fun monthlyTrendForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID,
        @Param("visFilter") visFilter: String = "ALL"
    ): List<Array<Any>>

    @Query("""
        SELECT COALESCE(SUM(t.amount), 0)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = :type
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
    """)
    fun sumAmountByCoupleIdAndDateRange(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType,
        @Param("userId") userId: UUID
    ): Long

    @Query("""
        SELECT COALESCE(SUM(t.amount), 0)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = :type
        AND t.category.id IN :categoryIds
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
    """)
    fun sumAmountByCoupleIdAndDateRangeAndCategories(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType,
        @Param("categoryIds") categoryIds: Set<UUID>,
        @Param("userId") userId: UUID
    ): Long

    @Query("""
        SELECT SUM(t.amount), COUNT(t)
        FROM Transaction t
        WHERE t.paymentMethod.id = :paymentMethodId
        AND t.settlementDate BETWEEN :startDate AND :endDate
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
    """)
    fun sumByPaymentMethodAndSettlementDateRange(
        @Param("paymentMethodId") paymentMethodId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID
    ): List<Array<Any?>>

    @Query("""
        SELECT t.paymentMethod.id, SUM(t.amount)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.paymentMethod.type = com.budgetbook.paymentmethod.domain.PaymentMethodType.CREDIT
        AND t.settlementDate BETWEEN :startDate AND :endDate
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
        GROUP BY t.paymentMethod.id
    """)
    fun sumBySettlementDateGroupedByPaymentMethod(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID
    ): List<Array<Any>>

    @Query("""
        SELECT COALESCE(SUM(t.amount), 0)
        FROM Transaction t
        WHERE t.pocket.id = :pocketId
        AND t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
    """)
    fun sumExpenseByPocketId(
        @Param("pocketId") pocketId: UUID,
        @Param("userId") userId: UUID
    ): Long

    @Query("""
        SELECT t.pocket.id, COALESCE(SUM(t.amount), 0)
        FROM Transaction t
        WHERE t.pocket.id IN :pocketIds
        AND t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
        GROUP BY t.pocket.id
    """)
    fun sumExpenseByPocketIdIn(
        @Param("pocketIds") pocketIds: Set<UUID>,
        @Param("userId") userId: UUID
    ): List<Array<Any>>

    @Query("""
        SELECT t.paymentMethod.id, t.paymentMethod.name, SUM(t.amount), COUNT(t)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE
        AND t.paymentMethod IS NOT NULL
        AND (
            (:visFilter = 'ALL' AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId))
            OR (:visFilter = 'SHARED' AND t.visibility = com.budgetbook.common.entity.Visibility.SHARED)
            OR (:visFilter = 'PRIVATE' AND t.visibility = com.budgetbook.common.entity.Visibility.PRIVATE AND t.owner.id = :userId)
        )
        GROUP BY t.paymentMethod.id, t.paymentMethod.name
        ORDER BY SUM(t.amount) DESC
    """)
    fun sumByPaymentMethodForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID,
        @Param("visFilter") visFilter: String = "ALL"
    ): List<Array<Any>>

    @Query("""
        SELECT COALESCE(SUM(t.amount), 0)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = :type
        AND t.category.group.id = :groupId
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
    """)
    fun sumAmountByGroupAndDateRange(
        @Param("coupleId") coupleId: UUID,
        @Param("groupId") groupId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType,
        @Param("userId") userId: UUID
    ): Long

    @Query("SELECT COUNT(DISTINCT t.author.id) FROM Transaction t WHERE t.createdAt >= :since")
    fun countDistinctAuthorsSince(@Param("since") since: java.time.Instant): Long

    @Query("SELECT COUNT(t) FROM Transaction t WHERE t.couple.id = :coupleId")
    fun countByCoupleId(@Param("coupleId") coupleId: UUID): Long

    @Query(
        value = """
            SELECT t.description
            FROM transactions t
            WHERE t.couple_id = :coupleId
            AND LOWER(t.description) LIKE LOWER(CONCAT('%', :query, '%'))
            AND (t.visibility = 'SHARED' OR t.owner_id = CAST(:userId AS UUID))
            GROUP BY t.description
            ORDER BY MAX(t.created_at) DESC
            LIMIT :limit
        """,
        nativeQuery = true
    )
    fun findDistinctDescriptionsByQuery(
        @Param("coupleId") coupleId: UUID,
        @Param("query") query: String,
        @Param("userId") userId: UUID,
        @Param("limit") limit: Int
    ): List<String>

    @Query("""
        SELECT t.category.id, COALESCE(SUM(t.amount), 0)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = :type
        AND t.category.id IN :categoryIds
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
        GROUP BY t.category.id
    """)
    fun sumAmountGroupedByCategoryId(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType,
        @Param("categoryIds") categoryIds: Set<UUID>,
        @Param("userId") userId: UUID
    ): List<Array<Any>>

    @Modifying
    @Query(
        value = """
            UPDATE transactions
            SET visibility = :visibility, owner_id = CAST(:ownerId AS UUID)
            WHERE category_id = :categoryId
        """,
        nativeQuery = true
    )
    fun updateVisibilityByCategoryId(
        @Param("categoryId") categoryId: UUID,
        @Param("visibility") visibility: String,
        @Param("ownerId") ownerId: UUID?
    )
}
