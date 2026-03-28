package com.budgetbook.preference.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.preference.domain.CouplePreference
import com.budgetbook.preference.dto.FavoriteToggleRequest
import com.budgetbook.preference.dto.FavoritesRequest
import com.budgetbook.preference.repository.CouplePreferenceRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import java.util.UUID

class PreferenceServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val couplePreferenceRepository = mockk<CouplePreferenceRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val categoryRepository = mockk<CategoryRepository>()
    val paymentMethodRepository = mockk<PaymentMethodRepository>()

    val service = PreferenceService(
        couplePreferenceRepository, coupleResolver, categoryRepository, paymentMethodRepository
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    val catId1 = UUID.randomUUID()
    val catId2 = UUID.randomUUID()
    val pmId1 = UUID.randomUUID()

    // --- getFavorites ---

    Given("getFavorites") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("no preference row exists") {
            every { couplePreferenceRepository.findByCoupleId(couple.id) } returns null

            Then("returns empty arrays") {
                val result = service.getFavorites(user1.id)
                result.categoryIds.shouldBeEmpty()
                result.paymentMethodIds.shouldBeEmpty()
            }
        }

        When("preference row exists with data") {
            val pref = CouplePreference(
                couple = couple,
                favoriteCategoryIds = listOf(catId1, catId2),
                favoritePaymentMethodIds = listOf(pmId1)
            )
            every { couplePreferenceRepository.findByCoupleId(couple.id) } returns pref

            Then("returns the stored favorites") {
                val result = service.getFavorites(user1.id)
                result.categoryIds shouldContainExactly listOf(catId1, catId2)
                result.paymentMethodIds shouldContainExactly listOf(pmId1)
            }
        }

        When("user is not in an active couple") {
            every { coupleResolver.getActiveCouple(user1.id) } throws
                NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.getFavorites(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    // --- updateFavorites ---

    Given("updateFavorites") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("no preference row exists yet (upsert)") {
            every { couplePreferenceRepository.findByCoupleId(couple.id) } returns null
            val prefSlot = slot<CouplePreference>()
            every { couplePreferenceRepository.save(capture(prefSlot)) } answers { prefSlot.captured }

            val request = FavoritesRequest(
                categoryIds = listOf(catId1),
                paymentMethodIds = listOf(pmId1)
            )
            val result = service.updateFavorites(user1.id, request)

            Then("creates new preference with given favorites") {
                result.categoryIds shouldContainExactly listOf(catId1)
                result.paymentMethodIds shouldContainExactly listOf(pmId1)
            }
        }

        When("preference row already exists") {
            val existing = CouplePreference(
                couple = couple,
                favoriteCategoryIds = listOf(catId1),
                favoritePaymentMethodIds = listOf(pmId1)
            )
            every { couplePreferenceRepository.findByCoupleId(couple.id) } returns existing
            val prefSlot = slot<CouplePreference>()
            every { couplePreferenceRepository.save(capture(prefSlot)) } answers { prefSlot.captured }

            val request = FavoritesRequest(
                categoryIds = listOf(catId2),
                paymentMethodIds = emptyList()
            )
            val result = service.updateFavorites(user1.id, request)

            Then("replaces all favorites") {
                result.categoryIds shouldContainExactly listOf(catId2)
                result.paymentMethodIds.shouldBeEmpty()
            }
        }
    }

    // --- toggleFavorite ---

    Given("toggleFavorite") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("toggling a category that is not yet favorited") {
            every { categoryRepository.existsById(catId1) } returns true
            val pref = CouplePreference(couple = couple, favoriteCategoryIds = emptyList())
            every { couplePreferenceRepository.findByCoupleId(couple.id) } returns pref
            val prefSlot = slot<CouplePreference>()
            every { couplePreferenceRepository.save(capture(prefSlot)) } answers { prefSlot.captured }

            val request = FavoriteToggleRequest(type = "CATEGORY", itemId = catId1)
            val result = service.toggleFavorite(user1.id, request)

            Then("adds the category to favorites") {
                result.categoryIds shouldContainExactly listOf(catId1)
            }
        }

        When("toggling a category that is already favorited") {
            every { categoryRepository.existsById(catId1) } returns true
            val pref = CouplePreference(couple = couple, favoriteCategoryIds = listOf(catId1, catId2))
            every { couplePreferenceRepository.findByCoupleId(couple.id) } returns pref
            val prefSlot = slot<CouplePreference>()
            every { couplePreferenceRepository.save(capture(prefSlot)) } answers { prefSlot.captured }

            val request = FavoriteToggleRequest(type = "CATEGORY", itemId = catId1)
            val result = service.toggleFavorite(user1.id, request)

            Then("removes the category from favorites") {
                result.categoryIds shouldContainExactly listOf(catId2)
            }
        }

        When("toggling a payment method") {
            every { paymentMethodRepository.existsById(pmId1) } returns true
            val pref = CouplePreference(couple = couple, favoritePaymentMethodIds = emptyList())
            every { couplePreferenceRepository.findByCoupleId(couple.id) } returns pref
            val prefSlot = slot<CouplePreference>()
            every { couplePreferenceRepository.save(capture(prefSlot)) } answers { prefSlot.captured }

            val request = FavoriteToggleRequest(type = "PAYMENT_METHOD", itemId = pmId1)
            val result = service.toggleFavorite(user1.id, request)

            Then("adds the payment method to favorites") {
                result.paymentMethodIds shouldContainExactly listOf(pmId1)
            }
        }

        When("toggling with invalid type") {
            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.toggleFavorite(user1.id, FavoriteToggleRequest(type = "INVALID", itemId = catId1))
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("toggling a non-existent category") {
            every { categoryRepository.existsById(catId1) } returns false

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.toggleFavorite(user1.id, FavoriteToggleRequest(type = "CATEGORY", itemId = catId1))
                }
                ex.code shouldBe "CATEGORY_NOT_FOUND"
            }
        }

        When("toggling a non-existent payment method") {
            every { paymentMethodRepository.existsById(pmId1) } returns false

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.toggleFavorite(user1.id, FavoriteToggleRequest(type = "PAYMENT_METHOD", itemId = pmId1))
                }
                ex.code shouldBe "PAYMENT_METHOD_NOT_FOUND"
            }
        }

        When("no preference row exists and toggling creates one") {
            every { categoryRepository.existsById(catId1) } returns true
            every { couplePreferenceRepository.findByCoupleId(couple.id) } returns null
            val prefSlot = slot<CouplePreference>()
            every { couplePreferenceRepository.save(capture(prefSlot)) } answers { prefSlot.captured }

            val request = FavoriteToggleRequest(type = "CATEGORY", itemId = catId1)
            val result = service.toggleFavorite(user1.id, request)

            Then("creates preference and adds the item") {
                result.categoryIds shouldContainExactly listOf(catId1)
                result.paymentMethodIds.shouldBeEmpty()
            }
        }
    }
})
