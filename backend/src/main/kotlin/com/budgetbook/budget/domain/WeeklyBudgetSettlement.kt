package com.budgetbook.budget.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.category.domain.Category
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.couple.domain.Couple
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

@Entity
@Table(name = "weekly_budget_settlements")
class WeeklyBudgetSettlement(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "budget_id", nullable = false)
    val budget: MonthlyBudget,

    @Column(name = "year_month", nullable = false, length = 7)
    val yearMonth: String,

    @Column(name = "week_number", nullable = false)
    val weekNumber: Int,

    @Column(name = "week_start", nullable = false)
    val weekStart: LocalDate,

    @Column(name = "week_end", nullable = false)
    val weekEnd: LocalDate,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    val category: Category? = null,

    @Column(name = "settled_amount", nullable = false)
    var settledAmount: Long = 0,

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    var status: SettlementStatus = SettlementStatus.PENDING,

    @Column(name = "settled_at")
    var settledAt: Instant? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "settled_by")
    var settledBy: User? = null
) : BaseTimeEntity()

enum class SettlementStatus {
    PENDING, SETTLED
}
