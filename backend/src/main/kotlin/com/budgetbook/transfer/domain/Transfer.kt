package com.budgetbook.transfer.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.couple.domain.Couple
import com.budgetbook.paymentmethod.domain.PaymentMethod
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.time.LocalDate
import java.util.UUID

@Entity
@Table(name = "transfers")
class Transfer(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    val author: User,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "source_payment_method_id", nullable = false)
    var sourcePaymentMethod: PaymentMethod,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "destination_payment_method_id", nullable = false)
    var destinationPaymentMethod: PaymentMethod,

    @Column(nullable = false)
    var amount: Long,

    @Column(length = 255)
    var description: String? = null,

    var memo: String? = null,

    @Column(name = "transfer_date", nullable = false)
    var transferDate: LocalDate,

    @Column(name = "auto_settlement_key", length = 100, unique = true)
    val autoSettlementKey: String? = null
) : BaseTimeEntity()
