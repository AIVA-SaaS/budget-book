package com.budgetbook.report.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.report.dto.MonthlyReportResponse
import com.budgetbook.report.dto.WeeklyReportResponse
import com.budgetbook.report.service.ReportService
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@Validated
@RestController
@RequestMapping("/api/v1/reports")
class ReportController(
    private val reportService: ReportService
) {

    @GetMapping("/weekly")
    fun getWeeklyReport(
        @AuthUser userId: UUID,
        @RequestParam @Min(2000) @Max(2100) year: Int,
        @RequestParam @Min(1) @Max(12) month: Int,
        @RequestParam @Min(1) @Max(6) week: Int
    ): ApiResponse<WeeklyReportResponse> {
        return ApiResponse.ok(reportService.getWeeklyReport(userId, year, month, week))
    }

    @GetMapping("/monthly")
    fun getMonthlyReport(
        @AuthUser userId: UUID,
        @RequestParam @Min(2000) @Max(2100) year: Int,
        @RequestParam @Min(1) @Max(12) month: Int
    ): ApiResponse<MonthlyReportResponse> {
        return ApiResponse.ok(reportService.getMonthlyReport(userId, year, month))
    }
}
