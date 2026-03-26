package com.budgetbook.couple.dto

import java.time.Instant
import java.util.UUID

data class InvitationResponse(
    val code: String,
    val expiresAt: Instant
)

data class CoupleResponse(
    val id: UUID,
    val partner: UserSummary,
    val status: String,
    val createdAt: Instant,
    val dissolvedAt: Instant? = null
)

data class UserSummary(
    val id: UUID,
    val nickname: String,
    val profileImageUrl: String?
)

data class InvitationStatusResponse(
    val code: String,
    val expiresAt: Instant,
    val status: String
)
