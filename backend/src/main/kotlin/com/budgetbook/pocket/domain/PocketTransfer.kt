package com.budgetbook.pocket.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.couple.domain.Couple
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
@Table(name = "pocket_transfers")
class PocketTransfer(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "from_pocket_id", nullable = false)
    val fromPocket: MoneyPocket,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "to_pocket_id", nullable = false)
    val toPocket: MoneyPocket,

    @Column(nullable = false)
    val amount: Long,

    @Column(length = 255)
    var description: String? = null,

    @Column(name = "transfer_date", nullable = false)
    val transferDate: LocalDate,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    val author: User
) : BaseTimeEntity()
