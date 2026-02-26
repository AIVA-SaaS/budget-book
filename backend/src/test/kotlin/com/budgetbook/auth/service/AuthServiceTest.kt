package com.budgetbook.auth.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.RefreshToken
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.dto.LogoutRequest
import com.budgetbook.auth.dto.RefreshTokenRequest
import com.budgetbook.auth.repository.RefreshTokenRepository
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.exception.UnauthorizedException
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.Instant
import java.util.Optional
import java.util.UUID

class AuthServiceTest : BehaviorSpec({

    val userRepository = mockk<UserRepository>()
    val refreshTokenRepository = mockk<RefreshTokenRepository>()
    val jwtTokenProvider = mockk<JwtTokenProvider>()

    val authService = AuthService(userRepository, refreshTokenRepository, jwtTokenProvider)

    val testUser = User(
        email = "test@example.com",
        nickname = "TestUser",
        profileImageUrl = "https://example.com/photo.png",
        provider = AuthProvider.GOOGLE,
        providerId = "google-123"
    )

    Given("a valid refresh token") {
        val storedToken = RefreshToken(
            user = testUser,
            token = "valid-refresh-token",
            expiresAt = Instant.now().plusSeconds(3600),
            revoked = false
        )

        every { refreshTokenRepository.findByToken("valid-refresh-token") } returns storedToken
        every { refreshTokenRepository.save(any()) } returnsArgument 0
        every { jwtTokenProvider.generateAccessToken(testUser.id, testUser.email) } returns "new-access-token"
        every { jwtTokenProvider.generateRefreshToken() } returns "new-refresh-token"
        every { jwtTokenProvider.getAccessTokenExpiry() } returns 3600000L
        every { jwtTokenProvider.getRefreshTokenExpiry() } returns 604800000L

        When("refreshToken is called") {
            val request = RefreshTokenRequest(refreshToken = "valid-refresh-token")
            val result = authService.refreshToken(request)

            Then("returns new TokenResponse") {
                result.accessToken shouldBe "new-access-token"
                result.refreshToken shouldBe "new-refresh-token"
                result.expiresIn shouldBe 3600000L
            }

            Then("revokes the old refresh token") {
                storedToken.revoked shouldBe true
                verify { refreshTokenRepository.save(storedToken) }
            }

            Then("saves a new refresh token") {
                // Two saves: one for revoking old token, one for saving new token
                verify(exactly = 2) { refreshTokenRepository.save(any()) }
            }
        }
    }

    Given("an expired refresh token") {
        val expiredToken = RefreshToken(
            user = testUser,
            token = "expired-refresh-token",
            expiresAt = Instant.now().minusSeconds(3600), // expired 1 hour ago
            revoked = false
        )

        every { refreshTokenRepository.findByToken("expired-refresh-token") } returns expiredToken
        every { refreshTokenRepository.save(any()) } returnsArgument 0

        When("refreshToken is called") {
            val request = RefreshTokenRequest(refreshToken = "expired-refresh-token")

            Then("throws UnauthorizedException") {
                val exception = shouldThrow<UnauthorizedException> {
                    authService.refreshToken(request)
                }
                exception.code shouldBe "AUTH_TOKEN_EXPIRED"
            }
        }
    }

    Given("a revoked refresh token") {
        val revokedToken = RefreshToken(
            user = testUser,
            token = "revoked-refresh-token",
            expiresAt = Instant.now().plusSeconds(3600),
            revoked = true
        )

        every { refreshTokenRepository.findByToken("revoked-refresh-token") } returns revokedToken

        When("refreshToken is called") {
            val request = RefreshTokenRequest(refreshToken = "revoked-refresh-token")

            Then("throws UnauthorizedException") {
                val exception = shouldThrow<UnauthorizedException> {
                    authService.refreshToken(request)
                }
                exception.code shouldBe "AUTH_TOKEN_REVOKED"
            }
        }
    }

    Given("a non-existent refresh token") {
        every { refreshTokenRepository.findByToken("non-existent-token") } returns null

        When("refreshToken is called") {
            val request = RefreshTokenRequest(refreshToken = "non-existent-token")

            Then("throws UnauthorizedException") {
                val exception = shouldThrow<UnauthorizedException> {
                    authService.refreshToken(request)
                }
                exception.code shouldBe "AUTH_INVALID_TOKEN"
            }
        }
    }

    Given("a valid user ID") {
        every { userRepository.findById(testUser.id) } returns Optional.of(testUser)

        When("getCurrentUser is called") {
            val result = authService.getCurrentUser(testUser.id)

            Then("returns UserResponse with correct data") {
                result.id shouldBe testUser.id
                result.email shouldBe "test@example.com"
                result.nickname shouldBe "TestUser"
                result.profileImageUrl shouldBe "https://example.com/photo.png"
                result.provider shouldBe "GOOGLE"
                result.role shouldBe "USER"
            }
        }
    }

    Given("an invalid user ID") {
        val unknownId = UUID.randomUUID()
        every { userRepository.findById(unknownId) } returns Optional.empty()

        When("getCurrentUser is called") {
            Then("throws NotFoundException") {
                val exception = shouldThrow<NotFoundException> {
                    authService.getCurrentUser(unknownId)
                }
                exception.code shouldBe "USER_NOT_FOUND"
            }
        }
    }

    Given("a valid logout request") {
        val logoutToken = RefreshToken(
            user = testUser,
            token = "logout-refresh-token",
            expiresAt = Instant.now().plusSeconds(3600),
            revoked = false
        )

        every { refreshTokenRepository.findByToken("logout-refresh-token") } returns logoutToken
        every { refreshTokenRepository.save(any()) } returnsArgument 0

        When("logout is called") {
            val request = LogoutRequest(refreshToken = "logout-refresh-token")
            authService.logout(testUser.id, request)

            Then("revokes the token") {
                logoutToken.revoked shouldBe true
                verify { refreshTokenRepository.save(logoutToken) }
            }
        }
    }

    Given("a logout request with a token belonging to another user") {
        val otherUser = User(
            email = "other@example.com",
            nickname = "OtherUser",
            provider = AuthProvider.KAKAO,
            providerId = "kakao-456"
        )

        val otherUserToken = RefreshToken(
            user = otherUser,
            token = "other-user-token",
            expiresAt = Instant.now().plusSeconds(3600),
            revoked = false
        )

        every { refreshTokenRepository.findByToken("other-user-token") } returns otherUserToken

        When("logout is called with a different user ID") {
            val request = LogoutRequest(refreshToken = "other-user-token")

            Then("throws UnauthorizedException") {
                val exception = shouldThrow<UnauthorizedException> {
                    authService.logout(testUser.id, request)
                }
                exception.code shouldBe "AUTH_TOKEN_MISMATCH"
            }
        }
    }
})
