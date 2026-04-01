package com.budgetbook.auth.controller

import com.budgetbook.auth.dto.LogoutRequest
import com.budgetbook.auth.dto.RefreshTokenRequest
import com.budgetbook.auth.dto.TokenResponse
import com.budgetbook.auth.dto.UpdateProfileRequest
import com.budgetbook.auth.dto.UserResponse
import com.budgetbook.auth.service.AuthService
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.exception.TooManyRequestsException
import com.budgetbook.common.ratelimit.RateLimiter
import com.budgetbook.common.security.AuthUser
import jakarta.servlet.http.HttpServletRequest
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.multipart.MultipartFile
import java.util.UUID

@RestController
@RequestMapping("/api/v1/auth")
class AuthController(
    private val authService: AuthService,
    private val rateLimiter: RateLimiter
) {

    companion object {
        private const val LOGIN_MAX_REQUESTS = 10
        private const val LOGIN_WINDOW_MILLIS = 60_000L // 1 minute
    }

    @PostMapping("/refresh")
    fun refreshToken(
        @Valid @RequestBody request: RefreshTokenRequest,
        httpRequest: HttpServletRequest
    ): ApiResponse<TokenResponse> {
        val clientIp = httpRequest.getHeader("X-Forwarded-For")?.split(",")?.firstOrNull()?.trim()
            ?: httpRequest.remoteAddr
        val rateLimitKey = "auth-refresh:$clientIp"

        if (!rateLimiter.tryAcquire(rateLimitKey, LOGIN_MAX_REQUESTS, LOGIN_WINDOW_MILLIS)) {
            throw TooManyRequestsException(
                "RATE_LIMIT_EXCEEDED",
                "Too many login attempts. Please try again later."
            )
        }

        val tokenResponse = authService.refreshToken(request)
        return ApiResponse.ok(tokenResponse)
    }

    @GetMapping("/me")
    fun getCurrentUser(@AuthUser userId: UUID): ApiResponse<UserResponse> {
        val userResponse = authService.getCurrentUser(userId)
        return ApiResponse.ok(userResponse)
    }

    @PatchMapping("/me")
    fun updateProfile(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: UpdateProfileRequest
    ): ApiResponse<UserResponse> {
        val userResponse = authService.updateProfile(userId, request)
        return ApiResponse.ok(userResponse)
    }

    @PostMapping("/me/profile-image")
    fun uploadProfileImage(
        @AuthUser userId: UUID,
        @RequestParam("file") file: MultipartFile
    ): ApiResponse<UserResponse> {
        val userResponse = authService.uploadProfileImage(userId, file)
        return ApiResponse.ok(userResponse)
    }

    @DeleteMapping("/me/profile-image")
    fun removeProfileImage(@AuthUser userId: UUID): ApiResponse<UserResponse> {
        val userResponse = authService.removeProfileImage(userId)
        return ApiResponse.ok(userResponse)
    }

    @PostMapping("/logout")
    fun logout(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: LogoutRequest
    ): ApiResponse<Unit> {
        authService.logout(userId, request)
        return ApiResponse.ok()
    }
}
