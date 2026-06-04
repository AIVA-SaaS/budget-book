package com.budgetbook.auth.service

import com.budgetbook.auth.domain.EmailPolicy
import com.budgetbook.auth.domain.RefreshToken
import com.budgetbook.auth.dto.LogoutRequest
import com.budgetbook.auth.dto.RefreshTokenRequest
import com.budgetbook.auth.dto.TokenResponse
import com.budgetbook.auth.dto.UpdateProfileRequest
import com.budgetbook.auth.dto.UserResponse
import com.budgetbook.auth.repository.RefreshTokenRepository
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.exception.UnauthorizedException
import org.springframework.web.multipart.MultipartFile
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant
import java.util.Base64
import java.util.UUID

@Service
class AuthService(
    private val userRepository: UserRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val jwtTokenProvider: JwtTokenProvider,
    private val coupleRepository: CoupleRepository,
    private val userCacheService: UserCacheService
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

        // Evict user from JWT auth cache on logout
        userCacheService.evict(userId)
    }

    @Transactional(readOnly = true)
    fun getCurrentUser(userId: UUID): UserResponse {
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found") }

        val couple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        return UserResponse.from(user, couple?.id)
    }

    @Transactional
    fun updateProfile(userId: UUID, request: UpdateProfileRequest): UserResponse {
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found") }

        request.nickname?.let { user.nickname = it }
        if (request.clearProfileImage) {
            user.profileImageUrl = null
        } else {
            request.profileImageUrl?.let { user.profileImageUrl = it }
        }

        request.email?.let { rawEmail ->
            val trimmed = rawEmail.trim()
            // Reject direct placeholder domain input
            if (EmailPolicy.isPlaceholderEmail(trimmed)) {
                throw BusinessException("INVALID_EMAIL", "Cannot use a reserved email domain.")
            }
            // Reject duplicate email belonging to a different user
            val existing = userRepository.findByEmail(trimmed)
            if (existing != null && existing.id != user.id) {
                throw BusinessException("EMAIL_ALREADY_IN_USE", "This email is already in use by another account.")
            }
            user.email = trimmed
        }

        val savedUser = userRepository.save(user)
        userCacheService.evict(userId)

        val couple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        return UserResponse.from(savedUser, couple?.id)
    }

    @Transactional
    fun uploadProfileImage(userId: UUID, file: MultipartFile): UserResponse {
        val maxSize = 2L * 1024 * 1024 // 2MB
        if (file.size > maxSize) {
            throw BusinessException("VALIDATION_ERROR", "File size must not exceed 2MB")
        }

        val allowedTypes = setOf("image/jpeg", "image/png", "image/webp")
        val contentType = file.contentType
        if (contentType == null || contentType !in allowedTypes) {
            throw BusinessException("VALIDATION_ERROR", "File type must be one of: image/jpeg, image/png, image/webp")
        }

        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found") }

        val base64Data = Base64.getEncoder().encodeToString(file.bytes)
        user.profileImageUrl = "data:$contentType;base64,$base64Data"

        val savedUser = userRepository.save(user)
        userCacheService.evict(userId)

        val couple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        return UserResponse.from(savedUser, couple?.id)
    }

    @Transactional
    fun removeProfileImage(userId: UUID): UserResponse {
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found") }

        user.profileImageUrl = null

        val savedUser = userRepository.save(user)
        userCacheService.evict(userId)

        val couple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        return UserResponse.from(savedUser, couple?.id)
    }
}
