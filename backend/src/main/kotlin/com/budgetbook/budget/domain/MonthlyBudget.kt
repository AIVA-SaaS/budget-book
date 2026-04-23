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
     * 범위 종료월 (YYYY-MM). null = 무기한.
     * - TEMPLATE: start=yearMonth, end=endYearMonth (null=무기한)
     * - OVERRIDE: start=end=yearMonth (단일월)
     */
    @Column(name = "end_year_month", length = 7)
    var endYearMonth: String? = null,

    /**
     * row 분류.
     * - TEMPLATE: (couple, category, group) 당 1건. 범위 기본 예산.
     * - OVERRIDE: 특정 month 한정 덮어쓰기.
     */
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

enum class BudgetRowKind { TEMPLATE, OVERRIDE }
