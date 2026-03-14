package com.budgetbook.pocket.domain

import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.couple.domain.Couple
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.math.BigDecimal
import java.util.UUID

@Entity
@Table(name = "distribution_ratios")
class DistributionRatio(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pocket_id", nullable = false)
    val pocket: MoneyPocket,

    @Column(nullable = false, precision = 5, scale = 2)
    var ratio: BigDecimal
) : BaseTimeEntity()
