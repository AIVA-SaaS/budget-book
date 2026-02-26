package com.budgetbook.auth.controller

import com.budgetbook.auth.dto.LogoutRequest
import com.budgetbook.auth.dto.RefreshTokenRequest
import com.budgetbook.auth.dto.TokenResponse
import com.budgetbook.auth.dto.UserResponse
import com.budgetbook.auth.service.AuthService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.Authentication
import java.time.Instant
import java.util.UUID

class AuthControllerTest : FunSpec({

    val authService = mockk<AuthService>()
    val authController = AuthController(authService)

    val testUserId = UUID.randomUUID()

    fun createAuthentication(userId: UUID): Authentication {
        return UsernamePasswordAuthenticationToken(userId, null, emptyList())
    }

    test("refreshToken calls authService.refreshToken and returns ApiResponse.ok") {
        val request = RefreshTokenRequest(refreshToken = "some-refresh-token")
        val expectedResponse = TokenResponse(
            accessToken = "new-access-token",
            refreshToken = "new-refresh-token",
            expiresIn = 3600000L
        )

        every { authService.refreshToken(request) } returns expectedResponse

        val result = authController.refreshToken(request)

        result.success shouldBe true
        result.data shouldBe expectedResponse
        result.data!!.accessToken shouldBe "new-access-token"
        result.data!!.refreshToken shouldBe "new-refresh-token"
        result.data!!.expiresIn shouldBe 3600000L

        verify(exactly = 1) { authService.refreshToken(request) }
    }

    test("getCurrentUser returns current user info wrapped in ApiResponse.ok") {
        val authentication = createAuthentication(testUserId)
        val expectedUser = UserResponse(
            id = testUserId,
            email = "test@example.com",
            nickname = "TestUser",
            profileImageUrl = "https://example.com/photo.png",
            provider = "GOOGLE",
            role = "USER",
            createdAt = Instant.now()
        )

        every { authService.getCurrentUser(testUserId) } returns expectedUser

        val result = authController.getCurrentUser(authentication)

        result.success shouldBe true
        result.data shouldBe expectedUser
        result.data!!.id shouldBe testUserId
        result.data!!.email shouldBe "test@example.com"
        result.data!!.nickname shouldBe "TestUser"

        verify(exactly = 1) { authService.getCurrentUser(testUserId) }
    }

    test("logout calls authService.logout and returns ApiResponse.ok") {
        val authentication = createAuthentication(testUserId)
        val request = LogoutRequest(refreshToken = "logout-refresh-token")

        justRun { authService.logout(testUserId, request) }

        val result = authController.logout(authentication, request)

        result.success shouldBe true

        verify(exactly = 1) { authService.logout(testUserId, request) }
    }

    test("refreshToken passes the exact request object to service") {
        val request = RefreshTokenRequest(refreshToken = "specific-token-value")
        val tokenResponse = TokenResponse(
            accessToken = "access",
            refreshToken = "refresh",
            expiresIn = 1000L
        )

        every { authService.refreshToken(request) } returns tokenResponse

        authController.refreshToken(request)

        verify { authService.refreshToken(match { it.refreshToken == "specific-token-value" }) }
    }

    test("getCurrentUser extracts UUID from authentication principal") {
        val specificUserId = UUID.fromString("550e8400-e29b-41d4-a716-446655440000")
        val authentication = createAuthentication(specificUserId)
        val expectedUser = UserResponse(
            id = specificUserId,
            email = "specific@example.com",
            nickname = "SpecificUser",
            profileImageUrl = null,
            provider = "KAKAO",
            role = "USER",
            createdAt = Instant.now()
        )

        every { authService.getCurrentUser(specificUserId) } returns expectedUser

        val result = authController.getCurrentUser(authentication)

        result.data!!.id shouldBe specificUserId
        verify { authService.getCurrentUser(specificUserId) }
    }

    test("logout extracts UUID from authentication principal and passes to service") {
        val specificUserId = UUID.fromString("550e8400-e29b-41d4-a716-446655440000")
        val authentication = createAuthentication(specificUserId)
        val request = LogoutRequest(refreshToken = "token-to-logout")

        justRun { authService.logout(specificUserId, request) }

        authController.logout(authentication, request)

        verify { authService.logout(specificUserId, request) }
    }
})
