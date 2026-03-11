package com.budgetbook.report.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.report.dto.MonthlyReportResponse
import com.budgetbook.report.dto.WeeklyReportResponse
import com.budgetbook.report.service.ReportService
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/reports")
class ReportController(
    private val reportService: ReportService
) {

    @GetMapping("/weekly")
    fun getWeeklyReport(
        authentication: Authentication,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam week: Int
    ): ApiResponse<WeeklyReportResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(reportService.getWeeklyReport(userId, year, month, week))
    }

    @GetMapping("/monthly")
    fun getMonthlyReport(
        authentication: Authentication,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<MonthlyReportResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(reportService.getMonthlyReport(userId, year, month))
    }
}
