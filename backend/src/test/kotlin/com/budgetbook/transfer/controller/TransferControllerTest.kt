package com.budgetbook.transfer.controller

import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.transfer.dto.CreateTransferRequest
import com.budgetbook.transfer.dto.PaymentMethodSummary
import com.budgetbook.transfer.dto.TransferResponse
import com.budgetbook.transfer.dto.UpdateTransferRequest
import com.budgetbook.transfer.service.TransferService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

class TransferControllerTest : FunSpec({

    val transferService = mockk<TransferService>()
    val controller = TransferController(transferService)
    val testUserId = UUID.randomUUID()

    fun sampleTransferResponse() = TransferResponse(
        id = UUID.randomUUID(),
        coupleId = UUID.randomUUID(),
        author = UserSummary(testUserId, "User", null),
        sourcePaymentMethod = PaymentMethodSummary(UUID.randomUUID(), "신한은행", "BANK"),
        destinationPaymentMethod = PaymentMethodSummary(UUID.randomUUID(), "현금", "CASH"),
        amount = 100000,
        description = "ATM 출금",
        memo = null,
        transferDate = LocalDate.of(2026, 3, 25),
        kind = com.budgetbook.transfer.domain.TransferKind.GENERIC,
        createdAt = Instant.now()
    )

    test("createTransfer returns 201") {
        val request = CreateTransferRequest(
            sourcePaymentMethodId = UUID.randomUUID(),
            destinationPaymentMethodId = UUID.randomUUID(),
            amount = 100000,
            transferDate = LocalDate.of(2026, 3, 25)
        )
        every { transferService.createTransfer(testUserId, request) } returns sampleTransferResponse()

        val result = controller.createTransfer(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.amount shouldBe 100000
    }

    test("listTransfers returns transfer list") {
        val transfers = listOf(sampleTransferResponse())
        every { transferService.listTransfers(testUserId, 2026, 3) } returns transfers

        val result = controller.listTransfers(testUserId, 2026, 3)

        result.success shouldBe true
        result.data!!.size shouldBe 1
    }

    test("getTransfer returns single transfer") {
        val transferId = UUID.randomUUID()
        every { transferService.getTransfer(testUserId, transferId) } returns sampleTransferResponse()

        val result = controller.getTransfer(testUserId, transferId)

        result.success shouldBe true
        result.data!!.amount shouldBe 100000
    }

    test("updateTransfer returns updated transfer") {
        val transferId = UUID.randomUUID()
        val request = UpdateTransferRequest(amount = 200000)
        every { transferService.updateTransfer(testUserId, transferId, request) } returns sampleTransferResponse()

        val result = controller.updateTransfer(testUserId, transferId, request)

        result.success shouldBe true
    }

    test("deleteTransfer returns 204") {
        val transferId = UUID.randomUUID()
        justRun { transferService.deleteTransfer(testUserId, transferId) }

        val result = controller.deleteTransfer(testUserId, transferId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify { transferService.deleteTransfer(testUserId, transferId) }
    }
})
