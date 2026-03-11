package com.budgetbook.budget.domain

import com.budgetbook.category.domain.CategoryGroup
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
import java.time.LocalDate
import java.util.UUID

@Entity
@Table(name = "weekly_budget_snapshots")
class WeeklyBudgetSnapshot(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "group_id")
    val group: CategoryGroup? = null,

    @Column(name = "year_month", nullable = false, length = 7)
    val yearMonth: String,

    @Column(name = "week_number", nullable = false)
    val weekNumber: Int,

    @Column(name = "week_start", nullable = false)
    val weekStart: LocalDate,

    @Column(name = "week_end", nullable = false)
    val weekEnd: LocalDate,

    @Column(name = "budget_amount", nullable = false)
    var budgetAmount: Long = 0,

    @Column(name = "spent_amount", nullable = false)
    var spentAmount: Long = 0,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    var status: WeeklyStatus = WeeklyStatus.IN_PROGRESS
) : BaseTimeEntity()

enum class WeeklyStatus { UNDER, OVER, IN_PROGRESS }
