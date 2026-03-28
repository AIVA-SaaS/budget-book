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

    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): SpendingPlan?
}
