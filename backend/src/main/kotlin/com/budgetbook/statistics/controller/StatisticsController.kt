package com.budgetbook.statistics.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.common.security.AuthUser
import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.MonthlyTrendResponse
import com.budgetbook.statistics.dto.PaymentMethodStatResponse
import com.budgetbook.statistics.dto.PeriodSummaryResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import org.springframework.format.annotation.DateTimeFormat
import java.time.LocalDate
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
        // 2026-08-12 — 필터는 VO 를 **통째로** 넘긴다.
        // 필드를 하나씩 나열하면 새 축이 추가될 때 조용히 누락된다(4회 재발 원인).
        return ApiResponse.ok(statisticsService.getMonthlySummary(userId, year, month, filter))
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
        // 회차 11-1 — dateFrom/dateTo 전달 (통계 페이지의 dateRange 필터 일관성)
        return ApiResponse.ok(paymentMethodStatisticsService.getPaymentMethodStats(
            userId = userId,
            year = year,
            month = month,
            visibility = filter.visibility ?: "ALL",
            dateFrom = filter.dateFrom,
            dateTo = filter.dateTo
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

    @GetMapping("/period-summary")
    fun getPeriodSummary(
        @AuthUser userId: UUID,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) dateFrom: LocalDate,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) dateTo: LocalDate,
        @ModelAttribute filter: CommonFilterParams
    ): ApiResponse<PeriodSummaryResponse> {
        // 필터 VO 통째로 전달 (getMonthlySummary 와 동일 규칙).
        return ApiResponse.ok(statisticsService.getPeriodSummary(userId, dateFrom, dateTo, filter))
    }
}
