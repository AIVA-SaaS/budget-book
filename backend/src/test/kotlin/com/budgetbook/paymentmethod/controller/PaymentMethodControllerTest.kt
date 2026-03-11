package com.budgetbook.paymentmethod.controller

import com.budgetbook.paymentmethod.dto.CardPendingResponse
import com.budgetbook.paymentmethod.dto.CreatePaymentMethodRequest
import com.budgetbook.paymentmethod.dto.PaymentMethodResponse
import com.budgetbook.paymentmethod.dto.UpdatePaymentMethodRequest
import com.budgetbook.paymentmethod.service.PaymentMethodService
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
import java.time.LocalDate
import java.util.UUID

class PaymentMethodControllerTest : FunSpec({

    val paymentMethodService = mockk<PaymentMethodService>()
    val controller = PaymentMethodController(paymentMethodService)
    val testUserId = UUID.randomUUID()

    fun createAuth(userId: UUID): Authentication =
        UsernamePasswordAuthenticationToken(userId, null, emptyList())

    fun sampleResponse() = PaymentMethodResponse(
        id = UUID.randomUUID(),
        name = "현금",
        type = "CASH",
        settlementDay = null,
        closingDay = null,
        isActive = true,
        isDefault = true,
        displayOrder = 0,
        createdAt = Instant.now()
    )

    test("listPaymentMethods returns list") {
        val auth = createAuth(testUserId)
        val methods = listOf(sampleResponse())
        every { paymentMethodService.listPaymentMethods(testUserId) } returns methods

        val result = controller.listPaymentMethods(auth)

        result.success shouldBe true
        result.data!!.size shouldBe 1
        result.data!![0].name shouldBe "현금"
    }

    test("createPaymentMethod returns 201") {
        val auth = createAuth(testUserId)
        val request = CreatePaymentMethodRequest(name = "신한카드", type = "CREDIT", settlementDay = 15, closingDay = 25)
        val response = PaymentMethodResponse(
            id = UUID.randomUUID(),
            name = "신한카드",
            type = "CREDIT",
            settlementDay = 15,
            closingDay = 25,
            isActive = true,
            isDefault = false,
            displayOrder = 0,
            createdAt = Instant.now()
        )
        every { paymentMethodService.createPaymentMethod(testUserId, request) } returns response

        val result = controller.createPaymentMethod(auth, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.name shouldBe "신한카드"
    }

    test("updatePaymentMethod returns updated method") {
        val auth = createAuth(testUserId)
        val methodId = UUID.randomUUID()
        val request = UpdatePaymentMethodRequest(name = "생활비 현금")
        val response = sampleResponse().copy(name = "생활비 현금")
        every { paymentMethodService.updatePaymentMethod(testUserId, methodId, request) } returns response

        val result = controller.updatePaymentMethod(auth, methodId, request)

        result.success shouldBe true
        result.data!!.name shouldBe "생활비 현금"
    }

    test("deletePaymentMethod returns 204") {
        val auth = createAuth(testUserId)
        val methodId = UUID.randomUUID()
        justRun { paymentMethodService.deletePaymentMethod(testUserId, methodId) }

        val result = controller.deletePaymentMethod(auth, methodId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { paymentMethodService.deletePaymentMethod(testUserId, methodId) }
    }

    test("getCardPendingSummary returns card pending data") {
        val auth = createAuth(testUserId)
        val cardResponse = PaymentMethodResponse(
            id = UUID.randomUUID(),
            name = "신한카드",
            type = "CREDIT",
            settlementDay = 15,
            closingDay = 25,
            isActive = true,
            isDefault = false,
            displayOrder = 0,
            createdAt = Instant.now()
        )
        val pendingResponse = CardPendingResponse(
            paymentMethod = cardResponse,
            pendingAmount = 250000,
            settlementDate = LocalDate.of(2024, 4, 15),
            transactionCount = 5
        )
        every { paymentMethodService.getCardPendingSummary(testUserId, 2024, 4) } returns listOf(pendingResponse)

        val result = controller.getCardPendingSummary(auth, 2024, 4)

        result.success shouldBe true
        result.data!!.size shouldBe 1
        result.data!![0].pendingAmount shouldBe 250000
        result.data!![0].transactionCount shouldBe 5
    }
})
