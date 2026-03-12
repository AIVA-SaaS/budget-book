package com.budgetbook.auth.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.util.Optional
import java.util.UUID

class UserCacheServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val userRepository = mockk<UserRepository>()
    val userCacheService = UserCacheService(userRepository)

    val testUser = User(
        email = "test@example.com",
        nickname = "TestUser",
        provider = AuthProvider.GOOGLE,
        providerId = "google-123"
    )

    Given("a user exists in the database") {
        every { userRepository.findById(testUser.id) } returns Optional.of(testUser)

        When("findById is called the first time") {
            val result = userCacheService.findById(testUser.id)

            Then("returns the user from DB") {
                result shouldBe testUser
                verify(exactly = 1) { userRepository.findById(testUser.id) }
            }
        }

        When("findById is called twice") {
            userCacheService.findById(testUser.id)
            val secondResult = userCacheService.findById(testUser.id)

            Then("returns cached user without second DB call") {
                secondResult shouldBe testUser
                verify(exactly = 1) { userRepository.findById(testUser.id) }
            }
        }
    }

    Given("a user does not exist in the database") {
        val unknownId = UUID.randomUUID()
        every { userRepository.findById(unknownId) } returns Optional.empty()

        When("findById is called") {
            val result = userCacheService.findById(unknownId)

            Then("returns null") {
                result.shouldBeNull()
            }
        }
    }

    Given("a cached user entry") {
        every { userRepository.findById(testUser.id) } returns Optional.of(testUser)
        userCacheService.findById(testUser.id) // populate cache

        When("evict is called and then findById again") {
            userCacheService.evict(testUser.id)
            userCacheService.findById(testUser.id)

            Then("hits the DB again after eviction") {
                verify(exactly = 2) { userRepository.findById(testUser.id) }
            }
        }
    }

    Given("multiple cached entries") {
        val user2 = User(
            email = "user2@example.com",
            nickname = "User2",
            provider = AuthProvider.KAKAO,
            providerId = "kakao-456"
        )
        every { userRepository.findById(testUser.id) } returns Optional.of(testUser)
        every { userRepository.findById(user2.id) } returns Optional.of(user2)

        userCacheService.findById(testUser.id)
        userCacheService.findById(user2.id)

        When("evictAll is called") {
            userCacheService.evictAll()
            userCacheService.findById(testUser.id)
            userCacheService.findById(user2.id)

            Then("both entries require fresh DB lookups") {
                verify(exactly = 2) { userRepository.findById(testUser.id) }
                verify(exactly = 2) { userRepository.findById(user2.id) }
            }
        }
    }
})
