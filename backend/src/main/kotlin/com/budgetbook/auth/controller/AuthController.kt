package com.budgetbook.auth.controller

import com.budgetbook.auth.dto.LogoutRequest
import com.budgetbook.auth.dto.RefreshTokenRequest
import com.budgetbook.auth.dto.TokenResponse
import com.budgetbook.auth.dto.UserResponse
import com.budgetbook.auth.service.AuthService
import com.budgetbook.common.dto.ApiResponse
import jakarta.validation.Valid
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/auth")
class AuthController(
    private val authService: AuthService
) {

    @PostMapping("/refresh")
    fun refreshToken(
        @Valid @RequestBody request: RefreshTokenRequest
    ): ApiResponse<TokenResponse> {
        val tokenResponse = authService.refreshToken(request)
        return ApiResponse.ok(tokenResponse)
    }

    @GetMapping("/me")
    fun getCurrentUser(authentication: Authentication): ApiResponse<UserResponse> {
        val userId = authentication.principal as UUID
        val userResponse = authService.getCurrentUser(userId)
        return ApiResponse.ok(userResponse)
    }

    @PostMapping("/logout")
    fun logout(
        authentication: Authentication,
        @Valid @RequestBody request: LogoutRequest
    ): ApiResponse<Unit> {
        val userId = authentication.principal as UUID
        authService.logout(userId, request)
        return ApiResponse.ok()
    }
}
