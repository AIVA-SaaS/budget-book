package com.budgetbook.budget.controller

import com.budgetbook.budget.dto.BudgetAlertResponse
import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetResponse
import com.budgetbook.budget.dto.BudgetSummaryResponse
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.dto.CopyBudgetRequest
import com.budgetbook.budget.dto.CurrentWeekSummaryResponse
import com.budgetbook.budget.dto.WeeklyOverviewResponse
import com.budgetbook.budget.service.BudgetAlertService
import com.budgetbook.budget.service.BudgetService
import com.budgetbook.budget.service.WeeklyBudgetService
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/budgets")
class BudgetController(
    private val budgetService: BudgetService,
    private val weeklyBudgetService: WeeklyBudgetService,
    private val budgetAlertService: BudgetAlertService
) {

    @PostMapping
    fun createBudget(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: BudgetRequest
    ): ResponseEntity<ApiResponse<BudgetResponse>> {
        val result = budgetService.createBudget(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @GetMapping
    fun listBudgets(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<List<BudgetResponse>> {
        return ApiResponse.ok(budgetService.getBudgetsByMonth(userId, year, month))
    }

    @PutMapping("/{id}")
    fun updateBudget(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: BudgetUpdateRequest
    ): ApiResponse<BudgetResponse> {
        return ApiResponse.ok(budgetService.updateBudget(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteBudget(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        budgetService.deleteBudget(userId, id)
        return ResponseEntity.noContent().build()
    }

    @PostMapping("/copy-previous")
    fun copyFromPreviousMonth(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CopyBudgetRequest
    ): ResponseEntity<ApiResponse<List<BudgetResponse>>> {
        val result = budgetService.copyFromPreviousMonth(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @GetMapping("/alerts")
    fun getBudgetAlerts(
        @AuthUser userId: UUID,
        @RequestParam yearMonth: String
    ): ApiResponse<List<BudgetAlertResponse>> {
        return ApiResponse.ok(budgetAlertService.getBudgetAlerts(userId, yearMonth))
    }

    @GetMapping("/summary")
    fun getBudgetSummary(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<BudgetSummaryResponse> {
        return ApiResponse.ok(budgetService.getBudgetSummary(userId, year, month))
    }

    @GetMapping("/weekly")
    fun getWeeklyOverview(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<WeeklyOverviewResponse> {
        return ApiResponse.ok(weeklyBudgetService.getWeeklyOverview(userId, year, month))
    }

    @GetMapping("/weekly/current")
    fun getCurrentWeekSummary(@AuthUser userId: UUID): ApiResponse<CurrentWeekSummaryResponse> {
        return ApiResponse.ok(weeklyBudgetService.getCurrentWeekSummary(userId))
    }
}
