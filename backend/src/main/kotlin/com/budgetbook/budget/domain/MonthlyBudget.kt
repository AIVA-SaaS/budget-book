package com.budgetbook.budget.domain

import com.budgetbook.category.domain.Category
import com.budgetbook.common.entity.BaseTimeEntity
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
    val category: Category? = null,

    @Column(name = "year_month", nullable = false, length = 7)
    val yearMonth: String,

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
    var pocket: MoneyPocket? = null
) : BaseTimeEntity()

enum class BudgetPeriod { WEEKLY, MONTHLY }

enum class PeriodType { NONE, DAILY, WEEKLY, MONTHLY }
