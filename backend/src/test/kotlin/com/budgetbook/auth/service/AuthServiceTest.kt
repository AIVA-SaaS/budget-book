package com.budgetbook.auth.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.RefreshToken
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.dto.LogoutRequest
import com.budgetbook.auth.dto.RefreshTokenRequest
import com.budgetbook.auth.dto.UpdateProfileRequest
import com.budgetbook.auth.repository.RefreshTokenRepository
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.exception.UnauthorizedException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldStartWith
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.springframework.web.multipart.MultipartFile
import java.time.Instant
import java.util.Optional
import java.util.UUID

class AuthServiceTest : BehaviorSpec({

    val userRepository = mockk<UserRepository>()
    val refreshTokenRepository = mockk<RefreshTokenRepository>()
    val jwtTokenProvider = mockk<JwtTokenProvider>()
    val coupleRepository = mockk<CoupleRepository>()
    val userCacheService = mockk<UserCacheService>(relaxed = true)

    val authService = AuthService(userRepository, refreshTokenRepository, jwtTokenProvider, coupleRepository, userCacheService)

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

    Given("a valid user ID with no active couple") {
        every { userRepository.findById(testUser.id) } returns Optional.of(testUser)
        every { coupleRepository.findByUserIdAndStatus(testUser.id, CoupleStatus.ACTIVE) } returns null

        When("getCurrentUser is called") {
            val result = authService.getCurrentUser(testUser.id)

            Then("returns UserResponse with null coupleId") {
                result.id shouldBe testUser.id
                result.email shouldBe "test@example.com"
                result.nickname shouldBe "TestUser"
                result.profileImageUrl shouldBe "https://example.com/photo.png"
                result.provider shouldBe "GOOGLE"
                result.role shouldBe "USER"
                result.coupleId shouldBe null
            }
        }
    }

    Given("a valid user ID with an active couple") {
        val otherUser = User(
            email = "partner@example.com",
            nickname = "Partner",
            provider = AuthProvider.KAKAO,
            providerId = "kakao-789"
        )
        val couple = Couple(
            user1 = testUser,
            user2 = otherUser,
            status = CoupleStatus.ACTIVE
        )

        every { userRepository.findById(testUser.id) } returns Optional.of(testUser)
        every { coupleRepository.findByUserIdAndStatus(testUser.id, CoupleStatus.ACTIVE) } returns couple

        When("getCurrentUser is called") {
            val result = authService.getCurrentUser(testUser.id)

            Then("returns UserResponse with the coupleId") {
                result.id shouldBe testUser.id
                result.email shouldBe "test@example.com"
                result.coupleId shouldBe couple.id
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

    Given("an updateProfile request with nickname only") {
        val user = User(
            email = "profile@example.com",
            nickname = "OldNick",
            profileImageUrl = "https://example.com/old.png",
            provider = AuthProvider.GOOGLE,
            providerId = "google-profile-1"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { userRepository.save(any()) } returnsArgument 0
        every { coupleRepository.findByUserIdAndStatus(user.id, CoupleStatus.ACTIVE) } returns null

        When("updateProfile is called with a new nickname") {
            val request = UpdateProfileRequest(nickname = "NewNick")
            val result = authService.updateProfile(user.id, request)

            Then("updates the nickname and keeps profileImageUrl") {
                result.nickname shouldBe "NewNick"
                result.profileImageUrl shouldBe "https://example.com/old.png"
            }

            Then("evicts the user cache") {
                verify { userCacheService.evict(user.id) }
            }
        }
    }

    Given("an updateProfile request with profileImageUrl only") {
        val user = User(
            email = "profile2@example.com",
            nickname = "KeepNick",
            profileImageUrl = "https://example.com/old.png",
            provider = AuthProvider.GOOGLE,
            providerId = "google-profile-2"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { userRepository.save(any()) } returnsArgument 0
        every { coupleRepository.findByUserIdAndStatus(user.id, CoupleStatus.ACTIVE) } returns null

        When("updateProfile is called with a new profileImageUrl") {
            val request = UpdateProfileRequest(profileImageUrl = "https://example.com/new.png")
            val result = authService.updateProfile(user.id, request)

            Then("updates the profileImageUrl and keeps nickname") {
                result.nickname shouldBe "KeepNick"
                result.profileImageUrl shouldBe "https://example.com/new.png"
            }
        }
    }

    Given("an updateProfile request with clearProfileImage = true") {
        val user = User(
            email = "profile3@example.com",
            nickname = "ClearImg",
            profileImageUrl = "https://example.com/existing.png",
            provider = AuthProvider.GOOGLE,
            providerId = "google-profile-3"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { userRepository.save(any()) } returnsArgument 0
        every { coupleRepository.findByUserIdAndStatus(user.id, CoupleStatus.ACTIVE) } returns null

        When("updateProfile is called with clearProfileImage = true") {
            val request = UpdateProfileRequest(clearProfileImage = true)
            val result = authService.updateProfile(user.id, request)

            Then("clears the profileImageUrl") {
                result.profileImageUrl shouldBe null
            }
        }
    }

    Given("an updateProfile request with clearProfileImage = true and profileImageUrl provided") {
        val user = User(
            email = "profile4@example.com",
            nickname = "ClearWins",
            profileImageUrl = "https://example.com/existing.png",
            provider = AuthProvider.GOOGLE,
            providerId = "google-profile-4"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { userRepository.save(any()) } returnsArgument 0
        every { coupleRepository.findByUserIdAndStatus(user.id, CoupleStatus.ACTIVE) } returns null

        When("updateProfile is called") {
            val request = UpdateProfileRequest(
                profileImageUrl = "https://example.com/new.png",
                clearProfileImage = true
            )
            val result = authService.updateProfile(user.id, request)

            Then("clearProfileImage takes precedence and sets profileImageUrl to null") {
                result.profileImageUrl shouldBe null
            }
        }
    }

    Given("an updateProfile request for a non-existent user") {
        val unknownId = UUID.randomUUID()
        every { userRepository.findById(unknownId) } returns Optional.empty()

        When("updateProfile is called") {
            val request = UpdateProfileRequest(nickname = "NewNick")

            Then("throws NotFoundException") {
                val exception = shouldThrow<NotFoundException> {
                    authService.updateProfile(unknownId, request)
                }
                exception.code shouldBe "USER_NOT_FOUND"
            }
        }
    }

    // --- uploadProfileImage ---

    Given("a valid JPEG image file") {
        val user = User(
            email = "upload@example.com",
            nickname = "Uploader",
            provider = AuthProvider.GOOGLE,
            providerId = "google-upload-1"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { userRepository.save(any()) } returnsArgument 0
        every { coupleRepository.findByUserIdAndStatus(user.id, CoupleStatus.ACTIVE) } returns null

        val file = mockk<MultipartFile>()
        every { file.size } returns 1024L
        every { file.contentType } returns "image/jpeg"
        every { file.bytes } returns byteArrayOf(0x01, 0x02, 0x03)

        When("uploadProfileImage is called") {
            val result = authService.uploadProfileImage(user.id, file)

            Then("stores base64 data URL in profileImageUrl") {
                result.profileImageUrl shouldStartWith "data:image/jpeg;base64,"
            }

            Then("evicts the user cache") {
                verify { userCacheService.evict(user.id) }
            }
        }
    }

    Given("a PNG image file") {
        val user = User(
            email = "upload-png@example.com",
            nickname = "PngUploader",
            provider = AuthProvider.GOOGLE,
            providerId = "google-upload-png"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { userRepository.save(any()) } returnsArgument 0
        every { coupleRepository.findByUserIdAndStatus(user.id, CoupleStatus.ACTIVE) } returns null

        val file = mockk<MultipartFile>()
        every { file.size } returns 500L
        every { file.contentType } returns "image/png"
        every { file.bytes } returns byteArrayOf(0x50, 0x4E, 0x47, 0x0A)

        When("uploadProfileImage is called") {
            val result = authService.uploadProfileImage(user.id, file)

            Then("stores base64 data URL with image/png content type") {
                result.profileImageUrl shouldStartWith "data:image/png;base64,"
            }
        }
    }

    Given("a file exceeding 2MB") {
        val file = mockk<MultipartFile>()
        every { file.size } returns 3 * 1024 * 1024L // 3MB

        When("uploadProfileImage is called") {
            Then("throws BusinessException for file size") {
                val exception = shouldThrow<BusinessException> {
                    authService.uploadProfileImage(UUID.randomUUID(), file)
                }
                exception.code shouldBe "VALIDATION_ERROR"
                exception.message shouldBe "File size must not exceed 2MB"
            }
        }
    }

    Given("a file with unsupported content type") {
        val file = mockk<MultipartFile>()
        every { file.size } returns 1024L
        every { file.contentType } returns "image/gif"

        When("uploadProfileImage is called") {
            Then("throws BusinessException for content type") {
                val exception = shouldThrow<BusinessException> {
                    authService.uploadProfileImage(UUID.randomUUID(), file)
                }
                exception.code shouldBe "VALIDATION_ERROR"
                exception.message shouldBe "File type must be one of: image/jpeg, image/png, image/webp"
            }
        }
    }

    Given("a file with null content type") {
        val file = mockk<MultipartFile>()
        every { file.size } returns 1024L
        every { file.contentType } returns null

        When("uploadProfileImage is called") {
            Then("throws BusinessException for content type") {
                val exception = shouldThrow<BusinessException> {
                    authService.uploadProfileImage(UUID.randomUUID(), file)
                }
                exception.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("uploadProfileImage for a non-existent user") {
        val unknownId = UUID.randomUUID()
        val file = mockk<MultipartFile>()
        every { file.size } returns 1024L
        every { file.contentType } returns "image/jpeg"
        every { userRepository.findById(unknownId) } returns Optional.empty()

        When("uploadProfileImage is called") {
            Then("throws NotFoundException") {
                val exception = shouldThrow<NotFoundException> {
                    authService.uploadProfileImage(unknownId, file)
                }
                exception.code shouldBe "USER_NOT_FOUND"
            }
        }
    }

    // --- removeProfileImage ---

    Given("a user with an existing profile image") {
        val user = User(
            email = "remove@example.com",
            nickname = "Remover",
            profileImageUrl = "data:image/jpeg;base64,abc123",
            provider = AuthProvider.GOOGLE,
            providerId = "google-remove-1"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { userRepository.save(any()) } returnsArgument 0
        every { coupleRepository.findByUserIdAndStatus(user.id, CoupleStatus.ACTIVE) } returns null

        When("removeProfileImage is called") {
            val result = authService.removeProfileImage(user.id)

            Then("sets profileImageUrl to null") {
                result.profileImageUrl shouldBe null
            }

            Then("evicts the user cache") {
                verify { userCacheService.evict(user.id) }
            }
        }
    }

    Given("removeProfileImage for a non-existent user") {
        val unknownId = UUID.randomUUID()
        every { userRepository.findById(unknownId) } returns Optional.empty()

        When("removeProfileImage is called") {
            Then("throws NotFoundException") {
                val exception = shouldThrow<NotFoundException> {
                    authService.removeProfileImage(unknownId)
                }
                exception.code shouldBe "USER_NOT_FOUND"
            }
        }
    }

    // --- updateProfile email field ---

    Given("a Kakao user with placeholder email updating to a real email") {
        val kakaoUser = User(
            email = "kakao_12345@no-email.local",
            nickname = "KakaoUser",
            provider = AuthProvider.KAKAO,
            providerId = "12345"
        )

        every { userRepository.findById(kakaoUser.id) } returns Optional.of(kakaoUser)
        every { userRepository.findByEmail("real@example.com") } returns null
        every { userRepository.save(any()) } returnsArgument 0
        every { coupleRepository.findByUserIdAndStatus(kakaoUser.id, CoupleStatus.ACTIVE) } returns null

        When("updateProfile is called with a real email") {
            val request = UpdateProfileRequest(email = "real@example.com")
            val result = authService.updateProfile(kakaoUser.id, request)

            Then("email is updated successfully") {
                result.email shouldBe "real@example.com"
            }

            Then("evicts user cache") {
                verify { userCacheService.evict(kakaoUser.id) }
            }
        }
    }

    Given("a user trying to update email to a placeholder domain value") {
        val user = User(
            email = "kakao_abc@no-email.local",
            nickname = "KakaoUser2",
            provider = AuthProvider.KAKAO,
            providerId = "abc"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)

        When("updateProfile is called with a placeholder-domain email") {
            val request = UpdateProfileRequest(email = "attacker_xyz@no-email.local")

            Then("throws BusinessException with INVALID_EMAIL") {
                val exception = shouldThrow<BusinessException> {
                    authService.updateProfile(user.id, request)
                }
                exception.code shouldBe "INVALID_EMAIL"
            }
        }
    }

    Given("a user trying to update email to one already used by another account") {
        val existingUser = User(
            email = "taken@example.com",
            nickname = "ExistingUser",
            provider = AuthProvider.GOOGLE,
            providerId = "google-existing"
        )
        val user = User(
            email = "kakao_dup@no-email.local",
            nickname = "KakaoUser3",
            provider = AuthProvider.KAKAO,
            providerId = "dup"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { userRepository.findByEmail("taken@example.com") } returns existingUser

        When("updateProfile is called with the taken email") {
            val request = UpdateProfileRequest(email = "taken@example.com")

            Then("throws BusinessException with EMAIL_ALREADY_IN_USE") {
                val exception = shouldThrow<BusinessException> {
                    authService.updateProfile(user.id, request)
                }
                exception.code shouldBe "EMAIL_ALREADY_IN_USE"
            }
        }
    }

    Given("a user updating email to their own current email") {
        val user = User(
            email = "mine@example.com",
            nickname = "SameEmailUser",
            provider = AuthProvider.GOOGLE,
            providerId = "google-same"
        )

        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { userRepository.findByEmail("mine@example.com") } returns user
        every { userRepository.save(any()) } returnsArgument 0
        every { coupleRepository.findByUserIdAndStatus(user.id, CoupleStatus.ACTIVE) } returns null

        When("updateProfile is called with the same email") {
            val request = UpdateProfileRequest(email = "mine@example.com")
            val result = authService.updateProfile(user.id, request)

            Then("succeeds (same-user idempotent update)") {
                result.email shouldBe "mine@example.com"
            }
        }
    }
})
