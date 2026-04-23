package com.budgetbook.budget.repository

import com.budgetbook.budget.domain.MonthlyBudget
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface MonthlyBudgetRepository : JpaRepository<MonthlyBudget, UUID> {

    // ------------------------------------------------------------
    // TEMPLATE + OVERRIDE 조회 (Phase 23 PR-X4)
    // ------------------------------------------------------------

    /** 주어진 월 M 을 커버하는 TEMPLATE row 들 (start_ym <= M AND (end_ym IS NULL OR end_ym >= M)) */
    @Query(
        """
        SELECT b FROM MonthlyBudget b
        LEFT JOIN FETCH b.group
        LEFT JOIN FETCH b.category
        WHERE b.couple.id = :coupleId
          AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.TEMPLATE
          AND b.yearMonth <= :yearMonth
          AND (b.endYearMonth IS NULL OR b.endYearMonth >= :yearMonth)
          AND (b.visibility = com.budgetbook.common.entity.Visibility.SHARED OR b.owner.id = :userId)
        """
    )
    fun findTemplatesCovering(
        @Param("coupleId") coupleId: UUID,
        @Param("yearMonth") yearMonth: String,
        @Param("userId") userId: UUID
    ): List<MonthlyBudget>

    /** 특정 월의 OVERRIDE row 들 */
    @Query(
        """
        SELECT b FROM MonthlyBudget b
        LEFT JOIN FETCH b.group
        LEFT JOIN FETCH b.category
        WHERE b.couple.id = :coupleId
          AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.OVERRIDE
          AND b.yearMonth = :yearMonth
          AND (b.visibility = com.budgetbook.common.entity.Visibility.SHARED OR b.owner.id = :userId)
        """
    )
    fun findOverridesForMonth(
        @Param("coupleId") coupleId: UUID,
        @Param("yearMonth") yearMonth: String,
        @Param("userId") userId: UUID
    ): List<MonthlyBudget>

    /** 특정 (category, group) 키의 OVERRIDE 를 특정 월 이후 전부 조회 (cascade 삭제용) */
    @Query(
        """
        SELECT b FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
          AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.OVERRIDE
          AND b.yearMonth >= :fromYearMonth
          AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
          AND ((:groupId IS NULL AND b.group IS NULL) OR b.group.id = :groupId)
        """
    )
    fun findOverridesFromMonth(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("groupId") groupId: UUID?,
        @Param("fromYearMonth") fromYearMonth: String
    ): List<MonthlyBudget>

    /** 특정 (category, group) 의 TEMPLATE 조회 */
    @Query(
        """
        SELECT b FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
          AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.TEMPLATE
          AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
          AND ((:groupId IS NULL AND b.group IS NULL) OR b.group.id = :groupId)
        """
    )
    fun findTemplateByCategoryGroup(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("groupId") groupId: UUID?
    ): MonthlyBudget?

    /** 특정 (couple, category, group, yearMonth) 의 OVERRIDE 단일 조회 */
    @Query(
        """
        SELECT b FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
          AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.OVERRIDE
          AND b.yearMonth = :yearMonth
          AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
          AND ((:groupId IS NULL AND b.group IS NULL) OR b.group.id = :groupId)
        """
    )
    fun findOverrideForKey(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("groupId") groupId: UUID?,
        @Param("yearMonth") yearMonth: String
    ): MonthlyBudget?

    @Modifying
    @Query(
        """
        DELETE FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
          AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.OVERRIDE
          AND b.yearMonth >= :fromYearMonth
          AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
          AND ((:groupId IS NULL AND b.group IS NULL) OR b.group.id = :groupId)
        """
    )
    fun deleteOverridesFromMonth(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("groupId") groupId: UUID?,
        @Param("fromYearMonth") fromYearMonth: String
    ): Int

    // ------------------------------------------------------------
    // 병합 뷰 (TEMPLATE + OVERRIDE 를 하나의 월 예산 목록으로)
    // ------------------------------------------------------------

    /**
     * 기존 호출부가 사용하는 메서드. 이제 템플릿+오버라이드를 병합하여 반환한다.
     * (category, group) 키마다 OVERRIDE 가 있으면 OVERRIDE, 없으면 TEMPLATE.
     */
    fun findByCoupleIdAndYearMonthAndUserId(
        coupleId: UUID,
        yearMonth: String,
        userId: UUID
    ): List<MonthlyBudget> {
        val templates = findTemplatesCovering(coupleId, yearMonth, userId)
        val overrides = findOverridesForMonth(coupleId, yearMonth, userId)
        val overrideKeys = overrides.map { Pair(it.category?.id, it.group?.id) }.toSet()
        val templatesWithoutOverride = templates.filter {
            Pair(it.category?.id, it.group?.id) !in overrideKeys
        }
        return overrides + templatesWithoutOverride
    }

    /** 병합 뷰 (userId 필터 없음) — 내부용 */
    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): MonthlyBudget?

    /**
     * 특정 (couple, category, group, yearMonth) 의 OVERRIDE 존재 여부.
     * (기존 API 호환 — createBudget 중복 체크는 TEMPLATE/OVERRIDE 별도 처리 필요)
     */
    @Query(
        """
        SELECT CASE WHEN COUNT(b) > 0 THEN true ELSE false END
        FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
          AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.OVERRIDE
          AND b.yearMonth = :yearMonth
          AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
          AND ((:groupId IS NULL AND b.group IS NULL) OR b.group.id = :groupId)
        """
    )
    fun existsByCoupleIdAndCategoryGroupAndYearMonth(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("groupId") groupId: UUID?,
        @Param("yearMonth") yearMonth: String
    ): Boolean

    /** TEMPLATE 존재 여부 — createBudget 에서 TEMPLATE 생성 시 중복 체크 */
    @Query(
        """
        SELECT CASE WHEN COUNT(b) > 0 THEN true ELSE false END
        FROM MonthlyBudget b
        WHERE b.couple.id = :coupleId
          AND b.rowKind = com.budgetbook.budget.domain.BudgetRowKind.TEMPLATE
          AND ((:categoryId IS NULL AND b.category IS NULL) OR b.category.id = :categoryId)
          AND ((:groupId IS NULL AND b.group IS NULL) OR b.group.id = :groupId)
        """
    )
    fun existsTemplateByCategoryGroup(
        @Param("coupleId") coupleId: UUID,
        @Param("categoryId") categoryId: UUID?,
        @Param("groupId") groupId: UUID?
    ): Boolean
}
