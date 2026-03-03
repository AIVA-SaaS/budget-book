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
    val createdAt: Instant
)

data class UserSummary(
    val id: UUID,
    val nickname: String,
    val profileImageUrl: String?
)
