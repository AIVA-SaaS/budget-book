package com.budgetbook.preference.controller

import com.budgetbook.preference.dto.FavoriteToggleRequest
import com.budgetbook.preference.dto.FavoritesRequest
import com.budgetbook.preference.dto.FavoritesResponse
import com.budgetbook.preference.service.PreferenceService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldContainExactly
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.util.UUID

class PreferenceControllerTest : FunSpec({

    val preferenceService = mockk<PreferenceService>()
    val controller = PreferenceController(preferenceService)

    val testUserId = UUID.randomUUID()
    val catId1 = UUID.randomUUID()
    val pmId1 = UUID.randomUUID()

    test("getFavorites returns empty arrays when no preferences exist") {
        every { preferenceService.getFavorites(testUserId) } returns FavoritesResponse(emptyList(), emptyList())

        val result = controller.getFavorites(testUserId)

        result.success shouldBe true
        result.data!!.categoryIds.shouldBeEmpty()
        result.data!!.paymentMethodIds.shouldBeEmpty()
    }

    test("getFavorites returns stored favorites") {
        val response = FavoritesResponse(listOf(catId1), listOf(pmId1))
        every { preferenceService.getFavorites(testUserId) } returns response

        val result = controller.getFavorites(testUserId)

        result.success shouldBe true
        result.data!!.categoryIds shouldContainExactly listOf(catId1)
        result.data!!.paymentMethodIds shouldContainExactly listOf(pmId1)
    }

    test("updateFavorites replaces all favorites") {
        val request = FavoritesRequest(listOf(catId1), listOf(pmId1))
        val response = FavoritesResponse(listOf(catId1), listOf(pmId1))
        every { preferenceService.updateFavorites(testUserId, request) } returns response

        val result = controller.updateFavorites(testUserId, request)

        result.success shouldBe true
        result.data!!.categoryIds shouldContainExactly listOf(catId1)
    }

    test("toggleFavorite returns updated favorites") {
        val request = FavoriteToggleRequest(type = "CATEGORY", itemId = catId1)
        val response = FavoritesResponse(listOf(catId1), emptyList())
        every { preferenceService.toggleFavorite(testUserId, request) } returns response

        val result = controller.toggleFavorite(testUserId, request)

        result.success shouldBe true
        result.data!!.categoryIds shouldContainExactly listOf(catId1)
    }
})
