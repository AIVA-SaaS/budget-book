package com.budgetbook.budget.controller

import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetResponse
import com.budgetbook.budget.dto.BudgetSummaryItemResponse
import com.budgetbook.budget.dto.BudgetSummaryResponse
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.service.BudgetService
import com.budgetbook.transaction.dto.CategorySummary
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

class BudgetControllerTest : FunSpec({

    val budgetService = mockk<BudgetService>()
    val controller = BudgetController(budgetService)
    val testUserId = UUID.randomUUID()

    fun createAuth(userId: UUID): Authentication =
        UsernamePasswordAuthenticationToken(userId, null, emptyList())

    val sampleCategory = CategorySummary(
        id = UUID.randomUUID(), name = "식비", type = "EXPENSE", icon = "restaurant", color = "#FF5733"
    )

    fun sampleBudgetResponse(category: CategorySummary? = sampleCategory) = BudgetResponse(
        id = UUID.randomUUID(),
        coupleId = UUID.randomUUID(),
        category = category,
        yearMonth = "2026-03",
        amount = 150000,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("createBudget returns 201") {
        val auth = createAuth(testUserId)
        val request = BudgetRequest(categoryId = sampleCategory.id, yearMonth = "2026-03", amount = 150000)
        every { budgetService.createBudget(testUserId, request) } returns sampleBudgetResponse()

        val result = controller.createBudget(auth, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.amount shouldBe 150000
    }

    test("listBudgets returns budgets for month") {
        val auth = createAuth(testUserId)
        val budgets = listOf(sampleBudgetResponse(), sampleBudgetResponse(null))
        every { budgetService.getBudgetsByMonth(testUserId, 2026, 3) } returns budgets

        val result = controller.listBudgets(auth, 2026, 3)

        result.success shouldBe true
        result.data!!.size shouldBe 2
    }

    test("updateBudget returns updated budget") {
        val auth = createAuth(testUserId)
        val budgetId = UUID.randomUUID()
        val request = BudgetUpdateRequest(amount = 200000)
        val response = sampleBudgetResponse().copy(amount = 200000)
        every { budgetService.updateBudget(testUserId, budgetId, request) } returns response

        val result = controller.updateBudget(auth, budgetId, request)

        result.success shouldBe true
        result.data!!.amount shouldBe 200000
    }

    test("deleteBudget returns 204") {
        val auth = createAuth(testUserId)
        val budgetId = UUID.randomUUID()
        justRun { budgetService.deleteBudget(testUserId, budgetId) }

        val result = controller.deleteBudget(auth, budgetId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { budgetService.deleteBudget(testUserId, budgetId) }
    }

    test("getBudgetSummary returns summary") {
        val auth = createAuth(testUserId)
        val summary = BudgetSummaryResponse(
            yearMonth = "2026-03",
            totalBudget = 3150000,
            totalSpent = 1800000,
            items = listOf(
                BudgetSummaryItemResponse(
                    category = sampleCategory,
                    budgetAmount = 150000,
                    spentAmount = 95000,
                    remainingAmount = 55000,
                    usageRate = 63.3
                ),
                BudgetSummaryItemResponse(
                    category = null,
                    budgetAmount = 3000000,
                    spentAmount = 1705000,
                    remainingAmount = 1295000,
                    usageRate = 56.8
                )
            )
        )
        every { budgetService.getBudgetSummary(testUserId, 2026, 3) } returns summary

        val result = controller.getBudgetSummary(auth, 2026, 3)

        result.success shouldBe true
        result.data!!.yearMonth shouldBe "2026-03"
        result.data!!.totalBudget shouldBe 3150000
        result.data!!.items.size shouldBe 2
    }
})
