package com.budgetbook.auth.service

import com.budgetbook.auth.domain.RefreshToken
import com.budgetbook.auth.dto.LogoutRequest
import com.budgetbook.auth.dto.RefreshTokenRequest
import com.budgetbook.auth.dto.TokenResponse
import com.budgetbook.auth.dto.UserResponse
import com.budgetbook.auth.repository.RefreshTokenRepository
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.exception.UnauthorizedException
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant
import java.util.UUID

@Service
class AuthService(
    private val userRepository: UserRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val jwtTokenProvider: JwtTokenProvider
) {

    @Transactional
    fun refreshToken(request: RefreshTokenRequest): TokenResponse {
        val storedToken = refreshTokenRepository.findByToken(request.refreshToken)
            ?: throw UnauthorizedException("AUTH_INVALID_TOKEN", "Invalid refresh token")

        if (storedToken.revoked) {
            throw UnauthorizedException("AUTH_TOKEN_REVOKED", "Refresh token has been revoked")
        }

        if (storedToken.expiresAt.isBefore(Instant.now())) {
            storedToken.revoked = true
            refreshTokenRepository.save(storedToken)
            throw UnauthorizedException("AUTH_TOKEN_EXPIRED", "Refresh token has expired")
        }

        // Revoke old token
        storedToken.revoked = true
        refreshTokenRepository.save(storedToken)

        val user = storedToken.user

        // Generate new token pair
        val newAccessToken = jwtTokenProvider.generateAccessToken(user.id, user.email)
        val newRefreshTokenValue = jwtTokenProvider.generateRefreshToken()

        val newRefreshToken = RefreshToken(
            user = user,
            token = newRefreshTokenValue,
            expiresAt = Instant.now().plusMillis(jwtTokenProvider.getRefreshTokenExpiry())
        )
        refreshTokenRepository.save(newRefreshToken)

        return TokenResponse(
            accessToken = newAccessToken,
            refreshToken = newRefreshTokenValue,
            expiresIn = jwtTokenProvider.getAccessTokenExpiry()
        )
    }

    @Transactional
    fun logout(userId: UUID, request: LogoutRequest) {
        val storedToken = refreshTokenRepository.findByToken(request.refreshToken)
            ?: throw UnauthorizedException("AUTH_INVALID_TOKEN", "Invalid refresh token")

        if (storedToken.user.id != userId) {
            throw UnauthorizedException("AUTH_TOKEN_MISMATCH", "Token does not belong to the current user")
        }

        storedToken.revoked = true
        refreshTokenRepository.save(storedToken)
    }

    @Transactional(readOnly = true)
    fun getCurrentUser(userId: UUID): UserResponse {
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found") }

        return UserResponse.from(user)
    }
}
