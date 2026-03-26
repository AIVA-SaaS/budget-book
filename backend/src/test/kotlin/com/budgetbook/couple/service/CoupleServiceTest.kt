package com.budgetbook.couple.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.service.CategoryGroupService
import com.budgetbook.category.service.CategoryService
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.paymentmethod.service.PaymentMethodService
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.GoneException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleInvitation
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.domain.InvitationStatus
import com.budgetbook.couple.repository.CoupleInvitationRepository
import com.budgetbook.couple.repository.CoupleRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.kotest.matchers.string.shouldHaveLength
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.time.Instant
import java.util.Optional
import java.util.UUID

class CoupleServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val coupleRepository = mockk<CoupleRepository>()
    val coupleInvitationRepository = mockk<CoupleInvitationRepository>()
    val userRepository = mockk<UserRepository>()
    val categoryService = mockk<CategoryService>(relaxed = true)
    val categoryGroupService = mockk<CategoryGroupService>(relaxed = true)
    val paymentMethodService = mockk<PaymentMethodService>(relaxed = true)
    val redisCacheService = mockk<RedisCacheService>(relaxed = true)
    val coupleService = CoupleService(coupleRepository, coupleInvitationRepository, userRepository, categoryService, categoryGroupService, paymentMethodService, redisCacheService)

    val user1 = User(
        email = "user1@example.com",
        nickname = "User1",
        provider = AuthProvider.GOOGLE,
        providerId = "google-1"
    )

    val user2 = User(
        email = "user2@example.com",
        nickname = "User2",
        profileImageUrl = "https://example.com/photo2.jpg",
        provider = AuthProvider.KAKAO,
        providerId = "kakao-2"
    )

    // --- createInvitation ---

    Given("a user not in an active couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null
        every { coupleInvitationRepository.updateStatusByInviterIdAndStatus(user1.id, InvitationStatus.PENDING, InvitationStatus.CANCELLED) } returns Unit
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        val invitationSlot = slot<CoupleInvitation>()
        every { coupleInvitationRepository.save(capture(invitationSlot)) } answers { invitationSlot.captured }

        When("createInvitation is called") {
            val result = coupleService.createInvitation(user1.id)

            Then("returns an 8-char invitation code with 24h expiry") {
                result.code shouldHaveLength 8
                result.expiresAt.isAfter(Instant.now()) shouldBe true
            }

            Then("cancels previous pending invitations") {
                verify { coupleInvitationRepository.updateStatusByInviterIdAndStatus(user1.id, InvitationStatus.PENDING, InvitationStatus.CANCELLED) }
            }
        }
    }

    Given("a user already in an active couple") {
        val existingCouple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns existingCouple

        When("createInvitation is called") {
            Then("throws ConflictException") {
                val ex = shouldThrow<ConflictException> {
                    coupleService.createInvitation(user1.id)
                }
                ex.code shouldBe "COUPLE_ALREADY_EXISTS"
            }
        }
    }

    // --- acceptInvitation ---

    Given("a valid pending invitation code") {
        val invitation = CoupleInvitation(
            inviter = user1,
            invitationCode = "ABCD1234",
            expiresAt = Instant.now().plusSeconds(3600)
        )

        every { coupleInvitationRepository.findByInvitationCode("ABCD1234") } returns invitation
        every { userRepository.findById(user2.id) } returns Optional.of(user2)
        every { coupleRepository.findByUserIdAndStatus(user2.id, CoupleStatus.ACTIVE) } returns null
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null
        every { coupleInvitationRepository.save(invitation) } returns invitation

        val coupleSlot = slot<Couple>()
        every { coupleRepository.save(capture(coupleSlot)) } answers { coupleSlot.captured }

        When("acceptInvitation is called by a different user") {
            val result = coupleService.acceptInvitation(user2.id, "ABCD1234")

            Then("creates an active couple and returns CoupleResponse") {
                result.status shouldBe "ACTIVE"
                result.partner.id shouldBe user1.id
                result.partner.nickname shouldBe "User1"
            }

            Then("marks invitation as accepted") {
                invitation.status shouldBe InvitationStatus.ACCEPTED
            }

            Then("seeds default categories, category groups, and payment methods") {
                verify(exactly = 1) { categoryService.seedDefaultCategories(any()) }
                verify(exactly = 1) { categoryGroupService.seedDefaultCategoryGroups(any()) }
                verify(exactly = 1) { paymentMethodService.seedDefaultPaymentMethods(any()) }
            }
        }
    }

    Given("an invitation code that does not exist") {
        every { coupleInvitationRepository.findByInvitationCode("INVALID1") } returns null

        When("acceptInvitation is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    coupleService.acceptInvitation(user2.id, "INVALID1")
                }
                ex.code shouldBe "INVITATION_NOT_FOUND"
            }
        }
    }

    Given("an expired invitation code") {
        val invitation = CoupleInvitation(
            inviter = user1,
            invitationCode = "EXPRD123",
            expiresAt = Instant.now().minusSeconds(3600)
        )
        every { coupleInvitationRepository.findByInvitationCode("EXPRD123") } returns invitation
        every { coupleInvitationRepository.save(invitation) } returns invitation

        When("acceptInvitation is called") {
            Then("throws GoneException and marks invitation as expired") {
                val ex = shouldThrow<GoneException> {
                    coupleService.acceptInvitation(user2.id, "EXPRD123")
                }
                ex.code shouldBe "INVITATION_EXPIRED"
                invitation.status shouldBe InvitationStatus.EXPIRED
            }
        }
    }

    Given("a user trying to accept their own invitation") {
        val invitation = CoupleInvitation(
            inviter = user1,
            invitationCode = "SELF1234",
            expiresAt = Instant.now().plusSeconds(3600)
        )
        every { coupleInvitationRepository.findByInvitationCode("SELF1234") } returns invitation

        When("acceptInvitation is called with the inviter's userId") {
            Then("throws BusinessException with SELF_INVITATION") {
                val ex = shouldThrow<BusinessException> {
                    coupleService.acceptInvitation(user1.id, "SELF1234")
                }
                ex.code shouldBe "SELF_INVITATION"
            }
        }
    }

    Given("a user already in a couple trying to accept an invitation") {
        val invitation = CoupleInvitation(
            inviter = user1,
            invitationCode = "DUPE1234",
            expiresAt = Instant.now().plusSeconds(3600)
        )
        val existingCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)

        every { coupleInvitationRepository.findByInvitationCode("DUPE1234") } returns invitation
        every { userRepository.findById(user2.id) } returns Optional.of(user2)
        every { coupleRepository.findByUserIdAndStatus(user2.id, CoupleStatus.ACTIVE) } returns existingCouple

        When("acceptInvitation is called") {
            Then("throws ConflictException") {
                val ex = shouldThrow<ConflictException> {
                    coupleService.acceptInvitation(user2.id, "DUPE1234")
                }
                ex.code shouldBe "COUPLE_ALREADY_EXISTS"
            }
        }
    }

    Given("a valid invitation where seed fails") {
        val invitation = CoupleInvitation(
            inviter = user1,
            invitationCode = "SEED1234",
            expiresAt = Instant.now().plusSeconds(3600)
        )

        every { coupleInvitationRepository.findByInvitationCode("SEED1234") } returns invitation
        every { userRepository.findById(user2.id) } returns Optional.of(user2)
        every { coupleRepository.findByUserIdAndStatus(user2.id, CoupleStatus.ACTIVE) } returns null
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null
        every { coupleInvitationRepository.save(invitation) } returns invitation

        val coupleSlot = slot<Couple>()
        every { coupleRepository.save(capture(coupleSlot)) } answers { coupleSlot.captured }

        // categoryService.seedDefaultCategories throws an exception
        every { categoryService.seedDefaultCategories(any()) } throws RuntimeException("DB error during seed")

        When("acceptInvitation is called") {
            Then("throws RuntimeException so @Transactional can rollback") {
                shouldThrow<RuntimeException> {
                    coupleService.acceptInvitation(user2.id, "SEED1234")
                }.message shouldBe "DB error during seed"
            }
        }
    }

    // --- getMyCouple ---

    Given("a user in an active couple") {
        val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("getMyCouple is called") {
            val result = coupleService.getMyCouple(user1.id)

            Then("returns the couple info with partner details") {
                result.id shouldBe couple.id
                result.partner.id shouldBe user2.id
                result.partner.nickname shouldBe "User2"
                result.partner.profileImageUrl shouldBe "https://example.com/photo2.jpg"
                result.status shouldBe "ACTIVE"
            }
        }
    }

    Given("user2 in an active couple querying their partner") {
        val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
        every { coupleRepository.findByUserIdAndStatus(user2.id, CoupleStatus.ACTIVE) } returns couple

        When("getMyCouple is called by user2") {
            val result = coupleService.getMyCouple(user2.id)

            Then("returns user1 as the partner") {
                result.partner.id shouldBe user1.id
                result.partner.nickname shouldBe "User1"
            }
        }
    }

    Given("a user not in any couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("getMyCouple is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    coupleService.getMyCouple(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    // --- getMyInvitation ---

    Given("a user with a PENDING valid invitation") {
        val invitation = CoupleInvitation(
            inviter = user1,
            invitationCode = "PEND1234",
            expiresAt = Instant.now().plusSeconds(3600)
        )
        every { coupleInvitationRepository.findTopByInviterIdOrderByCreatedAtDesc(user1.id) } returns invitation

        When("getMyInvitation is called") {
            val result = coupleService.getMyInvitation(user1.id)

            Then("returns status PENDING with the invitation code") {
                result.code shouldBe "PEND1234"
                result.status shouldBe "PENDING"
                result.expiresAt shouldBe invitation.expiresAt
            }
        }
    }

    Given("a user with a PENDING but expired invitation") {
        val invitation = CoupleInvitation(
            inviter = user1,
            invitationCode = "EXPR1234",
            expiresAt = Instant.now().minusSeconds(3600)
        )
        every { coupleInvitationRepository.findTopByInviterIdOrderByCreatedAtDesc(user1.id) } returns invitation
        every { coupleInvitationRepository.save(invitation) } returns invitation

        When("getMyInvitation is called") {
            val result = coupleService.getMyInvitation(user1.id)

            Then("returns status EXPIRED and updates the DB") {
                result.code shouldBe "EXPR1234"
                result.status shouldBe "EXPIRED"
                invitation.status shouldBe InvitationStatus.EXPIRED
                verify { coupleInvitationRepository.save(invitation) }
            }
        }
    }

    Given("a user with an ACCEPTED invitation") {
        val invitation = CoupleInvitation(
            inviter = user1,
            invitationCode = "ACPT1234",
            expiresAt = Instant.now().plusSeconds(3600)
        ).apply { status = InvitationStatus.ACCEPTED }
        every { coupleInvitationRepository.findTopByInviterIdOrderByCreatedAtDesc(user1.id) } returns invitation

        When("getMyInvitation is called") {
            val result = coupleService.getMyInvitation(user1.id)

            Then("returns status ACCEPTED") {
                result.code shouldBe "ACPT1234"
                result.status shouldBe "ACCEPTED"
            }
        }
    }

    Given("a user with no invitations") {
        every { coupleInvitationRepository.findTopByInviterIdOrderByCreatedAtDesc(user1.id) } returns null

        When("getMyInvitation is called") {
            Then("throws NotFoundException with INVITATION_NOT_FOUND") {
                val ex = shouldThrow<NotFoundException> {
                    coupleService.getMyInvitation(user1.id)
                }
                ex.code shouldBe "INVITATION_NOT_FOUND"
            }
        }
    }

    // --- dissolveCouple ---

    Given("a user in an active couple wanting to dissolve") {
        val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { coupleRepository.save(couple) } returns couple

        When("dissolveCouple is called") {
            val beforeDissolve = Instant.now()
            coupleService.dissolveCouple(user1.id)

            Then("sets couple status to DISSOLVED") {
                couple.status shouldBe CoupleStatus.DISSOLVED
                verify { coupleRepository.save(couple) }
            }

            Then("sets dissolvedAt timestamp") {
                couple.dissolvedAt shouldNotBe null
                couple.dissolvedAt!!.isAfter(beforeDissolve.minusSeconds(1)) shouldBe true
                couple.dissolvedAt!!.isBefore(Instant.now().plusSeconds(1)) shouldBe true
            }
        }
    }

    Given("a user not in a couple trying to dissolve") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("dissolveCouple is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    coupleService.dissolveCouple(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }
})
