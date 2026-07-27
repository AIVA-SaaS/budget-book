package com.budgetbook.spendingplan.repository

import com.budgetbook.spendingplan.domain.SpendingPlan
import com.budgetbook.spendingplan.domain.SpendingPlanStatus
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.LocalDate
import java.util.UUID

interface SpendingPlanRepository : JpaRepository<SpendingPlan, UUID> {

    /**
     * 이 거래에 연결된 계획이 있는지. 거래→이체 변환 가드용
     * (`linked_transaction_id` FK 에 ON DELETE 가 없어 그냥 지우면 무결성 오류).
     */
    fun existsByLinkedTransactionId(transactionId: UUID): Boolean

    @Query("""
        SELECT sp FROM SpendingPlan sp
        LEFT JOIN FETCH sp.category c
        LEFT JOIN FETCH c.group
        LEFT JOIN FETCH sp.paymentMethod
        LEFT JOIN FETCH sp.linkedTransaction
        LEFT JOIN FETCH sp.author
        WHERE sp.couple.id = :coupleId
        AND sp.targetDate BETWEEN :startDate AND :endDate
        AND (sp.visibility = com.budgetbook.common.entity.Visibility.SHARED OR sp.owner.id = :userId)
        ORDER BY sp.targetDate ASC
    """)
    fun findByCoupleAndDateRange(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("userId") userId: UUID
    ): List<SpendingPlan>

    @Query("""
        SELECT sp FROM SpendingPlan sp
        LEFT JOIN FETCH sp.category c
        LEFT JOIN FETCH c.group
        LEFT JOIN FETCH sp.paymentMethod
        LEFT JOIN FETCH sp.linkedTransaction
        LEFT JOIN FETCH sp.author
        WHERE sp.couple.id = :coupleId
        AND sp.targetDate BETWEEN :startDate AND :endDate
        AND sp.status = :status
        AND (sp.visibility = com.budgetbook.common.entity.Visibility.SHARED OR sp.owner.id = :userId)
        ORDER BY sp.targetDate ASC
    """)
    fun findByCoupleAndDateRangeAndStatus(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("status") status: SpendingPlanStatus,
        @Param("userId") userId: UUID
    ): List<SpendingPlan>

    @Query("""
        SELECT sp FROM SpendingPlan sp
        LEFT JOIN FETCH sp.category
        WHERE sp.couple.id = :coupleId
        AND sp.status = com.budgetbook.spendingplan.domain.SpendingPlanStatus.PLANNED
        AND sp.category.id = :categoryId
        AND sp.targetDate BETWEEN :startDate AND :endDate
    """)
    fun findMatchingPlans(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<SpendingPlan>

    // 회차 12 P4 (2026-05-03) — month 필터 추가.
    // 이전 버그: target month 무관하게 모든 spending plan 합산 → budget UI 에서
    // 입력 안 한 달에도 plannedAmount 0 아닌 값 표시 (도메인 분리 위반).
    // targetDate IS NULL (날짜 미지정 plan) 은 모든 월에 포함.
    @Query("""
        SELECT sp.category.id, COALESCE(SUM(sp.amount), 0)
        FROM SpendingPlan sp
        WHERE sp.couple.id = :coupleId
        AND sp.category.id IN :categoryIds
        AND sp.status IN (com.budgetbook.spendingplan.domain.SpendingPlanStatus.WISHLIST, com.budgetbook.spendingplan.domain.SpendingPlanStatus.PLANNED)
        AND (sp.visibility = com.budgetbook.common.entity.Visibility.SHARED OR sp.owner.id = :userId)
        AND (sp.targetDate IS NULL OR sp.targetDate BETWEEN :startDate AND :endDate)
        GROUP BY sp.category.id
    """)
    fun sumPlannedAmountByCategoryIds(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryIds") categoryIds: Set<UUID>,
        @Param("userId") userId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>

    @Query("""
        SELECT COALESCE(SUM(sp.amount), 0)
        FROM SpendingPlan sp
        WHERE sp.couple.id = :coupleId
        AND sp.status IN (com.budgetbook.spendingplan.domain.SpendingPlanStatus.WISHLIST, com.budgetbook.spendingplan.domain.SpendingPlanStatus.PLANNED)
        AND (sp.visibility = com.budgetbook.common.entity.Visibility.SHARED OR sp.owner.id = :userId)
        AND (sp.targetDate IS NULL OR sp.targetDate BETWEEN :startDate AND :endDate)
    """)
    fun sumTotalPlannedAmount(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): Long

    @Query("""
        SELECT cg.id, COALESCE(SUM(sp.amount), 0)
        FROM SpendingPlan sp
        JOIN sp.category c
        JOIN c.group cg
        WHERE sp.couple.id = :coupleId
        AND cg.id IN :groupIds
        AND sp.status IN (com.budgetbook.spendingplan.domain.SpendingPlanStatus.WISHLIST, com.budgetbook.spendingplan.domain.SpendingPlanStatus.PLANNED)
        AND (sp.visibility = com.budgetbook.common.entity.Visibility.SHARED OR sp.owner.id = :userId)
        AND (sp.targetDate IS NULL OR sp.targetDate BETWEEN :startDate AND :endDate)
        GROUP BY cg.id
    """)
    fun sumPlannedAmountByGroupIds(
        @Param("coupleId") coupleId: UUID,
        @Param("groupIds") groupIds: Set<UUID>,
        @Param("userId") userId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>

    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): SpendingPlan?

    @Query("""
        SELECT sp.budget.id, COALESCE(SUM(sp.amount), 0)
        FROM SpendingPlan sp
        WHERE sp.couple.id = :coupleId
        AND sp.status = com.budgetbook.spendingplan.domain.SpendingPlanStatus.PLANNED
        AND sp.budget IS NOT NULL
        AND sp.targetDate BETWEEN :startDate AND :endDate
        GROUP BY sp.budget.id
    """)
    fun sumPlannedAmountByBudget(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>

    @Query("""
        SELECT sp FROM SpendingPlan sp
        LEFT JOIN FETCH sp.category c
        LEFT JOIN FETCH c.group
        LEFT JOIN FETCH sp.author
        WHERE sp.couple.id = :coupleId
        AND sp.status = com.budgetbook.spendingplan.domain.SpendingPlanStatus.WISHLIST
        AND (sp.visibility = com.budgetbook.common.entity.Visibility.SHARED OR sp.owner.id = :userId)
        ORDER BY CASE sp.priority
            WHEN com.budgetbook.spendingplan.domain.SpendingPlanPriority.HIGH THEN 0
            WHEN com.budgetbook.spendingplan.domain.SpendingPlanPriority.MEDIUM THEN 1
            WHEN com.budgetbook.spendingplan.domain.SpendingPlanPriority.LOW THEN 2
            END, sp.createdAt DESC
    """)
    fun findWishlistByCoupleId(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<SpendingPlan>
}
