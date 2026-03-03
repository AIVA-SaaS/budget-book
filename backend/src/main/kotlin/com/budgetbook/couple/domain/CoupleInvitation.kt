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
import java.time.Instant
import java.util.UUID

@Entity
@Table(name = "couple_invitations")
class CoupleInvitation(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "inviter_id", nullable = false)
    val inviter: User,

    @Column(name = "invitation_code", nullable = false, unique = true, length = 8)
    val invitationCode: String,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    var status: InvitationStatus = InvitationStatus.PENDING,

    @Column(name = "expires_at", nullable = false)
    val expiresAt: Instant
) : BaseTimeEntity()

enum class InvitationStatus { PENDING, ACCEPTED, EXPIRED, CANCELLED }
