package com.budgetbook.pocket.controller

import com.budgetbook.pocket.dto.CreatePocketRequest
import com.budgetbook.pocket.dto.PocketResponse
import com.budgetbook.pocket.dto.UpdatePocketRequest
import com.budgetbook.pocket.service.MoneyPocketService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.Authentication
import java.time.Instant
import java.util.UUID

class MoneyPocketControllerTest : FunSpec({

    val moneyPocketService = mockk<MoneyPocketService>()
    val controller = MoneyPocketController(moneyPocketService)
    val testUserId = UUID.randomUUID()

    fun createAuth(userId: UUID): Authentication =
        UsernamePasswordAuthenticationToken(userId, null, emptyList())

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
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("listPockets returns all active pockets") {
        val auth = createAuth(testUserId)
        val pockets = listOf(samplePocketResponse("생활비"), samplePocketResponse("저축"))
        every { moneyPocketService.getPockets(testUserId) } returns pockets

        val result = controller.listPockets(auth)

        result.success shouldBe true
        result.data!!.size shouldBe 2
    }

    test("createPocket returns 201") {
        val auth = createAuth(testUserId)
        val request = CreatePocketRequest(
            name = "생활비",
            type = "LIVING",
            allocatedAmount = 500000,
            icon = "wallet",
            color = "#FF5733"
        )
        every { moneyPocketService.createPocket(testUserId, request) } returns samplePocketResponse()

        val result = controller.createPocket(auth, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.name shouldBe "생활비"
    }

    test("updatePocket returns updated pocket") {
        val auth = createAuth(testUserId)
        val pocketId = UUID.randomUUID()
        val request = UpdatePocketRequest(name = "생활비(수정)", allocatedAmount = 600000)
        every { moneyPocketService.updatePocket(testUserId, pocketId, request) } returns samplePocketResponse("생활비(수정)")

        val result = controller.updatePocket(auth, pocketId, request)

        result.success shouldBe true
    }

    test("deletePocket returns 204") {
        val auth = createAuth(testUserId)
        val pocketId = UUID.randomUUID()
        justRun { moneyPocketService.deletePocket(testUserId, pocketId) }

        val result = controller.deletePocket(auth, pocketId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { moneyPocketService.deletePocket(testUserId, pocketId) }
    }
})
