package com.budgetbook.couple.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify

class CoupleResolverTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val coupleRepository = mockk<CoupleRepository>()
    val resolver = CoupleResolver(coupleRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    Given("a user in an active couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("getActiveCouple is called") {
            val result = resolver.getActiveCouple(user1.id)

            Then("returns the couple") {
                result shouldBe couple
            }
        }

        When("getActiveCouple is called twice for the same user") {
            resolver.getActiveCouple(user1.id)
            resolver.getActiveCouple(user1.id)

            Then("queries the repository only once (request-scoped cache)") {
                verify(exactly = 1) { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) }
            }
        }
    }

    Given("a user not in any active couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("getActiveCouple is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    resolver.getActiveCouple(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }

        When("getActiveCoupleOrNull is called") {
            val result = resolver.getActiveCoupleOrNull(user1.id)

            Then("returns null") {
                result shouldBe null
            }
        }
    }

    Given("a user in an active couple using getActiveCoupleOrNull") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("getActiveCoupleOrNull is called") {
            val result = resolver.getActiveCoupleOrNull(user1.id)

            Then("returns the couple") {
                result shouldBe couple
            }
        }

        When("getActiveCoupleOrNull then getActiveCouple is called") {
            resolver.getActiveCoupleOrNull(user1.id)
            resolver.getActiveCouple(user1.id)

            Then("queries the repository only once (cached from first call)") {
                verify(exactly = 1) { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) }
            }
        }
    }
})
