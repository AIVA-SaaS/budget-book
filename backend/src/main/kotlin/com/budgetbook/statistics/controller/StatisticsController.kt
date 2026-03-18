package com.budgetbook.statistics.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.MonthlyTrendResponse
import com.budgetbook.statistics.dto.PaymentMethodStatResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import com.budgetbook.statistics.service.PaymentMethodStatisticsService
import com.budgetbook.statistics.service.StatisticsService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/statistics")
class StatisticsController(
    private val statisticsService: StatisticsService,
    private val paymentMethodStatisticsService: PaymentMethodStatisticsService
) {

    @GetMapping("/summary")
    fun getMonthlySummary(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<StatisticsSummaryResponse> {
        return ApiResponse.ok(statisticsService.getMonthlySummary(userId, year, month))
    }

    @GetMapping("/by-category")
    fun getCategoryBreakdown(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam(required = false) type: String?
    ): ApiResponse<List<CategoryStatisticsResponse>> {
        return ApiResponse.ok(statisticsService.getCategoryBreakdown(userId, year, month, type))
    }

    @GetMapping("/payment-methods")
    fun getPaymentMethodStats(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<List<PaymentMethodStatResponse>> {
        return ApiResponse.ok(paymentMethodStatisticsService.getPaymentMethodStats(userId, year, month))
    }

    @GetMapping("/monthly-trend")
    fun getMonthlyTrend(
        @AuthUser userId: UUID,
        @RequestParam(defaultValue = "6") months: Int
    ): ApiResponse<List<MonthlyTrendResponse>> {
        return ApiResponse.ok(statisticsService.getMonthlyTrend(userId, months))
    }
}
