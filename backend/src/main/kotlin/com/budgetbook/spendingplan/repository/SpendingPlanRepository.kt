package com.budgetbook.spendingplan.repository

import com.budgetbook.spendingplan.domain.SpendingPlan
import com.budgetbook.spendingplan.domain.SpendingPlanStatus
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.LocalDate
import java.util.UUID

interface SpendingPlanRepository : JpaRepository<SpendingPlan, UUID> {

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

    @Query("""
        SELECT sp.category.id, COALESCE(SUM(sp.amount), 0)
        FROM SpendingPlan sp
        WHERE sp.couple.id = :coupleId
        AND sp.category.id IN :categoryIds
        AND sp.status IN (com.budgetbook.spendingplan.domain.SpendingPlanStatus.WISHLIST, com.budgetbook.spendingplan.domain.SpendingPlanStatus.PLANNED)
        AND (sp.visibility = com.budgetbook.common.entity.Visibility.SHARED OR sp.owner.id = :userId)
        GROUP BY sp.category.id
    """)
    fun sumPlannedAmountByCategoryIds(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryIds") categoryIds: Set<UUID>,
        @Param("userId") userId: UUID
    ): List<Array<Any>>

    @Query("""
        SELECT COALESCE(SUM(sp.amount), 0)
        FROM SpendingPlan sp
        WHERE sp.couple.id = :coupleId
        AND sp.status IN (com.budgetbook.spendingplan.domain.SpendingPlanStatus.WISHLIST, com.budgetbook.spendingplan.domain.SpendingPlanStatus.PLANNED)
        AND (sp.visibility = com.budgetbook.common.entity.Visibility.SHARED OR sp.owner.id = :userId)
    """)
    fun sumTotalPlannedAmount(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
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
        GROUP BY cg.id
    """)
    fun sumPlannedAmountByGroupIds(
        @Param("coupleId") coupleId: UUID,
        @Param("groupIds") groupIds: Set<UUID>,
        @Param("userId") userId: UUID
    ): List<Array<Any>>

    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): SpendingPlan?

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
