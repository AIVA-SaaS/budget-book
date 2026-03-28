package com.budgetbook.spendingplan.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.category.domain.Category
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.common.entity.Visibility
import com.budgetbook.couple.domain.Couple
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.transaction.domain.Transaction
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
@Table(name = "spending_plans")
class SpendingPlan(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    val author: User,

    @Column(nullable = false, length = 100)
    var name: String,

    @Column(nullable = false)
    var amount: Long,

    @Column(name = "target_date", nullable = false)
    var targetDate: LocalDate,

    var memo: String? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    var category: Category? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "payment_method_id")
    var paymentMethod: PaymentMethod? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "budget_id")
    var budget: MonthlyBudget? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "linked_transaction_id")
    var linkedTransaction: Transaction? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    var status: SpendingPlanStatus = SpendingPlanStatus.PLANNED,

    @Column(name = "actual_amount")
    var actualAmount: Long? = null,

    @Column(name = "completed_date")
    var completedDate: LocalDate? = null,

    @Column(name = "is_recurring", nullable = false)
    var isRecurring: Boolean = false,

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    var frequency: SpendingPlanFrequency? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recurring_source_id")
    var recurringSource: SpendingPlan? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    var visibility: Visibility = Visibility.SHARED,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id")
    var owner: User? = null
) : BaseTimeEntity()
