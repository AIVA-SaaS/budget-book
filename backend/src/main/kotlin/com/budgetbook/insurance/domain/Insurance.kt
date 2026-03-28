package com.budgetbook.insurance.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.category.domain.Category
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.common.entity.Visibility
import com.budgetbook.couple.domain.Couple
import com.budgetbook.paymentmethod.domain.PaymentMethod
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
@Table(name = "insurances")
class Insurance(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @Column(nullable = false, length = 100)
    var name: String,

    @Column(length = 100)
    var insurer: String? = null,

    @Enumerated(EnumType.STRING)
    @Column(name = "insurance_type", nullable = false, length = 30)
    var insuranceType: InsuranceType,

    @Column(name = "premium_amount", nullable = false)
    var premiumAmount: Long,

    @Column(name = "payment_day")
    var paymentDay: Int? = null,

    @Enumerated(EnumType.STRING)
    @Column(name = "payment_cycle", nullable = false, length = 20)
    var paymentCycle: PaymentCycle = PaymentCycle.MONTHLY,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "payment_method_id")
    var paymentMethod: PaymentMethod? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    var category: Category? = null,

    @Column(name = "start_date")
    var startDate: LocalDate? = null,

    @Column(name = "end_date")
    var endDate: LocalDate? = null,

    var memo: String? = null,

    @Column(name = "is_active", nullable = false)
    var isActive: Boolean = true,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    var visibility: Visibility = Visibility.SHARED,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id")
    var owner: User? = null
) : BaseTimeEntity()
