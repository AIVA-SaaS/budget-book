package com.budgetbook.auth.controller

import com.budgetbook.auth.dto.LogoutRequest
import com.budgetbook.auth.dto.RefreshTokenRequest
import com.budgetbook.auth.dto.TokenResponse
import com.budgetbook.auth.dto.UpdateProfileRequest
import com.budgetbook.auth.dto.UserResponse
import com.budgetbook.auth.service.AuthService
import com.budgetbook.common.exception.TooManyRequestsException
import com.budgetbook.common.ratelimit.RateLimiter
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.clearAllMocks
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockMultipartFile
import java.time.Instant
import java.util.UUID

class AuthControllerTest : FunSpec({

    val authService = mockk<AuthService>()
    val rateLimiter = mockk<RateLimiter>()
    val authController = AuthController(authService, rateLimiter)

    val testUserId = UUID.randomUUID()

    beforeEach {
        clearAllMocks()
    }

    test("refreshToken calls authService.refreshToken and returns ApiResponse.ok") {
        val request = RefreshTokenRequest(refreshToken = "some-refresh-token")
        val httpRequest = MockHttpServletRequest().apply { remoteAddr = "127.0.0.1" }
        val expectedResponse = TokenResponse(
            accessToken = "new-access-token",
            refreshToken = "new-refresh-token",
            expiresIn = 3600000L
        )

        every { rateLimiter.tryAcquire(any(), any(), any()) } returns true
        every { authService.refreshToken(request) } returns expectedResponse

        val result = authController.refreshToken(request, httpRequest)

        result.success shouldBe true
        result.data shouldBe expectedResponse
        result.data!!.accessToken shouldBe "new-access-token"
        result.data!!.refreshToken shouldBe "new-refresh-token"
        result.data!!.expiresIn shouldBe 3600000L

        verify(exactly = 1) { authService.refreshToken(request) }
    }

    test("refreshToken throws TooManyRequestsException when rate limit exceeded") {
        val request = RefreshTokenRequest(refreshToken = "some-refresh-token")
        val httpRequest = MockHttpServletRequest().apply { remoteAddr = "127.0.0.1" }

        every { rateLimiter.tryAcquire(any(), any(), any()) } returns false

        shouldThrow<TooManyRequestsException> {
            authController.refreshToken(request, httpRequest)
        }
    }

    test("refreshToken uses X-Forwarded-For header for IP extraction") {
        val request = RefreshTokenRequest(refreshToken = "some-refresh-token")
        val httpRequest = MockHttpServletRequest().apply {
            remoteAddr = "10.0.0.1"
            addHeader("X-Forwarded-For", "203.0.113.50, 70.41.3.18")
        }
        val expectedResponse = TokenResponse(
            accessToken = "access",
            refreshToken = "refresh",
            expiresIn = 1000L
        )

        every { rateLimiter.tryAcquire("auth-refresh:203.0.113.50", 10, 60_000L) } returns true
        every { authService.refreshToken(request) } returns expectedResponse

        val result = authController.refreshToken(request, httpRequest)
        result.success shouldBe true
    }

    test("getCurrentUser returns current user info wrapped in ApiResponse.ok") {
        val coupleId = UUID.randomUUID()
        val expectedUser = UserResponse(
            id = testUserId,
            email = "test@example.com",
            nickname = "TestUser",
            profileImageUrl = "https://example.com/photo.png",
            provider = "GOOGLE",
            role = "USER",
            coupleId = coupleId,
            createdAt = Instant.now()
        )

        every { authService.getCurrentUser(testUserId) } returns expectedUser

        val result = authController.getCurrentUser(testUserId)

        result.success shouldBe true
        result.data shouldBe expectedUser
        result.data!!.id shouldBe testUserId
        result.data!!.email shouldBe "test@example.com"
        result.data!!.nickname shouldBe "TestUser"

        verify(exactly = 1) { authService.getCurrentUser(testUserId) }
    }

    test("logout calls authService.logout and returns ApiResponse.ok") {
        val request = LogoutRequest(refreshToken = "logout-refresh-token")

        justRun { authService.logout(testUserId, request) }

        val result = authController.logout(testUserId, request)

        result.success shouldBe true

        verify(exactly = 1) { authService.logout(testUserId, request) }
    }

    test("refreshToken passes the exact request object to service") {
        val request = RefreshTokenRequest(refreshToken = "specific-token-value")
        val httpRequest = MockHttpServletRequest().apply { remoteAddr = "127.0.0.1" }
        val tokenResponse = TokenResponse(
            accessToken = "access",
            refreshToken = "refresh",
            expiresIn = 1000L
        )

        every { rateLimiter.tryAcquire(any(), any(), any()) } returns true
        every { authService.refreshToken(request) } returns tokenResponse

        authController.refreshToken(request, httpRequest)

        verify { authService.refreshToken(match { it.refreshToken == "specific-token-value" }) }
    }

    test("getCurrentUser returns null coupleId when user has no couple") {
        val expectedUser = UserResponse(
            id = testUserId,
            email = "test@example.com",
            nickname = "TestUser",
            profileImageUrl = "https://example.com/photo.png",
            provider = "GOOGLE",
            role = "USER",
            coupleId = null,
            createdAt = Instant.now()
        )

        every { authService.getCurrentUser(testUserId) } returns expectedUser

        val result = authController.getCurrentUser(testUserId)

        result.success shouldBe true
        result.data!!.coupleId shouldBe null

        verify(exactly = 1) { authService.getCurrentUser(testUserId) }
    }

    test("getCurrentUser extracts UUID from authentication principal") {
        val specificUserId = UUID.fromString("550e8400-e29b-41d4-a716-446655440000")
        val expectedUser = UserResponse(
            id = specificUserId,
            email = "specific@example.com",
            nickname = "SpecificUser",
            profileImageUrl = null,
            provider = "KAKAO",
            role = "USER",
            coupleId = null,
            createdAt = Instant.now()
        )

        every { authService.getCurrentUser(specificUserId) } returns expectedUser

        val result = authController.getCurrentUser(specificUserId)

        result.data!!.id shouldBe specificUserId
        verify { authService.getCurrentUser(specificUserId) }
    }

    test("logout extracts UUID from authentication principal and passes to service") {
        val specificUserId = UUID.fromString("550e8400-e29b-41d4-a716-446655440000")
        val request = LogoutRequest(refreshToken = "token-to-logout")

        justRun { authService.logout(specificUserId, request) }

        authController.logout(specificUserId, request)

        verify { authService.logout(specificUserId, request) }
    }

    test("updateProfile calls authService.updateProfile and returns ApiResponse.ok") {
        val request = UpdateProfileRequest(nickname = "NewNickname")
        val expectedUser = UserResponse(
            id = testUserId,
            email = "test@example.com",
            nickname = "NewNickname",
            profileImageUrl = "https://example.com/photo.png",
            provider = "GOOGLE",
            role = "USER",
            coupleId = null,
            createdAt = Instant.now()
        )

        every { authService.updateProfile(testUserId, request) } returns expectedUser

        val result = authController.updateProfile(testUserId, request)

        result.success shouldBe true
        result.data shouldBe expectedUser
        result.data!!.nickname shouldBe "NewNickname"

        verify(exactly = 1) { authService.updateProfile(testUserId, request) }
    }

    test("updateProfile with clearProfileImage returns null profileImageUrl") {
        val request = UpdateProfileRequest(clearProfileImage = true)
        val expectedUser = UserResponse(
            id = testUserId,
            email = "test@example.com",
            nickname = "TestUser",
            profileImageUrl = null,
            provider = "GOOGLE",
            role = "USER",
            coupleId = null,
            createdAt = Instant.now()
        )

        every { authService.updateProfile(testUserId, request) } returns expectedUser

        val result = authController.updateProfile(testUserId, request)

        result.success shouldBe true
        result.data!!.profileImageUrl shouldBe null

        verify(exactly = 1) { authService.updateProfile(testUserId, request) }
    }

    test("updateProfile extracts UUID from authentication principal") {
        val specificUserId = UUID.fromString("550e8400-e29b-41d4-a716-446655440000")
        val request = UpdateProfileRequest(nickname = "Updated")
        val expectedUser = UserResponse(
            id = specificUserId,
            email = "specific@example.com",
            nickname = "Updated",
            profileImageUrl = null,
            provider = "KAKAO",
            role = "USER",
            coupleId = null,
            createdAt = Instant.now()
        )

        every { authService.updateProfile(specificUserId, request) } returns expectedUser

        val result = authController.updateProfile(specificUserId, request)

        result.data!!.id shouldBe specificUserId
        verify { authService.updateProfile(specificUserId, request) }
    }

    test("uploadProfileImage calls authService.uploadProfileImage and returns ApiResponse.ok") {
        val file = MockMultipartFile("file", "photo.jpg", "image/jpeg", byteArrayOf(0x01, 0x02))
        val expectedUser = UserResponse(
            id = testUserId,
            email = "test@example.com",
            nickname = "TestUser",
            profileImageUrl = "data:image/jpeg;base64,AQI=",
            provider = "GOOGLE",
            role = "USER",
            coupleId = null,
            createdAt = Instant.now()
        )

        every { authService.uploadProfileImage(testUserId, any()) } returns expectedUser

        val result = authController.uploadProfileImage(testUserId, file)

        result.success shouldBe true
        result.data!!.profileImageUrl shouldBe "data:image/jpeg;base64,AQI="
        verify(exactly = 1) { authService.uploadProfileImage(testUserId, any()) }
    }

    test("removeProfileImage calls authService.removeProfileImage and returns ApiResponse.ok") {
        val expectedUser = UserResponse(
            id = testUserId,
            email = "test@example.com",
            nickname = "TestUser",
            profileImageUrl = null,
            provider = "GOOGLE",
            role = "USER",
            coupleId = null,
            createdAt = Instant.now()
        )

        every { authService.removeProfileImage(testUserId) } returns expectedUser

        val result = authController.removeProfileImage(testUserId)

        result.success shouldBe true
        result.data!!.profileImageUrl shouldBe null
        verify(exactly = 1) { authService.removeProfileImage(testUserId) }
    }
})
