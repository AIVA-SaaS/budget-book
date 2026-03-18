package com.budgetbook.report.controller

import com.budgetbook.report.dto.CardPendingReportSummary
import com.budgetbook.report.dto.CategorySpendingItem
import com.budgetbook.report.dto.DailySpendingItem
import com.budgetbook.report.dto.DayOfWeekPattern
import com.budgetbook.report.dto.GroupSpendingSummary
import com.budgetbook.report.dto.MonthComparisonResponse
import com.budgetbook.report.dto.MonthlyReportResponse
import com.budgetbook.report.dto.WeeklyReportResponse
import com.budgetbook.report.service.ReportService
import com.budgetbook.transaction.dto.CategorySummary
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.util.UUID

class ReportControllerTest : FunSpec({

    val reportService = mockk<ReportService>()
    val controller = ReportController(reportService)
    val testUserId = UUID.randomUUID()

    test("getWeeklyReport returns weekly report data") {

        val catId = UUID.randomUUID()
        val weeklyReport = WeeklyReportResponse(
            yearMonth = "2026-03",
            weekNumber = 1,
            weekStart = "2026-03-01",
            weekEnd = "2026-03-07",
            totalBudget = 100000,
            totalSpent = 80000,
            remainingAmount = 20000,
            usageRate = 80.0,
            status = "UNDER",
            topOverspendCategories = listOf(
                CategorySpendingItem(
                    category = CategorySummary(catId, "Meals", "EXPENSE", "restaurant", "#FF5733"),
                    amount = 80000,
                    averageAmount = 50000,
                    deviation = 30000,
                    transactionCount = 5
                )
            ),
            dailySpending = listOf(
                DailySpendingItem("2026-03-01", "SUN", 20000, 1),
                DailySpendingItem("2026-03-02", "MON", 50000, 2)
            ),
            peakSpendingDay = "MON"
        )

        every { reportService.getWeeklyReport(testUserId, 2026, 3, 1) } returns weeklyReport

        val result = controller.getWeeklyReport(testUserId, 2026, 3, 1)

        result.success shouldBe true
        result.data!!.yearMonth shouldBe "2026-03"
        result.data!!.weekNumber shouldBe 1
        result.data!!.totalBudget shouldBe 100000
        result.data!!.totalSpent shouldBe 80000
        result.data!!.status shouldBe "UNDER"
        result.data!!.topOverspendCategories.size shouldBe 1
        result.data!!.topOverspendCategories[0].deviation shouldBe 30000
        result.data!!.dailySpending.size shouldBe 2
        result.data!!.peakSpendingDay shouldBe "MON"
    }

    test("getMonthlyReport returns monthly report data") {

        val groupId = UUID.randomUUID()
        val catId = UUID.randomUUID()
        val monthlyReport = MonthlyReportResponse(
            yearMonth = "2026-03",
            totalIncome = 5000000,
            totalExpense = 3200000,
            balance = 1800000,
            groupSummaries = listOf(
                GroupSpendingSummary(
                    groupId = groupId,
                    groupName = "Food",
                    budgetType = "WEEKLY",
                    totalBudget = 500000,
                    totalSpent = 800000,
                    usageRate = 160.0
                )
            ),
            topCategories = listOf(
                CategorySpendingItem(
                    category = CategorySummary(catId, "Meals", "EXPENSE", "restaurant", "#FF5733"),
                    amount = 800000,
                    averageAmount = 600000,
                    deviation = 200000,
                    transactionCount = 12
                )
            ),
            previousMonthComparison = MonthComparisonResponse(
                previousYearMonth = "2026-02",
                incomeChange = 1000000,
                expenseChange = 400000,
                incomeChangeRate = 25.0,
                expenseChangeRate = 14.3
            ),
            cardPendingSummary = CardPendingReportSummary(
                totalPendingAmount = 150000,
                cardCount = 1
            ),
            dayOfWeekPattern = listOf(
                DayOfWeekPattern("MON", 50000, 200000, 8),
                DayOfWeekPattern("TUE", 30000, 120000, 5)
            )
        )

        every { reportService.getMonthlyReport(testUserId, 2026, 3) } returns monthlyReport

        val result = controller.getMonthlyReport(testUserId, 2026, 3)

        result.success shouldBe true
        result.data!!.yearMonth shouldBe "2026-03"
        result.data!!.totalIncome shouldBe 5000000
        result.data!!.totalExpense shouldBe 3200000
        result.data!!.balance shouldBe 1800000
        result.data!!.groupSummaries.size shouldBe 1
        result.data!!.groupSummaries[0].groupName shouldBe "Food"
        result.data!!.groupSummaries[0].usageRate shouldBe 160.0
        result.data!!.topCategories.size shouldBe 1
        result.data!!.previousMonthComparison!!.incomeChangeRate shouldBe 25.0
        result.data!!.cardPendingSummary!!.totalPendingAmount shouldBe 150000
        result.data!!.dayOfWeekPattern.size shouldBe 2
    }

    test("getMonthlyReport returns null optional fields correctly") {

        val monthlyReport = MonthlyReportResponse(
            yearMonth = "2026-01",
            totalIncome = 3000000,
            totalExpense = 1000000,
            balance = 2000000,
            groupSummaries = emptyList(),
            topCategories = emptyList(),
            previousMonthComparison = null,
            cardPendingSummary = null,
            dayOfWeekPattern = emptyList()
        )

        every { reportService.getMonthlyReport(testUserId, 2026, 1) } returns monthlyReport

        val result = controller.getMonthlyReport(testUserId, 2026, 1)

        result.success shouldBe true
        result.data!!.previousMonthComparison shouldBe null
        result.data!!.cardPendingSummary shouldBe null
        result.data!!.groupSummaries.size shouldBe 0
    }
})
