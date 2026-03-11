package com.budgetbook.recurring.controller

import com.budgetbook.recurring.dto.CreateRecurringTransactionRequest
import com.budgetbook.recurring.dto.RecurringTransactionResponse
import com.budgetbook.recurring.dto.UpdateRecurringTransactionRequest
import com.budgetbook.recurring.service.RecurringTransactionService
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

class RecurringTransactionControllerTest : FunSpec({

    val service = mockk<RecurringTransactionService>()
    val controller = RecurringTransactionController(service)
    val testUserId = UUID.randomUUID()

    fun createAuth(userId: UUID): Authentication =
        UsernamePasswordAuthenticationToken(userId, null, emptyList())

    fun sampleResponse() = RecurringTransactionResponse(
        id = UUID.randomUUID(),
        coupleId = UUID.randomUUID(),
        authorId = testUserId,
        type = "EXPENSE",
        amount = 50000,
        description = "월세",
        memo = null,
        frequency = "MONTHLY",
        dayOfMonth = 25,
        dayOfWeek = null,
        nextRunDate = "2026-04-25",
        lastRunDate = null,
        isActive = true,
        category = null,
        paymentMethodId = null,
        paymentMethodName = null,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("listRecurringTransactions returns list") {
        val auth = createAuth(testUserId)
        every { service.listRecurringTransactions(testUserId) } returns listOf(sampleResponse())

        val result = controller.listRecurringTransactions(auth)

        result.success shouldBe true
        result.data!!.size shouldBe 1
        result.data!![0].description shouldBe "월세"
    }

    test("createRecurringTransaction returns 201") {
        val auth = createAuth(testUserId)
        val request = CreateRecurringTransactionRequest(
            type = "EXPENSE",
            amount = 50000,
            description = "월세",
            frequency = "MONTHLY",
            dayOfMonth = 25
        )
        every { service.createRecurringTransaction(testUserId, request) } returns sampleResponse()

        val result = controller.createRecurringTransaction(auth, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.amount shouldBe 50000
    }

    test("updateRecurringTransaction returns updated result") {
        val auth = createAuth(testUserId)
        val id = UUID.randomUUID()
        val request = UpdateRecurringTransactionRequest(amount = 55000)
        val response = sampleResponse().copy(amount = 55000)
        every { service.updateRecurringTransaction(testUserId, id, request) } returns response

        val result = controller.updateRecurringTransaction(auth, id, request)

        result.success shouldBe true
        result.data!!.amount shouldBe 55000
    }

    test("deleteRecurringTransaction returns 204") {
        val auth = createAuth(testUserId)
        val id = UUID.randomUUID()
        justRun { service.deleteRecurringTransaction(testUserId, id) }

        val result = controller.deleteRecurringTransaction(auth, id)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { service.deleteRecurringTransaction(testUserId, id) }
    }
})
