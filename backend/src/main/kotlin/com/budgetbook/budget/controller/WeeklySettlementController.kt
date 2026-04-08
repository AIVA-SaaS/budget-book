package com.budgetbook.budget.controller

import com.budgetbook.budget.dto.SettleWeekRequest
import com.budgetbook.budget.dto.UnsettleWeekRequest
import com.budgetbook.budget.dto.WeeklySettlementOverviewResponse
import com.budgetbook.budget.service.WeeklySettlementService
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import jakarta.validation.Valid
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@Validated
@RestController
@RequestMapping("/api/v1/budgets/weekly/settlements")
class WeeklySettlementController(
    private val weeklySettlementService: WeeklySettlementService
) {

    @GetMapping
    fun getSettlementOverview(
        @AuthUser userId: UUID,
        @RequestParam @Min(2000) @Max(2100) year: Int,
        @RequestParam @Min(1) @Max(12) month: Int
    ): ApiResponse<WeeklySettlementOverviewResponse> {
        return ApiResponse.ok(weeklySettlementService.getSettlementOverview(userId, year, month))
    }

    @PostMapping("/settle")
    fun settleWeek(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: SettleWeekRequest
    ): ApiResponse<Unit> {
        weeklySettlementService.settleWeek(userId, request)
        return ApiResponse.ok()
    }

    @PostMapping("/unsettle")
    fun unsettleWeek(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: UnsettleWeekRequest
    ): ApiResponse<Unit> {
        weeklySettlementService.unsettleWeek(userId, request)
        return ApiResponse.ok()
    }
}
