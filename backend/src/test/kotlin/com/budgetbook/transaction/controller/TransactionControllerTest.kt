package com.budgetbook.transaction.controller

import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.transaction.dto.CreateTransactionRequest
import com.budgetbook.transaction.dto.PageResponse
import com.budgetbook.transaction.dto.TransactionResponse
import com.budgetbook.transaction.dto.UpdateTransactionRequest
import com.budgetbook.transaction.service.TransactionService
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

class TransactionControllerTest : FunSpec({

    val transactionService = mockk<TransactionService>()
    val controller = TransactionController(transactionService)
    val testUserId = UUID.randomUUID()

    fun createAuth(userId: UUID): Authentication =
        UsernamePasswordAuthenticationToken(userId, null, emptyList())

    fun sampleTransactionResponse() = TransactionResponse(
        id = UUID.randomUUID(),
        coupleId = UUID.randomUUID(),
        author = UserSummary(testUserId, "User", null),
        category = null,
        type = "EXPENSE",
        amount = 15000,
        description = "Test",
        memo = null,
        transactionDate = LocalDate.of(2024, 1, 15),
        paymentMethodId = null,
        paymentMethodName = null,
        paymentMethodType = null,
        settlementDate = null,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("listTransactions returns paginated results") {
        val auth = createAuth(testUserId)
        val pageResponse = PageResponse(
            content = listOf(sampleTransactionResponse()),
            page = 0, size = 20, totalElements = 1, totalPages = 1, first = true, last = true
        )
        every { transactionService.listTransactions(testUserId, 2024, 1, null, null, 0, 20) } returns pageResponse

        val result = controller.listTransactions(auth, 2024, 1, null, null, 0, 20)

        result.success shouldBe true
        result.data!!.totalElements shouldBe 1
    }

    test("createTransaction returns 201") {
        val auth = createAuth(testUserId)
        val request = CreateTransactionRequest(
            type = "EXPENSE", amount = 15000, description = "점심",
            transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionService.createTransaction(testUserId, request) } returns sampleTransactionResponse()

        val result = controller.createTransaction(auth, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
    }

    test("getTransaction returns transaction") {
        val auth = createAuth(testUserId)
        val txId = UUID.randomUUID()
        every { transactionService.getTransaction(testUserId, txId) } returns sampleTransactionResponse()

        val result = controller.getTransaction(auth, txId)

        result.success shouldBe true
        result.data!!.type shouldBe "EXPENSE"
    }

    test("updateTransaction returns updated transaction") {
        val auth = createAuth(testUserId)
        val txId = UUID.randomUUID()
        val request = UpdateTransactionRequest(amount = 18000)
        every { transactionService.updateTransaction(testUserId, txId, request) } returns sampleTransactionResponse()

        val result = controller.updateTransaction(auth, txId, request)

        result.success shouldBe true
    }

    test("deleteTransaction returns 204") {
        val auth = createAuth(testUserId)
        val txId = UUID.randomUUID()
        justRun { transactionService.deleteTransaction(testUserId, txId) }

        val result = controller.deleteTransaction(auth, txId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { transactionService.deleteTransaction(testUserId, txId) }
    }
})
