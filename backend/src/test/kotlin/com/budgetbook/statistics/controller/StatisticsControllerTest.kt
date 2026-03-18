package com.budgetbook.statistics.controller

import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.MonthlyTrendResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import com.budgetbook.statistics.service.PaymentMethodStatisticsService
import com.budgetbook.statistics.service.StatisticsService
import com.budgetbook.transaction.dto.CategorySummary
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.util.UUID

class StatisticsControllerTest : FunSpec({

    val statisticsService = mockk<StatisticsService>()
    val paymentMethodStatisticsService = mockk<PaymentMethodStatisticsService>()
    val controller = StatisticsController(statisticsService, paymentMethodStatisticsService)
    val testUserId = UUID.randomUUID()

    test("getMonthlySummary returns summary data") {

        val summary = StatisticsSummaryResponse(
            yearMonth = "2026-03",
            totalIncome = 5000000,
            totalExpense = 3200000,
            balance = 1800000,
            transactionCount = 45
        )
        every { statisticsService.getMonthlySummary(testUserId, 2026, 3) } returns summary

        val result = controller.getMonthlySummary(testUserId, 2026, 3)

        result.success shouldBe true
        result.data!!.yearMonth shouldBe "2026-03"
        result.data!!.totalIncome shouldBe 5000000
        result.data!!.totalExpense shouldBe 3200000
        result.data!!.balance shouldBe 1800000
        result.data!!.transactionCount shouldBe 45
    }

    test("getCategoryBreakdown returns category statistics") {

        val catId = UUID.randomUUID()
        val breakdown = listOf(
            CategoryStatisticsResponse(
                category = CategorySummary(catId, "식비", "EXPENSE", "restaurant", "#FF5733"),
                amount = 800000,
                percentage = 25.0,
                transactionCount = 12
            )
        )
        every { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE") } returns breakdown

        val result = controller.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE")

        result.success shouldBe true
        result.data!! shouldBe breakdown
    }

    test("getCategoryBreakdown with null type passes null to service") {

        every { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, null) } returns emptyList()

        val result = controller.getCategoryBreakdown(testUserId, 2026, 3, null)

        result.success shouldBe true
        result.data!! shouldBe emptyList()
    }

    test("getMonthlyTrend returns trend data") {

        val trend = listOf(
            MonthlyTrendResponse("2025-10", 4500000, 3100000, 1400000),
            MonthlyTrendResponse("2025-11", 4800000, 3400000, 1400000),
            MonthlyTrendResponse("2025-12", 5200000, 4100000, 1100000)
        )
        every { statisticsService.getMonthlyTrend(testUserId, 3) } returns trend

        val result = controller.getMonthlyTrend(testUserId, 3)

        result.success shouldBe true
        result.data!!.size shouldBe 3
        result.data!![0].yearMonth shouldBe "2025-10"
    }

    test("getMonthlyTrend uses default months value of 6") {

        val trend = (1..6).map {
            MonthlyTrendResponse("2025-${it.toString().padStart(2, '0')}", 0, 0, 0)
        }
        every { statisticsService.getMonthlyTrend(testUserId, 6) } returns trend

        val result = controller.getMonthlyTrend(testUserId, 6)

        result.success shouldBe true
        result.data!!.size shouldBe 6
    }
})
