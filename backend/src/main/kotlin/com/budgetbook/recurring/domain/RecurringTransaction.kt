package com.budgetbook.recurring.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.category.domain.Category
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.couple.domain.Couple
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.transaction.domain.TransactionType
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
@Table(name = "recurring_transactions")
class RecurringTransaction(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    val author: User,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    var category: Category? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "payment_method_id")
    var paymentMethod: PaymentMethod? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    val type: TransactionType,

    @Column(nullable = false)
    var amount: Long,

    @Column(nullable = false, length = 255)
    var description: String,

    var memo: String? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    val frequency: Frequency,

    @Column(name = "day_of_month")
    var dayOfMonth: Int? = null,

    @Column(name = "day_of_week")
    var dayOfWeek: Int? = null,

    @Column(name = "next_run_date", nullable = false)
    var nextRunDate: LocalDate,

    @Column(name = "last_run_date")
    var lastRunDate: LocalDate? = null,

    @Column(name = "is_active", nullable = false)
    var isActive: Boolean = true
) : BaseTimeEntity()

enum class Frequency { DAILY, WEEKLY, MONTHLY, YEARLY }
