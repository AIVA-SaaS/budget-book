package com.budgetbook.budget.controller

import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetResponse
import com.budgetbook.budget.dto.BudgetSummaryItemResponse
import com.budgetbook.budget.dto.BudgetSummaryResponse
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.dto.CopyBudgetRequest
import com.budgetbook.budget.dto.CurrentWeekSummaryResponse
import com.budgetbook.budget.dto.WeeklyBudgetItemResponse
import com.budgetbook.budget.dto.WeeklyOverviewResponse
import com.budgetbook.budget.dto.WeeklyWeekResponse
import com.budgetbook.budget.service.BudgetAlertService
import com.budgetbook.budget.service.BudgetService
import com.budgetbook.budget.service.WeeklyBudgetService
import com.budgetbook.transaction.dto.CategorySummary
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class BudgetControllerTest : FunSpec({

    val budgetService = mockk<BudgetService>()
    val weeklyBudgetService = mockk<WeeklyBudgetService>()
    val budgetAlertService = mockk<BudgetAlertService>()
    val controller = BudgetController(budgetService, weeklyBudgetService, budgetAlertService)
    val testUserId = UUID.randomUUID()

    val sampleCategory = CategorySummary(
        id = UUID.randomUUID(), name = "식비", type = "EXPENSE", icon = "restaurant", color = "#FF5733"
    )

    fun sampleBudgetResponse(category: CategorySummary? = sampleCategory) = BudgetResponse(
        id = UUID.randomUUID(),
        coupleId = UUID.randomUUID(),
        category = category,
        yearMonth = "2026-03",
        amount = 150000,
        budgetPeriod = "MONTHLY",
        weeklyAmount = null,
        periodType = "MONTHLY",
        startDate = "2026-03-01",
        endDate = "2026-03-31",
        pocketId = null,
        pocketName = null,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("createBudget returns 201") {

        val request = BudgetRequest(categoryId = sampleCategory.id, yearMonth = "2026-03", amount = 150000)
        every { budgetService.createBudget(testUserId, request) } returns sampleBudgetResponse()

        val result = controller.createBudget(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.amount shouldBe 150000
    }

    test("listBudgets returns budgets for month") {

        val budgets = listOf(sampleBudgetResponse(), sampleBudgetResponse(null))
        every { budgetService.getBudgetsByMonth(testUserId, 2026, 3) } returns budgets

        val result = controller.listBudgets(testUserId, 2026, 3)

        result.success shouldBe true
        result.data!!.size shouldBe 2
    }

    test("updateBudget returns updated budget") {

        val budgetId = UUID.randomUUID()
        val request = BudgetUpdateRequest(amount = 200000)
        val response = sampleBudgetResponse().copy(amount = 200000)
        every { budgetService.updateBudget(testUserId, budgetId, request) } returns response

        val result = controller.updateBudget(testUserId, budgetId, request)

        result.success shouldBe true
        result.data!!.amount shouldBe 200000
    }

    test("deleteBudget returns 204") {

        val budgetId = UUID.randomUUID()
        justRun { budgetService.deleteBudget(testUserId, budgetId) }

        val result = controller.deleteBudget(testUserId, budgetId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { budgetService.deleteBudget(testUserId, budgetId) }
    }

    test("copyFromPreviousMonth returns 201 with copied budgets") {

        val request = CopyBudgetRequest(sourceYear = 2026, sourceMonth = 2, targetYear = 2026, targetMonth = 3)
        val copiedBudgets = listOf(
            sampleBudgetResponse(),
            sampleBudgetResponse(null)
        )
        every { budgetService.copyFromPreviousMonth(testUserId, request) } returns copiedBudgets

        val result = controller.copyFromPreviousMonth(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.size shouldBe 2
    }

    test("copyFromPreviousMonth returns 201 with empty list when all duplicates") {

        val request = CopyBudgetRequest(sourceYear = 2026, sourceMonth = 2, targetYear = 2026, targetMonth = 3)
        every { budgetService.copyFromPreviousMonth(testUserId, request) } returns emptyList()

        val result = controller.copyFromPreviousMonth(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.size shouldBe 0
    }

    test("getBudgetSummary returns summary") {

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

        val result = controller.getBudgetSummary(testUserId, 2026, 3)

        result.success shouldBe true
        result.data!!.yearMonth shouldBe "2026-03"
        result.data!!.totalBudget shouldBe 3150000
        result.data!!.items.size shouldBe 2
    }

    test("getWeeklyOverview returns weekly overview") {

        val budgetId = UUID.randomUUID()
        val overview = WeeklyOverviewResponse(
            yearMonth = "2026-03",
            weeks = listOf(
                WeeklyWeekResponse(
                    weekNumber = 1, weekStart = "2026-03-01", weekEnd = "2026-03-07",
                    totalBudget = 100000, totalSpent = 80000, totalRemaining = 20000,
                    items = listOf(
                        WeeklyBudgetItemResponse(
                            budgetId = budgetId,
                            categoryId = sampleCategory.id,
                            categoryName = "식비",
                            groupId = null,
                            groupName = null,
                            budgetAmount = 100000,
                            spentAmount = 80000,
                            remainingAmount = 20000,
                            usageRate = 80.0
                        )
                    )
                )
            )
        )
        every { weeklyBudgetService.getWeeklyOverview(testUserId, 2026, 3) } returns overview

        val result = controller.getWeeklyOverview(testUserId, 2026, 3)

        result.success shouldBe true
        result.data!!.yearMonth shouldBe "2026-03"
        result.data!!.weeks.size shouldBe 1
        result.data!!.weeks[0].weekNumber shouldBe 1
        result.data!!.weeks[0].items.size shouldBe 1
    }

    test("getCurrentWeekSummary returns current week summary") {

        val budgetId = UUID.randomUUID()
        val summary = CurrentWeekSummaryResponse(
            yearMonth = "2026-03",
            weekNumber = 2,
            weekStart = "2026-03-08",
            weekEnd = "2026-03-14",
            items = listOf(
                WeeklyBudgetItemResponse(
                    budgetId = budgetId,
                    categoryId = null,
                    categoryName = null,
                    groupId = UUID.randomUUID(),
                    groupName = "생활비",
                    budgetAmount = 100000,
                    spentAmount = 45000,
                    remainingAmount = 55000,
                    usageRate = 45.0
                )
            )
        )
        every { weeklyBudgetService.getCurrentWeekSummary(testUserId) } returns summary

        val result = controller.getCurrentWeekSummary(testUserId)

        result.success shouldBe true
        result.data!!.weekNumber shouldBe 2
        result.data!!.items.size shouldBe 1
        result.data!!.items[0].groupName shouldBe "생활비"
    }
})
