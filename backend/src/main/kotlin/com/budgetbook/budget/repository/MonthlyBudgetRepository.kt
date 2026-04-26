package com.budgetbook.budget.repository

import com.budgetbook.budget.domain.MonthlyBudget
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface MonthlyBudgetRepository : JpaRepository<MonthlyBudget, UUID> {

    /**
     * Phase 25 후속 C-2.5 — V57 모델 (TEMPLATE/OVERRIDE) 기반 조회.
     * - OVERRIDE: yearMonth == :yearMonth 인 단일월 행
     * - TEMPLATE: yearMonth <= :yearMonth AND (endYearMonth IS NULL OR endYearMonth >= :yearMonth)
     * 같은 scope (couple, category, group) 의 OVERRIDE 가 같은 월에 있으면 OVERRIDE 우선 —
     * 호출 측 `MonthlyBudgetResolver.resolveForMonth` 에서 dedup.
     */
    @Query("""
        SELECT b FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
        AND (
            (b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.OVERRIDE AND b.yearMonth = :yearMonth)
            OR (
                b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.TEMPLATE
                AND b.yearMonth <= :yearMonth
                AND (b.endYearMonth IS NULL OR b.endYearMonth >= :yearMonth)
            )
        )
    """)
    fun findByCoupleIdAndYearMonth(
        @Param("coupleId") coupleId: UUID,
        @Param("yearMonth") yearMonth: String
    ): List<MonthlyBudget>

    @Query("""
        SELECT b FROM MonthlyBudget b
        LEFT JOIN FETCH b.group
        LEFT JOIN FETCH b.category
        WHERE b.couple.id = :coupleId
        AND (
            (b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.OVERRIDE AND b.yearMonth = :yearMonth)
            OR (
                b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.TEMPLATE
                AND b.yearMonth <= :yearMonth
                AND (b.endYearMonth IS NULL OR b.endYearMonth >= :yearMonth)
            )
        )
        AND (b.visibility = com.budgetbook.common.entity.Visibility.SHARED OR b.owner.id = :userId)
    """)
    fun findByCoupleIdAndYearMonthAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("yearMonth") yearMonth: String,
        @Param("userId") userId: UUID
    ): List<MonthlyBudget>

    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): MonthlyBudget?

    @Query("""
        SELECT CASE WHEN COUNT(b) > 0 THEN true ELSE false END
        FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
        AND b.yearMonth = :yearMonth
        AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
    """)
    fun existsByCoupleIdAndCategoryIdAndYearMonth(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("yearMonth") yearMonth: String
    ): Boolean

    @Query("""
        SELECT CASE WHEN COUNT(b) > 0 THEN true ELSE false END
        FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
        AND b.yearMonth = :yearMonth
        AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
        AND ((:groupId IS NULL AND b.group IS NULL) OR b.group.id = :groupId)
    """)
    fun existsByCoupleIdAndCategoryGroupAndYearMonth(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("groupId") groupId: UUID?,
        @Param("yearMonth") yearMonth: String
    ): Boolean
}
