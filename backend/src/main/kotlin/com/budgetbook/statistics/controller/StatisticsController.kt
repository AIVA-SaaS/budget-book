package com.budgetbook.statistics.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.common.security.AuthUser
import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.MonthlyTrendResponse
import com.budgetbook.statistics.dto.PaymentMethodStatResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import com.budgetbook.statistics.service.PaymentMethodStatisticsService
import com.budgetbook.statistics.service.StatisticsService
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.ModelAttribute
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@Validated
@RestController
@RequestMapping("/api/v1/statistics")
class StatisticsController(
    private val statisticsService: StatisticsService,
    private val paymentMethodStatisticsService: PaymentMethodStatisticsService
) {

    @GetMapping("/summary")
    fun getMonthlySummary(
        @AuthUser userId: UUID,
        @RequestParam @Min(2000) @Max(2100) year: Int,
        @RequestParam @Min(1) @Max(12) month: Int,
        @ModelAttribute filter: CommonFilterParams
    ): ApiResponse<StatisticsSummaryResponse> {
        return ApiResponse.ok(statisticsService.getMonthlySummary(
            userId, year, month, filter.visibility ?: "ALL", filter.dateFrom, filter.dateTo
        ))
    }

    @GetMapping("/by-category")
    fun getCategoryBreakdown(
        @AuthUser userId: UUID,
        @RequestParam @Min(2000) @Max(2100) year: Int,
        @RequestParam @Min(1) @Max(12) month: Int,
        @ModelAttribute filter: CommonFilterParams
    ): ApiResponse<List<CategoryStatisticsResponse>> {
        return ApiResponse.ok(statisticsService.getCategoryBreakdown(
            userId, year, month, filter.type, filter.visibility ?: "ALL", filter.dateFrom, filter.dateTo
        ))
    }

    @GetMapping("/payment-methods")
    fun getPaymentMethodStats(
        @AuthUser userId: UUID,
        @RequestParam @Min(2000) @Max(2100) year: Int,
        @RequestParam @Min(1) @Max(12) month: Int,
        @ModelAttribute filter: CommonFilterParams
    ): ApiResponse<List<PaymentMethodStatResponse>> {
        return ApiResponse.ok(paymentMethodStatisticsService.getPaymentMethodStats(
            userId, year, month, filter.visibility ?: "ALL"
        ))
    }

    @GetMapping("/monthly-trend")
    fun getMonthlyTrend(
        @AuthUser userId: UUID,
        @RequestParam(defaultValue = "6") months: Int,
        @ModelAttribute filter: CommonFilterParams
    ): ApiResponse<List<MonthlyTrendResponse>> {
        return ApiResponse.ok(statisticsService.getMonthlyTrend(
            userId, months, filter.visibility ?: "ALL"
        ))
    }
}
