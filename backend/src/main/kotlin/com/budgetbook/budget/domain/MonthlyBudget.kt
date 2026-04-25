package com.budgetbook.budget.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryGroup
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.common.entity.Visibility
import com.budgetbook.couple.domain.Couple
import com.budgetbook.pocket.domain.MoneyPocket
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.time.LocalDate
import java.util.UUID

@Entity
@Table(name = "monthly_budgets")
class MonthlyBudget(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    var category: Category? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "group_id")
    var group: CategoryGroup? = null,

    @Column(name = "year_month", nullable = false, length = 7)
    val yearMonth: String,

    /**
     * Phase 25 후속 C-1 — 템플릿+오버라이드 모델 (V57 컬럼 매핑 시작).
     * - TEMPLATE: 시작월=yearMonth, 종료월=endYearMonth (null=무기한)
     * - OVERRIDE: 단일월 — yearMonth == endYearMonth
     * 기존 데이터는 V57 백필로 모두 OVERRIDE + endYearMonth=yearMonth.
     */
    @Column(name = "end_year_month", length = 7)
    var endYearMonth: String? = null,

    @Enumerated(EnumType.STRING)
    @Column(name = "row_kind", nullable = false, length = 10)
    var rowKind: BudgetRowKind = BudgetRowKind.OVERRIDE,

    @Column(nullable = false)
    var amount: Long,

    @Column(name = "budget_period", nullable = false, length = 10)
    @Enumerated(EnumType.STRING)
    var budgetPeriod: BudgetPeriod = BudgetPeriod.MONTHLY,

    @Column(name = "weekly_amount")
    var weeklyAmount: Long? = null,

    @Column(name = "period_type", nullable = false, length = 10)
    @Enumerated(EnumType.STRING)
    var periodType: PeriodType = PeriodType.MONTHLY,

    @Column(name = "start_date")
    var startDate: LocalDate? = null,

    @Column(name = "end_date")
    var endDate: LocalDate? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pocket_id")
    var pocket: MoneyPocket? = null,

    @Enumerated(EnumType.STRING)
    @Column(name = "visibility", nullable = false, length = 10)
    var visibility: Visibility = Visibility.SHARED,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id")
    var owner: User? = null
) : BaseTimeEntity()

enum class BudgetPeriod { WEEKLY, MONTHLY }

enum class PeriodType { NONE, DAILY, WEEKLY, MONTHLY }

/**
 * Phase 25 후속 C-1 — V57 모델.
 * - TEMPLATE: 범위 안 모든 월에 effective 예산 제공
 * - OVERRIDE: 단일월 덮어쓰기. 같은 월에 TEMPLATE 이 있어도 OVERRIDE 우선.
 */
enum class BudgetRowKind { TEMPLATE, OVERRIDE }
