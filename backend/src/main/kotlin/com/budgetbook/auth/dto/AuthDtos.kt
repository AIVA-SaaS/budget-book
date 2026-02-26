package com.budgetbook.auth.dto

import com.budgetbook.auth.domain.User
import jakarta.validation.constraints.NotBlank
import java.time.Instant
import java.util.UUID

data class TokenResponse(
    val accessToken: String,
    val refreshToken: String,
    val expiresIn: Long
)

data class RefreshTokenRequest(
    @field:NotBlank(message = "Refresh token is required")
    val refreshToken: String
)

data class LogoutRequest(
    @field:NotBlank(message = "Refresh token is required")
    val refreshToken: String
)

data class UserResponse(
    val id: UUID,
    val email: String,
    val nickname: String,
    val profileImageUrl: String?,
    val provider: String,
    val role: String,
    val createdAt: Instant
) {
    companion object {
        fun from(user: User): UserResponse = UserResponse(
            id = user.id,
            email = user.email,
            nickname = user.nickname,
            profileImageUrl = user.profileImageUrl,
            provider = user.provider.name,
            role = user.role.name,
            createdAt = user.createdAt
        )
    }
}
