package com.budgetbook.statistics.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.MonthlyTrendResponse
import com.budgetbook.statistics.dto.PaymentMethodStatResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import com.budgetbook.statistics.service.PaymentMethodStatisticsService
import com.budgetbook.statistics.service.StatisticsService
import org.springframework.security.core.Authentication
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
        authentication: Authentication,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<StatisticsSummaryResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(statisticsService.getMonthlySummary(userId, year, month))
    }

    @GetMapping("/by-category")
    fun getCategoryBreakdown(
        authentication: Authentication,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam(required = false) type: String?
    ): ApiResponse<List<CategoryStatisticsResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(statisticsService.getCategoryBreakdown(userId, year, month, type))
    }

    @GetMapping("/payment-methods")
    fun getPaymentMethodStats(
        authentication: Authentication,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<List<PaymentMethodStatResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(paymentMethodStatisticsService.getPaymentMethodStats(userId, year, month))
    }

    @GetMapping("/monthly-trend")
    fun getMonthlyTrend(
        authentication: Authentication,
        @RequestParam(defaultValue = "6") months: Int
    ): ApiResponse<List<MonthlyTrendResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(statisticsService.getMonthlyTrend(userId, months))
    }
}
