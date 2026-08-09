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
               t.category.id, t.category.name, t.category.type, t.category.icon, t.category.color,
               t.category.group.id, t.category.group.name
        FROM Transaction t
        LEFT JOIN t.category.group
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = :type
        AND t.category IS NOT NULL
        AND (
            (:visFilter = 'ALL' AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId))
            OR (:visFilter = 'SHARED' AND t.visibility = com.budgetbook.common.entity.Visibility.SHARED)
            OR (:visFilter = 'PRIVATE' AND t.visibility = com.budgetbook.common.entity.Visibility.PRIVATE AND t.owner.id = :userId)
        )
        GROUP BY t.category.id, t.category.name, t.category.type, t.category.icon, t.category.color,
                 t.category.group.id, t.category.group.name
        ORDER BY SUM(t.amount) DESC
    """)
    fun sumByCategoryForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType,
        @Param("userId") userId: UUID,
        @Param("visFilter") visFilter: String = "ALL"
    ): List<Array<Any?>>

    @Query("""
        SELECT cg.id, SUM(t.amount)
        FROM Transaction t
        JOIN t.category c
        JOIN c.group cg
        WHERE t.couple.id = :coupleId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = :type
        AND cg.id IN :groupIds
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
        GROUP BY cg.id
    """)
    fun sumByCategoryGroupForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("type") type: TransactionType,
        @Param("groupIds") groupIds: Set<UUID>,
        @Param("userId") userId: UUID
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
        SELECT COALESCE(SUM(t.amount), 0), COUNT(t)
        FROM Transaction t
        WHERE t.paymentMethod.id = :paymentMethodId
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
    """)
    fun sumByPaymentMethodAndTransactionDateRange(
        @Param("paymentMethodId") paymentMethodId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID
    ): List<Array<Any?>>

    @Query("""
        SELECT COALESCE(SUM(t.amount), 0), COUNT(t)
        FROM Transaction t
        WHERE t.paymentMethod.id = :paymentMethodId
        AND t.settlementDate BETWEEN :startDate AND :endDate
        AND t.paidAt IS NULL
        AND t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE
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

    // 회차 12 follow-up (2026-05-04) — categoryGroupName 추가 (FE 카테고리 표시 통일).
    // 2026-06-29 — :since (최근 3개월) 필터 추가. COUNT/정렬을 최근 사용 빈도 기준으로 한정.
    @Query("""
        SELECT t.description,
               t.category.id, t.category.name, t.category.icon, t.category.color,
               t.category.group.name,
               t.paymentMethod.id, t.paymentMethod.name,
               COUNT(t)
        FROM Transaction t
        WHERE t.couple.id = :coupleId
        AND t.transactionDate >= :since
        AND (:type IS NULL OR t.type = :type)
        AND LOWER(t.description) LIKE LOWER(CONCAT(:query, '%'))
        GROUP BY t.description,
                 t.category.id, t.category.name, t.category.icon, t.category.color,
                 t.category.group.name,
                 t.paymentMethod.id, t.paymentMethod.name
        ORDER BY t.description, COUNT(t) DESC
    """)
    fun findSuggestionPatterns(
        @Param("coupleId") coupleId: UUID,
        @Param("query") query: String,
        @Param("since") since: LocalDate,
        @Param("type") type: TransactionType?
    ): List<Array<Any?>>

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

    @Query(
        value = """
            SELECT t.transaction_date, t.type, SUM(t.amount) as total, COUNT(*) as cnt
            FROM transactions t
            WHERE t.couple_id = :coupleId
            AND t.transaction_date BETWEEN :startDate AND :endDate
            AND (
                (:visFilter = 'ALL' AND (t.visibility = 'SHARED' OR t.owner_id = CAST(:userId AS UUID)))
                OR (:visFilter = 'SHARED' AND t.visibility = 'SHARED')
                OR (:visFilter = 'PRIVATE' AND t.visibility = 'PRIVATE' AND t.owner_id = CAST(:userId AS UUID))
            )
            GROUP BY t.transaction_date, t.type
            ORDER BY t.transaction_date
        """,
        nativeQuery = true
    )
    fun dailySummaryForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID,
        @Param("visFilter") visFilter: String = "ALL"
    ): List<Array<Any>>

    @Query("""
        SELECT t.paymentMethod.id, t.paymentMethod.name, t.paymentMethod.type, SUM(t.amount), COUNT(t)
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
        GROUP BY t.paymentMethod.id, t.paymentMethod.name, t.paymentMethod.type
        ORDER BY SUM(t.amount) DESC
    """)
    fun sumByPaymentMethodWithTypeForCouple(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID,
        @Param("visFilter") visFilter: String = "ALL"
    ): List<Array<Any>>

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

    /**
     * 결제수단 별 순잔액 (Phase 22 수정):
     * - INCOME:     +amount
     * - EXPENSE:    -amount
     * - ADJUSTMENT: +amount (amount 는 부호 있는 증감값. 양수=증가, 음수=감소)
     *
     * ADJUSTMENT 는 통계에서 제외되지만 잔액 계산에는 반드시 포함된다 (plan §2.5).
     */
    @Query("""
        SELECT t.paymentMethod.id,
            COALESCE(SUM(CASE WHEN t.type = com.budgetbook.transaction.domain.TransactionType.INCOME THEN t.amount ELSE 0L END), 0L) -
            COALESCE(SUM(CASE WHEN t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE THEN t.amount ELSE 0L END), 0L) +
            COALESCE(SUM(CASE WHEN t.type = com.budgetbook.transaction.domain.TransactionType.ADJUSTMENT THEN t.amount ELSE 0L END), 0L)
        FROM Transaction t
        WHERE t.couple.id = :coupleId AND t.paymentMethod IS NOT NULL
        GROUP BY t.paymentMethod.id
    """)
    fun netAmountByPaymentMethodForCouple(@Param("coupleId") coupleId: UUID): List<Array<Any>>

    /**
     * 결제수단 별 순잔액 (asOf 미만 시점 기준):
     * netAmountByPaymentMethodForCouple 와 동일하되 transactionDate < :asOf 조건 추가.
     * asOf 는 상한 배타(exclusive) — asOf 당일 거래는 제외된다.
     */
    @Query("""
        SELECT t.paymentMethod.id,
            COALESCE(SUM(CASE WHEN t.type = com.budgetbook.transaction.domain.TransactionType.INCOME THEN t.amount ELSE 0L END), 0L) -
            COALESCE(SUM(CASE WHEN t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE THEN t.amount ELSE 0L END), 0L) +
            COALESCE(SUM(CASE WHEN t.type = com.budgetbook.transaction.domain.TransactionType.ADJUSTMENT THEN t.amount ELSE 0L END), 0L)
        FROM Transaction t
        WHERE t.couple.id = :coupleId AND t.paymentMethod IS NOT NULL
        AND t.transactionDate < :asOf
        GROUP BY t.paymentMethod.id
    """)
    fun netAmountByPaymentMethodForCoupleUpTo(
        @Param("coupleId") coupleId: UUID,
        @Param("asOf") asOf: LocalDate
    ): List<Array<Any>>

    @Query("""
        SELECT t FROM Transaction t
        LEFT JOIN FETCH t.category
        WHERE t.paymentMethod.id = :paymentMethodId
        AND t.settlementDate BETWEEN :startDate AND :endDate
        AND t.paidAt IS NULL
        AND t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
        ORDER BY t.transactionDate ASC
    """)
    fun findByPaymentMethodAndSettlementDateRange(
        @Param("paymentMethodId") paymentMethodId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID
    ): List<Transaction>

    /**
     * V63: Edit-aware variant of [findByPaymentMethodAndSettlementDateRange].
     * Includes unpaid candidates OR transactions already linked to the settlement being
     * edited, so the edit screen can pre-check them. Pass editingTransferId = null for
     * create flow (then it behaves like the unpaid-only query).
     */
    @Query("""
        SELECT t FROM Transaction t
        LEFT JOIN FETCH t.category
        WHERE t.paymentMethod.id = :paymentMethodId
        AND t.settlementDate BETWEEN :startDate AND :endDate
        AND (t.paidAt IS NULL OR t.settlementTransferId = :editingTransferId)
        AND t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
        ORDER BY t.transactionDate ASC
    """)
    fun findByPaymentMethodAndSettlementDateRangeForEdit(
        @Param("paymentMethodId") paymentMethodId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID,
        @Param("editingTransferId") editingTransferId: UUID?
    ): List<Transaction>

    @Query("""
        SELECT t FROM Transaction t
        LEFT JOIN FETCH t.category
        WHERE t.paymentMethod.id = :paymentMethodId
        AND t.settlementDate IS NULL
        AND t.paidAt IS NULL
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
        ORDER BY t.transactionDate ASC
    """)
    fun findByPaymentMethodAndTransactionDateRangeWithNullSettlement(
        @Param("paymentMethodId") paymentMethodId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID
    ): List<Transaction>

    /**
     * V63: Edit-aware variant of [findByPaymentMethodAndTransactionDateRangeWithNullSettlement].
     * Includes null-settlement-date candidates OR transactions already linked to the
     * settlement being edited. Pass editingTransferId = null for create flow.
     */
    @Query("""
        SELECT t FROM Transaction t
        LEFT JOIN FETCH t.category
        WHERE t.paymentMethod.id = :paymentMethodId
        AND t.settlementDate IS NULL
        AND (t.paidAt IS NULL OR t.settlementTransferId = :editingTransferId)
        AND t.transactionDate BETWEEN :startDate AND :endDate
        AND t.type = com.budgetbook.transaction.domain.TransactionType.EXPENSE
        AND (t.visibility = com.budgetbook.common.entity.Visibility.SHARED OR t.owner.id = :userId)
        ORDER BY t.transactionDate ASC
    """)
    fun findByPaymentMethodAndTransactionDateRangeWithNullSettlementForEdit(
        @Param("paymentMethodId") paymentMethodId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID,
        @Param("editingTransferId") editingTransferId: UUID?
    ): List<Transaction>

    @Modifying
    @Query("""
        UPDATE Transaction t
        SET t.paidAt = :paidAt
        WHERE t.id IN :ids
        AND t.paidAt IS NULL
    """)
    fun markAsPaid(
        @Param("ids") ids: List<UUID>,
        @Param("paidAt") paidAt: LocalDate
    ): Int

    /**
     * V63: Mark transactions as paid AND record which settlement transfer did it.
     * Only affects currently-unpaid rows (paidAt IS NULL) to avoid hijacking transactions
     * already settled by another transfer.
     */
    @Modifying
    @Query("""
        UPDATE Transaction t
        SET t.paidAt = :paidAt, t.settlementTransferId = :transferId
        WHERE t.id IN :ids
        AND t.paidAt IS NULL
    """)
    fun markAsPaidForSettlement(
        @Param("ids") ids: List<UUID>,
        @Param("paidAt") paidAt: LocalDate,
        @Param("transferId") transferId: UUID
    ): Int

    /**
     * V63: Restore all transactions linked to a settlement transfer back to unpaid.
     * Used before re-marking (update) and before deleting a settlement transfer.
     */
    @Modifying
    @Query("""
        UPDATE Transaction t
        SET t.paidAt = NULL, t.settlementTransferId = NULL
        WHERE t.settlementTransferId = :transferId
    """)
    fun unmarkBySettlementTransfer(
        @Param("transferId") transferId: UUID
    ): Int

    /**
     * 이체 → 거래 역변환 가드 (2026-08-09).
     *
     * 결제 링크가 남은 이체를 지우면 `transactions.settlement_transfer_id` 가 조용히
     * NULL 로 끊겨(V63 `ON DELETE SET NULL`) 그 달 미결제 합계가 어긋난다.
     * `kind == CARD_SETTLEMENT` 검사와 겹치지만, 과거·자동 생성 데이터를 위한 두 번째 방어선.
     */
    fun existsBySettlementTransferId(settlementTransferId: UUID): Boolean

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
