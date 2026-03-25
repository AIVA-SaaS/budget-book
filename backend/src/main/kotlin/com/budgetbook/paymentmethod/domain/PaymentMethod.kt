package com.budgetbook.paymentmethod.domain

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
import java.util.UUID

@Entity
@Table(name = "payment_methods")
class PaymentMethod(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @Column(nullable = false, length = 100)
    var name: String,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    val type: PaymentMethodType,

    @Column(name = "settlement_day")
    var settlementDay: Int? = null,

    @Column(name = "closing_day")
    var closingDay: Int? = null,

    @Column(name = "is_active", nullable = false)
    var isActive: Boolean = true,

    @Column(name = "is_default", nullable = false)
    val isDefault: Boolean = false,

    @Column(name = "display_order", nullable = false)
    var displayOrder: Int = 0,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "linked_bank_id")
    var linkedBank: PaymentMethod? = null
) : BaseTimeEntity()

enum class PaymentMethodType { CASH, DEBIT, CREDIT, BANK }
