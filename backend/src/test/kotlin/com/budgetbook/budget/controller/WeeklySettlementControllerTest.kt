package com.budgetbook.budget.controller

import com.budgetbook.budget.dto.SettleWeekRequest
import com.budgetbook.budget.dto.SettlementItemResponse
import com.budgetbook.budget.dto.UnsettleWeekRequest
import com.budgetbook.budget.dto.WeekSettlementResponse
import com.budgetbook.budget.dto.WeeklySettlementOverviewResponse
import com.budgetbook.budget.service.WeeklySettlementService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import java.time.Instant
import java.util.UUID

class WeeklySettlementControllerTest : FunSpec({

    val service = mockk<WeeklySettlementService>()
    val controller = WeeklySettlementController(service)
    val testUserId = UUID.randomUUID()

    test("getSettlementOverview returns overview") {
        val categoryId = UUID.randomUUID()
        val budgetId = UUID.randomUUID()
        val settlementId = UUID.randomUUID()

        val overview = WeeklySettlementOverviewResponse(
            yearMonth = "2026-04",
            weeks = listOf(
                WeekSettlementResponse(
                    weekNumber = 1,
                    weekStart = "2026-04-01",
                    weekEnd = "2026-04-05",
                    items = listOf(
                        SettlementItemResponse(
                            settlementId = settlementId,
                            budgetId = budgetId,
                            categoryId = categoryId,
                            categoryName = "식비",
                            amount = 50000,
                            status = "PENDING",
                            settledAt = null
                        )
                    ),
                    allSettled = false
                )
            )
        )

        every { service.getSettlementOverview(testUserId, 2026, 4) } returns overview

        val result = controller.getSettlementOverview(testUserId, 2026, 4)

        result.success shouldBe true
        result.data!!.yearMonth shouldBe "2026-04"
        result.data!!.weeks.size shouldBe 1
        result.data!!.weeks[0].items[0].amount shouldBe 50000
    }

    test("settleWeek calls service and returns ok") {
        val request = SettleWeekRequest(
            budgetId = UUID.randomUUID(),
            yearMonth = "2026-04",
            weekNumber = 1
        )

        justRun { service.settleWeek(testUserId, request) }

        val result = controller.settleWeek(testUserId, request)

        result.success shouldBe true
        verify(exactly = 1) { service.settleWeek(testUserId, request) }
    }

    test("unsettleWeek calls service and returns ok") {
        val request = UnsettleWeekRequest(
            budgetId = UUID.randomUUID(),
            yearMonth = "2026-04",
            weekNumber = 1
        )

        justRun { service.unsettleWeek(testUserId, request) }

        val result = controller.unsettleWeek(testUserId, request)

        result.success shouldBe true
        verify(exactly = 1) { service.unsettleWeek(testUserId, request) }
    }

    test("settleWeek with specific categoryIds") {
        val catId1 = UUID.randomUUID()
        val catId2 = UUID.randomUUID()
        val request = SettleWeekRequest(
            budgetId = UUID.randomUUID(),
            yearMonth = "2026-04",
            weekNumber = 2,
            categoryIds = listOf(catId1, catId2)
        )

        justRun { service.settleWeek(testUserId, request) }

        val result = controller.settleWeek(testUserId, request)

        result.success shouldBe true
        verify(exactly = 1) { service.settleWeek(testUserId, request) }
    }
})
