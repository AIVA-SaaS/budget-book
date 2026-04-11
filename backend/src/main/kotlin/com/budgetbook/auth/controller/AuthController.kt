package com.budgetbook.auth.controller

import com.budgetbook.auth.dto.LogoutRequest
import com.budgetbook.auth.dto.RefreshTokenRequest
import com.budgetbook.auth.dto.TokenResponse
import com.budgetbook.auth.dto.UpdateProfileRequest
import com.budgetbook.auth.dto.UserResponse
import com.budgetbook.auth.service.AuthService
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.ratelimit.RateLimitKeyType
import com.budgetbook.common.security.AuthUser
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
    private val authService: AuthService
) {

    @RateLimit(maxRequests = 10, windowSeconds = 60, keyType = RateLimitKeyType.IP)
    @PostMapping("/refresh")
    fun refreshToken(
        @Valid @RequestBody request: RefreshTokenRequest
    ): ApiResponse<TokenResponse> {
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
