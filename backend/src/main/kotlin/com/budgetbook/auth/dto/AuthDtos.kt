package com.budgetbook.auth.dto

import com.budgetbook.auth.domain.User
import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
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

data class UpdateProfileRequest(
    @field:Size(min = 1, max = 50, message = "닉네임은 1~50자 이내로 입력해주세요")
    val nickname: String? = null,
    val profileImageUrl: String? = null,
    val clearProfileImage: Boolean = false,
    @field:Email(message = "올바른 이메일 형식이 아닙니다")
    val email: String? = null
)

data class UserResponse(
    val id: UUID,
    val email: String,
    val nickname: String,
    val profileImageUrl: String?,
    val provider: String,
    val role: String,
    val coupleId: UUID?,
    val createdAt: Instant
) {
    companion object {
        fun from(user: User, coupleId: UUID? = null): UserResponse = UserResponse(
            id = user.id,
            email = user.email,
            nickname = user.nickname,
            profileImageUrl = user.profileImageUrl,
            provider = user.provider.name,
            role = user.role.name,
            coupleId = coupleId,
            createdAt = user.createdAt
        )
    }
}
