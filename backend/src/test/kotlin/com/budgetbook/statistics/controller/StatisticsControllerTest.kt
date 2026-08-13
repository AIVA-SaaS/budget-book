package com.budgetbook.statistics.controller

import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.MonthlyTrendResponse
import com.budgetbook.statistics.dto.PaymentMethodStatResponse
import com.budgetbook.statistics.dto.PeriodSummaryResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import java.time.LocalDate
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
            totalTransfer = 0,
            balance = 1800000,
            transactionCount = 45
        )
        val filter = CommonFilterParams()
        every { statisticsService.getMonthlySummary(testUserId, 2026, 3, filter) } returns summary

        val result = controller.getMonthlySummary(testUserId, 2026, 3, filter)

        result.success shouldBe true
        result.data!!.yearMonth shouldBe "2026-03"
        result.data!!.totalIncome shouldBe 5000000
        result.data!!.totalExpense shouldBe 3200000
        result.data!!.balance shouldBe 1800000
        result.data!!.transactionCount shouldBe 45
    }

    test("getMonthlySummary passes visibility SHARED to service") {

        val summary = StatisticsSummaryResponse("2026-03", 1000000, 500000, 0, 500000, 10)
        val filter = CommonFilterParams(visibility = "SHARED")
        every { statisticsService.getMonthlySummary(testUserId, 2026, 3, filter) } returns summary

        val result = controller.getMonthlySummary(testUserId, 2026, 3, filter)

        result.success shouldBe true
        verify { statisticsService.getMonthlySummary(testUserId, 2026, 3, filter) }
    }

    // 2026-07-27 회귀 가드 — 거래 목록에는 needsReviewOnly 가 적용되는데 summary 에는
    // 전달되지 않아 "확인/입력 필요만 보기" 상태에서 월 합계가 전체 금액을 보여줬다
    // (합계 ≠ 보이는 행). 컨트롤러가 이 필터를 서비스로 넘기는지 고정한다.
    test("getMonthlySummary passes needsReviewOnly to service") {

        val summary = StatisticsSummaryResponse("2026-03", 0, 30000, 0, -30000, 2)
        val filter = CommonFilterParams(needsReviewOnly = true)
        every { statisticsService.getMonthlySummary(testUserId, 2026, 3, filter) } returns summary

        val result = controller.getMonthlySummary(testUserId, 2026, 3, filter)

        result.success shouldBe true
        result.data!!.totalExpense shouldBe 30000
        verify { statisticsService.getMonthlySummary(testUserId, 2026, 3, filter) }
    }

    test("getMonthlySummary passes visibility PRIVATE to service") {

        val summary = StatisticsSummaryResponse("2026-03", 200000, 100000, 0, 100000, 5)
        val filter = CommonFilterParams(visibility = "PRIVATE")
        every { statisticsService.getMonthlySummary(testUserId, 2026, 3, filter) } returns summary

        val result = controller.getMonthlySummary(testUserId, 2026, 3, filter)

        result.success shouldBe true
        verify { statisticsService.getMonthlySummary(testUserId, 2026, 3, filter) }
    }

    // 2026-08-12 구조 가드 — 컨트롤러가 필터 VO 를 **통째로** 넘기는지 고정한다.
    // 필드를 하나씩 나열하던 시절에는 새 축이 추가될 때마다 summary 쪽에서만 조용히
    // 누락됐다(4회 재발). 아래처럼 여러 축을 채운 VO 가 그대로 전달돼야 한다.
    test("getMonthlySummary forwards the whole filter VO (no field enumeration)") {

        val summary = StatisticsSummaryResponse("2026-03", 0, 0, 0, 0, 0)
        val filter = CommonFilterParams(
            dateFrom = LocalDate.of(2026, 6, 15),
            dateTo = LocalDate.of(2026, 8, 5),
            paymentMethodIds = listOf(UUID.randomUUID(), UUID.randomUUID()),
            amountMin = 10_000,
            amountMax = 500_000,
            keyword = "커피",
            transactionTypes = listOf("EXPENSE", "TRANSFER"),
            needsReviewOnly = null,
        )
        every { statisticsService.getMonthlySummary(testUserId, 2026, 3, filter) } returns summary

        controller.getMonthlySummary(testUserId, 2026, 3, filter).success shouldBe true

        verify { statisticsService.getMonthlySummary(testUserId, 2026, 3, filter) }
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
        every { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE", "ALL", null, null) } returns breakdown

        val filter = CommonFilterParams(type = "EXPENSE")
        val result = controller.getCategoryBreakdown(testUserId, 2026, 3, filter)

        result.success shouldBe true
        result.data!! shouldBe breakdown
    }

    test("getCategoryBreakdown passes visibility filter to service") {

        every { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE", "SHARED", null, null) } returns emptyList()

        val filter = CommonFilterParams(type = "EXPENSE", visibility = "SHARED")
        val result = controller.getCategoryBreakdown(testUserId, 2026, 3, filter)

        result.success shouldBe true
        verify { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, "EXPENSE", "SHARED", null, null) }
    }

    test("getCategoryBreakdown with null type passes null to service") {

        every { statisticsService.getCategoryBreakdown(testUserId, 2026, 3, null, "ALL", null, null) } returns emptyList()

        val filter = CommonFilterParams()
        val result = controller.getCategoryBreakdown(testUserId, 2026, 3, filter)

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

        val filter = CommonFilterParams(visibility = "PRIVATE")
        val result = controller.getPaymentMethodStats(testUserId, 2026, 3, filter)

        result.success shouldBe true
        result.data!!.size shouldBe 1
        verify { paymentMethodStatisticsService.getPaymentMethodStats(testUserId, 2026, 3, "PRIVATE") }
    }

    test("getMonthlyTrend returns trend data with default visibility") {

        val trend = listOf(
            MonthlyTrendResponse("2025-10", 4500000, 3100000, 0, 1400000),
            MonthlyTrendResponse("2025-11", 4800000, 3400000, 0, 1400000),
            MonthlyTrendResponse("2025-12", 5200000, 4100000, 0, 1100000)
        )
        every { statisticsService.getMonthlyTrend(testUserId, 3, "ALL") } returns trend

        val filter = CommonFilterParams()
        val result = controller.getMonthlyTrend(testUserId, 3, filter)

        result.success shouldBe true
        result.data!!.size shouldBe 3
        result.data!![0].yearMonth shouldBe "2025-10"
    }

    test("getMonthlyTrend passes visibility SHARED to service") {

        val trend = listOf(MonthlyTrendResponse("2026-03", 1000000, 500000, 0, 500000))
        every { statisticsService.getMonthlyTrend(testUserId, 6, "SHARED") } returns trend

        val filter = CommonFilterParams(visibility = "SHARED")
        val result = controller.getMonthlyTrend(testUserId, 6, filter)

        result.success shouldBe true
        verify { statisticsService.getMonthlyTrend(testUserId, 6, "SHARED") }
    }

    test("getMonthlyTrend uses default months value of 6") {

        val trend = (1..6).map {
            MonthlyTrendResponse("2025-${it.toString().padStart(2, '0')}", 0, 0, 0, 0)
        }
        every { statisticsService.getMonthlyTrend(testUserId, 6, "ALL") } returns trend

        val filter = CommonFilterParams()
        val result = controller.getMonthlyTrend(testUserId, 6, filter)

        result.success shouldBe true
        result.data!!.size shouldBe 6
    }

    test("getPeriodSummary returns period summary data") {
        val dateFrom = LocalDate.of(2026, 3, 1)
        val dateTo = LocalDate.of(2026, 3, 31)
        val summary = PeriodSummaryResponse(
            dateFrom = "2026-03-01",
            dateTo = "2026-03-31",
            totalIncome = 5000000,
            totalExpense = 3200000,
            totalTransfer = 0,
            balance = 1800000,
            byCategory = emptyList(),
            byBudget = emptyList(),
            byPaymentMethod = emptyList(),
            byDate = emptyList()
        )
        val filter = CommonFilterParams()
        every {
            statisticsService.getPeriodSummary(testUserId, dateFrom, dateTo, filter)
        } returns summary
        val result = controller.getPeriodSummary(testUserId, dateFrom, dateTo, filter)

        result.success shouldBe true
        result.data!!.totalIncome shouldBe 5000000
        result.data!!.totalExpense shouldBe 3200000
        result.data!!.balance shouldBe 1800000
    }

    test("getPeriodSummary passes visibility filter to service") {
        val dateFrom = LocalDate.of(2026, 3, 1)
        val dateTo = LocalDate.of(2026, 3, 31)
        val summary = PeriodSummaryResponse(
            dateFrom = "2026-03-01",
            dateTo = "2026-03-31",
            totalIncome = 1000000,
            totalExpense = 500000,
            totalTransfer = 0,
            balance = 500000,
            byCategory = emptyList(),
            byBudget = emptyList(),
            byPaymentMethod = emptyList(),
            byDate = emptyList()
        )
        val filter = CommonFilterParams(visibility = "SHARED")
        every {
            statisticsService.getPeriodSummary(testUserId, dateFrom, dateTo, filter)
        } returns summary
        val result = controller.getPeriodSummary(testUserId, dateFrom, dateTo, filter)

        result.success shouldBe true
        verify { statisticsService.getPeriodSummary(testUserId, dateFrom, dateTo, filter) }
    }

    test("getPeriodSummary passes categoryId filter to service") {
        val dateFrom = LocalDate.of(2026, 3, 1)
        val dateTo = LocalDate.of(2026, 3, 31)
        val catId = UUID.randomUUID()
        val summary = PeriodSummaryResponse(
            dateFrom = "2026-03-01",
            dateTo = "2026-03-31",
            totalIncome = 0,
            totalExpense = 800000,
            totalTransfer = 0,
            balance = -800000,
            byCategory = emptyList(),
            byBudget = emptyList(),
            byPaymentMethod = emptyList(),
            byDate = emptyList()
        )
        val filter = CommonFilterParams(categoryId = catId)
        every {
            statisticsService.getPeriodSummary(testUserId, dateFrom, dateTo, filter)
        } returns summary
        val result = controller.getPeriodSummary(testUserId, dateFrom, dateTo, filter)

        result.success shouldBe true
        verify { statisticsService.getPeriodSummary(testUserId, dateFrom, dateTo, filter) }
    }
})
