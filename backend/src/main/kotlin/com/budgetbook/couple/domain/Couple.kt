package com.budgetbook.couple.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.common.entity.BaseTimeEntity
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
@Table(name = "couples")
class Couple(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user1_id", nullable = false)
    val user1: User,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user2_id")
    var user2: User? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    var status: CoupleStatus = CoupleStatus.PENDING
) : BaseTimeEntity()

enum class CoupleStatus { PENDING, ACTIVE, DISSOLVED }
