package com.budgetbook.auth.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import org.springframework.context.ApplicationEventPublisher
import org.springframework.security.oauth2.core.OAuth2AuthenticationException

class CustomOAuth2UserServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val userRepository = mockk<UserRepository>()
    val eventPublisher = mockk<ApplicationEventPublisher>(relaxed = true)
    val service = CustomOAuth2UserService(userRepository, eventPublisher)

    // --- findOrCreateUser (the core logic being tested) ---

    Given("a new Google user (no existing provider or email match)") {
        every { userRepository.findByProviderAndProviderId(AuthProvider.GOOGLE, "google-id-123") } returns null
        every { userRepository.findByEmail("user@gmail.com") } returns null

        val userSlot = slot<User>()
        every { userRepository.save(capture(userSlot)) } answers { userSlot.captured }

        val userInfo = CustomOAuth2UserService.OAuth2UserInfo(
            providerId = "google-id-123",
            email = "user@gmail.com",
            name = "Google User",
            profileImageUrl = "https://google.com/photo.jpg"
        )

        When("findOrCreateUser is called") {
            val result = service.findOrCreateUser(AuthProvider.GOOGLE, userInfo)

            Then("creates a new user with GOOGLE provider") {
                result.email shouldBe "user@gmail.com"
                result.nickname shouldBe "Google User"
                result.profileImageUrl shouldBe "https://google.com/photo.jpg"
                result.provider shouldBe AuthProvider.GOOGLE
                result.providerId shouldBe "google-id-123"
            }
        }
    }

    Given("a new Kakao user (no existing provider or email match)") {
        every { userRepository.findByProviderAndProviderId(AuthProvider.KAKAO, "12345678") } returns null
        every { userRepository.findByEmail("user@kakao.com") } returns null

        val userSlot = slot<User>()
        every { userRepository.save(capture(userSlot)) } answers { userSlot.captured }

        val userInfo = CustomOAuth2UserService.OAuth2UserInfo(
            providerId = "12345678",
            email = "user@kakao.com",
            name = "Kakao User",
            profileImageUrl = "https://kakao.com/photo.jpg"
        )

        When("findOrCreateUser is called") {
            val result = service.findOrCreateUser(AuthProvider.KAKAO, userInfo)

            Then("creates a new user with KAKAO provider") {
                result.email shouldBe "user@kakao.com"
                result.nickname shouldBe "Kakao User"
                result.profileImageUrl shouldBe "https://kakao.com/photo.jpg"
                result.provider shouldBe AuthProvider.KAKAO
                result.providerId shouldBe "12345678"
            }
        }
    }

    Given("a Kakao login with the same email as an existing Google user") {
        val existingGoogleUser = User(
            email = "shared@example.com",
            nickname = "Google Name",
            profileImageUrl = "https://google.com/photo.jpg",
            provider = AuthProvider.GOOGLE,
            providerId = "google-id-999"
        )

        every { userRepository.findByProviderAndProviderId(AuthProvider.KAKAO, "99999999") } returns null
        every { userRepository.findByEmail("shared@example.com") } returns existingGoogleUser

        val userInfo = CustomOAuth2UserService.OAuth2UserInfo(
            providerId = "99999999",
            email = "shared@example.com",
            name = "Kakao Name",
            profileImageUrl = "https://kakao.com/photo.jpg"
        )

        When("findOrCreateUser is called") {
            Then("throws OAuth2AuthenticationException instead of auto-linking") {
                val ex = shouldThrow<OAuth2AuthenticationException> {
                    service.findOrCreateUser(AuthProvider.KAKAO, userInfo)
                }
                ex.error.errorCode shouldBe "account_exists"
                ex.error.description shouldContain "GOOGLE"
            }
        }
    }

    Given("an existing Google user logging in again with same provider") {
        val existingUser = User(
            email = "existing@gmail.com",
            nickname = "Old Nickname",
            profileImageUrl = "https://old-photo.jpg",
            provider = AuthProvider.GOOGLE,
            providerId = "existing-google-id"
        )

        every { userRepository.findByProviderAndProviderId(AuthProvider.GOOGLE, "existing-google-id") } returns existingUser
        every { userRepository.save(existingUser) } returns existingUser

        val userInfo = CustomOAuth2UserService.OAuth2UserInfo(
            providerId = "existing-google-id",
            email = "existing@gmail.com",
            name = "New Nickname",
            profileImageUrl = "https://new-photo.jpg"
        )

        When("findOrCreateUser is called") {
            val result = service.findOrCreateUser(AuthProvider.GOOGLE, userInfo)

            Then("updates nickname and profile image of existing user") {
                result.nickname shouldBe "New Nickname"
                result.profileImageUrl shouldBe "https://new-photo.jpg"
                result.provider shouldBe AuthProvider.GOOGLE
            }
        }
    }

    Given("a Google login with email already registered with Kakao") {
        val existingKakaoUser = User(
            email = "dual@example.com",
            nickname = "Kakao User",
            provider = AuthProvider.KAKAO,
            providerId = "kakao-id-111"
        )

        every { userRepository.findByProviderAndProviderId(AuthProvider.GOOGLE, "google-new-id") } returns null
        every { userRepository.findByEmail("dual@example.com") } returns existingKakaoUser

        val userInfo = CustomOAuth2UserService.OAuth2UserInfo(
            providerId = "google-new-id",
            email = "dual@example.com",
            name = "Google Name",
            profileImageUrl = null
        )

        When("findOrCreateUser is called") {
            Then("throws OAuth2AuthenticationException mentioning KAKAO provider") {
                val ex = shouldThrow<OAuth2AuthenticationException> {
                    service.findOrCreateUser(AuthProvider.GOOGLE, userInfo)
                }
                ex.error.errorCode shouldBe "account_exists"
                ex.error.description shouldContain "KAKAO"
            }
        }
    }
})
