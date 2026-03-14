package com.budgetbook.budget.controller

import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetResponse
import com.budgetbook.budget.dto.BudgetSummaryResponse
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.dto.CopyBudgetRequest
import com.budgetbook.budget.dto.CurrentWeekSummaryResponse
import com.budgetbook.budget.dto.WeeklyOverviewResponse
import com.budgetbook.budget.service.BudgetService
import com.budgetbook.budget.service.WeeklyBudgetService
import com.budgetbook.common.dto.ApiResponse
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
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
    private val weeklyBudgetService: WeeklyBudgetService
) {

    @PostMapping
    fun createBudget(
        authentication: Authentication,
        @Valid @RequestBody request: BudgetRequest
    ): ResponseEntity<ApiResponse<BudgetResponse>> {
        val userId = authentication.principal as UUID
        val result = budgetService.createBudget(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @GetMapping
    fun listBudgets(
        authentication: Authentication,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<List<BudgetResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(budgetService.getBudgetsByMonth(userId, year, month))
    }

    @PutMapping("/{id}")
    fun updateBudget(
        authentication: Authentication,
        @PathVariable id: UUID,
        @Valid @RequestBody request: BudgetUpdateRequest
    ): ApiResponse<BudgetResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(budgetService.updateBudget(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteBudget(
        authentication: Authentication,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        val userId = authentication.principal as UUID
        budgetService.deleteBudget(userId, id)
        return ResponseEntity.noContent().build()
    }

    @PostMapping("/copy-previous")
    fun copyFromPreviousMonth(
        authentication: Authentication,
        @Valid @RequestBody request: CopyBudgetRequest
    ): ResponseEntity<ApiResponse<List<BudgetResponse>>> {
        val userId = authentication.principal as UUID
        val result = budgetService.copyFromPreviousMonth(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @GetMapping("/summary")
    fun getBudgetSummary(
        authentication: Authentication,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<BudgetSummaryResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(budgetService.getBudgetSummary(userId, year, month))
    }

    @GetMapping("/weekly")
    fun getWeeklyOverview(
        authentication: Authentication,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<WeeklyOverviewResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(weeklyBudgetService.getWeeklyOverview(userId, year, month))
    }

    @GetMapping("/weekly/current")
    fun getCurrentWeekSummary(
        authentication: Authentication
    ): ApiResponse<CurrentWeekSummaryResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(weeklyBudgetService.getCurrentWeekSummary(userId))
    }
}
