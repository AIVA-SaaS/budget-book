package com.budgetbook.pocket.controller

import com.budgetbook.pocket.dto.CreatePocketRequest
import com.budgetbook.pocket.dto.DistributionRatioResponse
import com.budgetbook.pocket.dto.PocketResponse
import com.budgetbook.pocket.dto.SaveDistributionRatiosRequest
import com.budgetbook.pocket.dto.RatioEntry
import com.budgetbook.pocket.dto.UpdatePocketRequest
import com.budgetbook.pocket.service.DistributionRatioService
import com.budgetbook.pocket.service.MoneyPocketService
import java.math.BigDecimal
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class MoneyPocketControllerTest : FunSpec({

    val moneyPocketService = mockk<MoneyPocketService>()
    val distributionRatioService = mockk<DistributionRatioService>()
    val controller = MoneyPocketController(moneyPocketService, distributionRatioService)
    val testUserId = UUID.randomUUID()

    fun samplePocketResponse(name: String = "생활비") = PocketResponse(
        id = UUID.randomUUID(),
        name = name,
        type = "LIVING",
        allocatedAmount = 500000,
        balance = 500000,
        icon = "wallet",
        color = "#FF5733",
        displayOrder = 1,
        isActive = true,
        goalAmount = null,
        targetDate = null,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("listPockets returns all active pockets") {

        val pockets = listOf(samplePocketResponse("생활비"), samplePocketResponse("저축"))
        every { moneyPocketService.getPockets(testUserId) } returns pockets

        val result = controller.listPockets(testUserId)

        result.success shouldBe true
        result.data!!.size shouldBe 2
    }

    test("createPocket returns 201") {

        val request = CreatePocketRequest(
            name = "생활비",
            type = "LIVING",
            allocatedAmount = 500000,
            icon = "wallet",
            color = "#FF5733"
        )
        every { moneyPocketService.createPocket(testUserId, request) } returns samplePocketResponse()

        val result = controller.createPocket(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.name shouldBe "생활비"
    }

    test("updatePocket returns updated pocket") {

        val pocketId = UUID.randomUUID()
        val request = UpdatePocketRequest(name = "생활비(수정)", allocatedAmount = 600000)
        every { moneyPocketService.updatePocket(testUserId, pocketId, request) } returns samplePocketResponse("생활비(수정)")

        val result = controller.updatePocket(testUserId, pocketId, request)

        result.success shouldBe true
    }

    test("deletePocket returns 204") {

        val pocketId = UUID.randomUUID()
        justRun { moneyPocketService.deletePocket(testUserId, pocketId) }

        val result = controller.deletePocket(testUserId, pocketId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { moneyPocketService.deletePocket(testUserId, pocketId) }
    }

    test("getDistributionRatios returns saved ratios") {

        val ratios = listOf(
            DistributionRatioResponse(UUID.randomUUID(), "생활비", BigDecimal("70.00")),
            DistributionRatioResponse(UUID.randomUUID(), "저축", BigDecimal("30.00"))
        )
        every { distributionRatioService.getRatios(testUserId) } returns ratios

        val result = controller.getDistributionRatios(testUserId)

        result.success shouldBe true
        result.data!!.size shouldBe 2
    }

    test("saveDistributionRatios replaces ratios") {

        val pocketId1 = UUID.randomUUID()
        val pocketId2 = UUID.randomUUID()
        val request = SaveDistributionRatiosRequest(
            ratios = listOf(
                RatioEntry(pocketId1, BigDecimal("60.00")),
                RatioEntry(pocketId2, BigDecimal("40.00"))
            )
        )
        val response = listOf(
            DistributionRatioResponse(pocketId1, "생활비", BigDecimal("60.00")),
            DistributionRatioResponse(pocketId2, "저축", BigDecimal("40.00"))
        )
        every { distributionRatioService.saveRatios(testUserId, request) } returns response

        val result = controller.saveDistributionRatios(testUserId, request)

        result.success shouldBe true
        result.data!!.size shouldBe 2
    }
})
