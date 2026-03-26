package com.budgetbook.statistics.controller

import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.MonthlyTrendResponse
import com.budgetbook.statistics.dto.PaymentMethodStatResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import com.budgetbook.statistics.service.PaymentMethodStatisticsService
import com.budgetbook.statistics.service.StatisticsService
import com.budgetbook.transaction.dto.CategorySummary
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.util.UUID

class StatisticsControllerTest : FunSpec({

    val statisticsService = mockk<StatisticsService>()
    val paymentMethodStatisticsService = mockk<PaymentMethodStatisticsService>()
    val controller = StatisticsController(statisticsService, paymentMethodStatisticsService)
    val testUserId = UUID.randomUUID()

    test("getMonthlySummary returns summary data with default visibility ALL") {

        val summary = StatisticsSummaryResponse(
            yearMonth = "2026-03",
            totalIncome = 5000000,
            totalExpense = 3200000,
            balance = 1800000,
            transactionCount = 45
        )
        every { statisticsService.getMonthlySummary(testUserId, 2026, 3, "ALL") } returns summary

        val result = controller.getMonthlySummary(testUserId, 2026, 3, "ALL")

        result.success shouldBe true
        result.data!!.yearMonth shouldBe "2026-03"
        result.data!!.totalIncome shouldBe 5000000
        result.data!!.totalExpense shouldBe 3200000
        result.data!!.balance shouldBe 1800000
        result.data!!.transactionCount shouldBe 45
    }

    test("getMonthlySummary passes visibility SHARED to service") {

        val summary = StatisticsSummaryResponse("2026-03", 1000000, 500000, 500000, 10)
        every { statisticsService.getMonthlySummary(testUserId, 2026, 3, "SHARED") } returns summary

        val result = controller.getMonthlySummary(testUserId, 2026, 3, "SHARED")

        result.success shouldBe true
        verify { statisticsService.getMonthlySummary(testUserId, 2026, 3, "SHARED") }
    }

    test("getMonthlySummary passes visibility PRIVATE to service") {

        val summary = StatisticsSummaryResponse("2026-03", 200000, 100000, 100000, 5)
        every { statisticsService.getMonthlySummary(testUserId, 2026, 3, "PRIVATE") } returns summary

        val result = controller.getMonthlySummary(testUserId, 2026, 3, "PRIVATE")

        result.success shouldBe true
        verify { statisticsService.getMonthlySummary(testUserId, 2026, 3, "PRIVATE") }
    }

    test("getCategoryBreakdown returns category statistics with default visibility") {

        val catId = UUID.randomUUID()
        val breakdown = listOf(
            CategoryStatisticsResponse(
                category = CategorySummary(catId, "식비", "EXPENSE", "restaurant", "#FF5733"),
                amount = 800000,
                percentage = 25.0,
                transactionCount = 12
            )
        )
        every { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE", "ALL") } returns breakdown

        val result = controller.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE", "ALL")

        result.success shouldBe true
        result.data!! shouldBe breakdown
    }

    test("getCategoryBreakdown passes visibility filter to service") {

        every { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE", "SHARED") } returns emptyList()

        val result = controller.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE", "SHARED")

        result.success shouldBe true
        verify { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE", "SHARED") }
    }

    test("getCategoryBreakdown with null type passes null to service") {

        every { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, null, "ALL") } returns emptyList()

        val result = controller.getCategoryBreakdown(testUserId, 2026, 3, null, "ALL")

        result.success shouldBe true
        result.data!! shouldBe emptyList()
    }

    test("getPaymentMethodStats passes visibility to service") {

        val stats = listOf(
            PaymentMethodStatResponse(
                paymentMethodId = UUID.randomUUID().toString(),
                paymentMethodName = "Card",
                totalAmount = 500000,
                transactionCount = 10,
                percentage = 100.0
            )
        )
        every { paymentMethodStatisticsService.getPaymentMethodStats(testUserId, 2026, 3, "PRIVATE") } returns stats

        val result = controller.getPaymentMethodStats(testUserId, 2026, 3, "PRIVATE")

        result.success shouldBe true
        result.data!!.size shouldBe 1
        verify { paymentMethodStatisticsService.getPaymentMethodStats(testUserId, 2026, 3, "PRIVATE") }
    }

    test("getMonthlyTrend returns trend data with default visibility") {

        val trend = listOf(
            MonthlyTrendResponse("2025-10", 4500000, 3100000, 1400000),
            MonthlyTrendResponse("2025-11", 4800000, 3400000, 1400000),
            MonthlyTrendResponse("2025-12", 5200000, 4100000, 1100000)
        )
        every { statisticsService.getMonthlyTrend(testUserId, 3, "ALL") } returns trend

        val result = controller.getMonthlyTrend(testUserId, 3, "ALL")

        result.success shouldBe true
        result.data!!.size shouldBe 3
        result.data!![0].yearMonth shouldBe "2025-10"
    }

    test("getMonthlyTrend passes visibility SHARED to service") {

        val trend = listOf(MonthlyTrendResponse("2026-03", 1000000, 500000, 500000))
        every { statisticsService.getMonthlyTrend(testUserId, 6, "SHARED") } returns trend

        val result = controller.getMonthlyTrend(testUserId, 6, "SHARED")

        result.success shouldBe true
        verify { statisticsService.getMonthlyTrend(testUserId, 6, "SHARED") }
    }

    test("getMonthlyTrend uses default months value of 6") {

        val trend = (1..6).map {
            MonthlyTrendResponse("2025-${it.toString().padStart(2, '0')}", 0, 0, 0)
        }
        every { statisticsService.getMonthlyTrend(testUserId, 6, "ALL") } returns trend

        val result = controller.getMonthlyTrend(testUserId, 6, "ALL")

        result.success shouldBe true
        result.data!!.size shouldBe 6
    }
})
