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

    /**
     * Phase 25 후속 C-2.6 — 같은 scope (couple, category, group) 의 활성 TEMPLATE 1건 조회.
     * V57 partial unique 보장으로 결과는 0~1건. categoryId/groupId 가 null 이면 미할당 scope.
     * "활성" = `yearMonth <= :targetYearMonth AND (endYearMonth IS NULL OR endYearMonth >= :targetYearMonth)`.
     * `:excludeId` 는 자기 자신 제외용 (currentRow 가 이미 TEMPLATE 인 케이스 등).
     */
    @Query("""
        SELECT b FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
        AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.TEMPLATE
        AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
        AND ((:groupId IS NULL AND b.group IS NULL) OR b.group.id = :groupId)
        AND b.yearMonth <= :targetYearMonth
        AND (b.endYearMonth IS NULL OR b.endYearMonth >= :targetYearMonth)
        AND (:excludeId IS NULL OR b.id <> :excludeId)
    """)
    fun findActiveTemplateInScope(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("groupId") groupId: UUID?,
        @Param("targetYearMonth") targetYearMonth: String,
        @Param("excludeId") excludeId: UUID?
    ): MonthlyBudget?

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

    /**
     * Phase 25 후속 E-3 — OVERRIDE 행 충돌 전용 검사.
     * V57 partial unique `uk_monthly_budgets_override_month` 가 OVERRIDE-only 이므로,
     * split semantic 에서 OVERRIDE 신규 가능 여부 체크 시 TEMPLATE 행을 제외해야 한다.
     * 기존 `existsByCoupleIdAndCategoryGroupAndYearMonth` 는 rowKind 무관하게 매칭하여
     * TEMPLATE 자체를 false-positive 로 잡는 버그가 있었다.
     */
    @Query("""
        SELECT CASE WHEN COUNT(b) > 0 THEN true ELSE false END
        FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
        AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.OVERRIDE
        AND b.yearMonth = :yearMonth
        AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
        AND ((:groupId IS NULL AND b.group IS NULL) OR b.group.id = :groupId)
    """)
    fun existsOverrideByCoupleIdAndCategoryGroupAndYearMonth(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("groupId") groupId: UUID?,
        @Param("yearMonth") yearMonth: String
    ): Boolean
}
