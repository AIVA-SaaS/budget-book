package com.budgetbook.transaction.controller

import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.transaction.dto.CreateTransactionRequest
import com.budgetbook.transaction.dto.PageResponse
import com.budgetbook.transaction.dto.SettlementTransactionItem
import com.budgetbook.transaction.dto.SettlementTransactionsResponse
import com.budgetbook.transaction.dto.TransactionResponse
import com.budgetbook.transaction.dto.SuggestionResponse
import com.budgetbook.transaction.dto.UpdateTransactionRequest
import com.budgetbook.transaction.service.TransactionExportService
import com.budgetbook.transaction.service.TransactionImportService
import com.budgetbook.transaction.service.TransactionService
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

class TransactionControllerTest : FunSpec({

    val transactionService = mockk<TransactionService>()
    val transactionExportService = mockk<TransactionExportService>()
    val transactionImportService = mockk<TransactionImportService>()
    val controller = TransactionController(transactionService, transactionExportService, transactionImportService)
    val testUserId = UUID.randomUUID()

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

        val pageResponse = PageResponse(
            content = listOf(sampleTransactionResponse()),
            page = 0, size = 20, totalElements = 1, totalPages = 1, first = true, last = true
        )
        every { transactionService.listTransactions(testUserId, 2024, 1, null, null, null, null, null, null, null, null, null, null, 0, 20) } returns pageResponse

        val filter = CommonFilterParams(year = 2024, month = 1)
        val result = controller.listTransactions(testUserId, filter, 0, 20)

        result.success shouldBe true
        result.data!!.totalElements shouldBe 1
    }

    test("listTransactions with keyword filter") {

        val pageResponse = PageResponse(
            content = listOf(sampleTransactionResponse()),
            page = 0, size = 20, totalElements = 1, totalPages = 1, first = true, last = true
        )
        every { transactionService.listTransactions(testUserId, 2024, 1, null, null, "점심", null, null, null, null, null, null, null, 0, 20) } returns pageResponse

        val filter = CommonFilterParams(year = 2024, month = 1, keyword = "점심")
        val result = controller.listTransactions(testUserId, filter, 0, 20)

        result.success shouldBe true
        result.data!!.totalElements shouldBe 1
    }

    test("listTransactions with amount range filter") {

        val pageResponse = PageResponse(
            content = listOf(sampleTransactionResponse()),
            page = 0, size = 20, totalElements = 1, totalPages = 1, first = true, last = true
        )
        every { transactionService.listTransactions(testUserId, 2024, 1, null, null, null, null, null, 10000, 50000, null, null, null, 0, 20) } returns pageResponse

        val filter = CommonFilterParams(year = 2024, month = 1, amountMin = 10000, amountMax = 50000)
        val result = controller.listTransactions(testUserId, filter, 0, 20)

        result.success shouldBe true
        result.data!!.totalElements shouldBe 1
    }

    test("listTransactions with dateFrom and dateTo filter") {

        val pageResponse = PageResponse(
            content = listOf(sampleTransactionResponse()),
            page = 0, size = 20, totalElements = 1, totalPages = 1, first = true, last = true
        )
        val from = LocalDate.of(2024, 1, 1)
        val to = LocalDate.of(2024, 3, 31)
        every { transactionService.listTransactions(testUserId, null, null, null, null, null, null, null, null, null, from, to, null, 0, 20) } returns pageResponse

        val filter = CommonFilterParams(dateFrom = from, dateTo = to)
        val result = controller.listTransactions(testUserId, filter, 0, 20)

        result.success shouldBe true
        result.data!!.totalElements shouldBe 1
    }

    test("listTransactions with dateFrom only") {

        val pageResponse = PageResponse(
            content = listOf(sampleTransactionResponse()),
            page = 0, size = 20, totalElements = 1, totalPages = 1, first = true, last = true
        )
        val from = LocalDate.of(2024, 1, 1)
        every { transactionService.listTransactions(testUserId, null, null, null, null, null, null, null, null, null, from, null, null, 0, 20) } returns pageResponse

        val filter = CommonFilterParams(dateFrom = from)
        val result = controller.listTransactions(testUserId, filter, 0, 20)

        result.success shouldBe true
        result.data!!.totalElements shouldBe 1
    }

    test("listTransactions forwards visibility='SHARED' from filter to service (P6)") {

        val pageResponse = PageResponse(
            content = listOf(sampleTransactionResponse()),
            page = 0, size = 20, totalElements = 1, totalPages = 1, first = true, last = true
        )
        every { transactionService.listTransactions(testUserId, 2024, 1, null, null, null, null, null, null, null, null, null, "SHARED", 0, 20) } returns pageResponse

        val filter = CommonFilterParams(year = 2024, month = 1, visibility = "SHARED")
        val result = controller.listTransactions(testUserId, filter, 0, 20)

        result.success shouldBe true
        verify(exactly = 1) {
            transactionService.listTransactions(testUserId, 2024, 1, null, null, null, null, null, null, null, null, null, "SHARED", 0, 20)
        }
    }

    test("listTransactions forwards visibility='PRIVATE' from filter to service (P6)") {

        val pageResponse = PageResponse(
            content = emptyList<TransactionResponse>(),
            page = 0, size = 20, totalElements = 0, totalPages = 0, first = true, last = true
        )
        every { transactionService.listTransactions(testUserId, 2024, 1, null, null, null, null, null, null, null, null, null, "PRIVATE", 0, 20) } returns pageResponse

        val filter = CommonFilterParams(year = 2024, month = 1, visibility = "PRIVATE")
        controller.listTransactions(testUserId, filter, 0, 20)

        verify(exactly = 1) {
            transactionService.listTransactions(testUserId, 2024, 1, null, null, null, null, null, null, null, null, null, "PRIVATE", 0, 20)
        }
    }

    test("createTransaction returns 201") {

        val request = CreateTransactionRequest(
            type = "EXPENSE", amount = 15000, description = "점심",
            transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionService.createTransaction(testUserId, request) } returns sampleTransactionResponse()

        val result = controller.createTransaction(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
    }

    test("getTransaction returns transaction") {

        val txId = UUID.randomUUID()
        every { transactionService.getTransaction(testUserId, txId) } returns sampleTransactionResponse()

        val result = controller.getTransaction(testUserId, txId)

        result.success shouldBe true
        result.data!!.type shouldBe "EXPENSE"
    }

    test("updateTransaction returns updated transaction") {

        val txId = UUID.randomUUID()
        val request = UpdateTransactionRequest(amount = 18000)
        every { transactionService.updateTransaction(testUserId, txId, request) } returns sampleTransactionResponse()

        val result = controller.updateTransaction(testUserId, txId, request)

        result.success shouldBe true
    }

    test("deleteTransaction returns 204") {

        val txId = UUID.randomUUID()
        justRun { transactionService.deleteTransaction(testUserId, txId) }

        val result = controller.deleteTransaction(testUserId, txId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { transactionService.deleteTransaction(testUserId, txId) }
    }

    test("getSuggestions returns matching descriptions") {

        val suggestions = listOf(
            SuggestionResponse("점심 식사", emptyList()),
            SuggestionResponse("점심 도시락", emptyList())
        )
        every { transactionService.getSuggestions(testUserId, "점", 10) } returns suggestions

        val result = controller.getSuggestions(testUserId, "점", 10)

        result.success shouldBe true
        result.data!!.size shouldBe 2
        result.data!![0].description shouldBe "점심 식사"
    }

    test("getSuggestions with custom limit") {

        val suggestions = listOf(SuggestionResponse("커피", emptyList()))
        every { transactionService.getSuggestions(testUserId, "커", 5) } returns suggestions

        val result = controller.getSuggestions(testUserId, "커", 5)

        result.success shouldBe true
        result.data!!.size shouldBe 1
    }

    test("getSuggestions returns empty list when no matches") {

        every { transactionService.getSuggestions(testUserId, "없는내용", 10) } returns emptyList()

        val result = controller.getSuggestions(testUserId, "없는내용", 10)

        result.success shouldBe true
        result.data shouldBe emptyList()
    }

    test("getSettlementTransactions returns settlement data") {

        val pmId = UUID.randomUUID()
        val response = SettlementTransactionsResponse(
            totalAmount = 30000,
            transactionCount = 2,
            transactions = listOf(
                SettlementTransactionItem(
                    id = UUID.randomUUID(),
                    transactionDate = LocalDate.of(2024, 1, 5),
                    settlementDate = LocalDate.of(2024, 2, 15),
                    description = "점심",
                    amount = 10000,
                    categoryName = "식비",
                    categoryIcon = "restaurant"
                ),
                SettlementTransactionItem(
                    id = UUID.randomUUID(),
                    transactionDate = LocalDate.of(2024, 1, 10),
                    settlementDate = LocalDate.of(2024, 2, 15),
                    description = "저녁",
                    amount = 20000,
                    categoryName = null,
                    categoryIcon = null
                )
            )
        )
        every { transactionService.getSettlementTransactions(testUserId, pmId, 2024, 2) } returns response

        val result = controller.getSettlementTransactions(testUserId, pmId, 2024, 2)

        result.success shouldBe true
        result.data!!.totalAmount shouldBe 30000
        result.data!!.transactionCount shouldBe 2
        result.data!!.transactions.size shouldBe 2
    }

    test("exportCsv returns CSV with correct headers") {

        val csvContent = "\uFEFF날짜,유형,카테고리,설명,금액,메모,결제수단\n2026-03-01,수입,,월급,3000000,,\n"
        every { transactionExportService.exportCsv(testUserId, 2026, 3, null, null) } returns csvContent

        val result = controller.exportCsv(testUserId, 2026, 3, null, null)

        result.statusCode shouldBe HttpStatus.OK
        result.headers["Content-Disposition"]!![0] shouldBe "attachment; filename=\"transactions_2026_03.csv\""
        result.headers.contentType.toString() shouldBe "text/csv;charset=UTF-8"
    }
})
