package com.budgetbook.pocket.controller

import com.budgetbook.pocket.dto.CreateTransferRequest
import com.budgetbook.pocket.dto.DistributeRequest
import com.budgetbook.pocket.dto.DistributeResponse
import com.budgetbook.pocket.dto.DistributionItem
import com.budgetbook.pocket.dto.DistributionResult
import com.budgetbook.pocket.dto.PocketSummary
import com.budgetbook.pocket.dto.PocketTransferResponse
import com.budgetbook.pocket.service.PocketTransferService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import org.springframework.http.HttpStatus
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

class PocketTransferControllerTest : FunSpec({

    val pocketTransferService = mockk<PocketTransferService>()
    val controller = PocketTransferController(pocketTransferService)
    val testUserId = UUID.randomUUID()

    fun sampleTransferResponse() = PocketTransferResponse(
        id = UUID.randomUUID(),
        fromPocket = PocketSummary(UUID.randomUUID(), "생활비"),
        toPocket = PocketSummary(UUID.randomUUID(), "저축"),
        amount = 100000,
        description = "이체",
        transferDate = LocalDate.of(2024, 3, 1),
        authorId = testUserId,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("listTransfers returns transfers") {

        val transfers = listOf(sampleTransferResponse())
        every { pocketTransferService.getTransfers(testUserId) } returns transfers

        val result = controller.listTransfers(testUserId)

        result.success shouldBe true
        result.data!!.size shouldBe 1
    }

    test("createTransfer returns 201") {

        val request = CreateTransferRequest(
            fromPocketId = UUID.randomUUID(),
            toPocketId = UUID.randomUUID(),
            amount = 50000,
            transferDate = LocalDate.of(2024, 3, 1)
        )
        every { pocketTransferService.createTransfer(testUserId, request) } returns sampleTransferResponse()

        val result = controller.createTransfer(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
    }

    test("distribute returns distribution results") {

        val request = DistributeRequest(
            totalAmount = 3000000,
            distributions = listOf(
                DistributionItem(pocketId = UUID.randomUUID(), amount = 2000000),
                DistributionItem(pocketId = UUID.randomUUID(), amount = 1000000)
            )
        )
        val response = DistributeResponse(
            distributions = listOf(
                DistributionResult(UUID.randomUUID(), "생활비", 2000000),
                DistributionResult(UUID.randomUUID(), "저축", 1000000)
            ),
            totalDistributed = 3000000
        )
        every { pocketTransferService.distribute(testUserId, request) } returns response

        val result = controller.distribute(testUserId, request)

        result.success shouldBe true
        result.data!!.totalDistributed shouldBe 3000000
        result.data!!.distributions.size shouldBe 2
    }
})
