package com.budgetbook.smart.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.security.AuthUser
import com.budgetbook.smart.dto.BudgetSuggestion
import com.budgetbook.smart.dto.ClassifySuggestion
import com.budgetbook.smart.dto.InsightsResponse
import com.budgetbook.smart.service.PatternLearningService
import com.budgetbook.smart.service.SmartAnalysisService
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
@RequestMapping("/api/v1/smart")
class SmartAnalysisController(
    private val patternLearningService: PatternLearningService,
    private val analysisService: SmartAnalysisService
) {

    @GetMapping("/classify")
    @RateLimit(maxRequests = 10, windowSeconds = 60)
    fun classify(
        @AuthUser userId: UUID,
        @RequestParam description: String
    ): ApiResponse<List<ClassifySuggestion>> {
        val couple = analysisService.coupleResolver.getActiveCouple(userId)
        val suggestions = patternLearningService.suggest(couple.id, description)
        return ApiResponse.ok(suggestions)
    }

    @GetMapping("/insights")
    @RateLimit(maxRequests = 5, windowSeconds = 3600)
    fun getInsights(
        @AuthUser userId: UUID,
        @RequestParam @Min(2000) @Max(2100) year: Int,
        @RequestParam @Min(1) @Max(12) month: Int
    ): ApiResponse<InsightsResponse> {
        val result = analysisService.generateInsights(userId, year, month)
        return ApiResponse.ok(result)
    }

    @GetMapping("/budget-suggestions")
    @RateLimit(maxRequests = 5, windowSeconds = 3600)
    fun getBudgetSuggestions(
        @AuthUser userId: UUID
    ): ApiResponse<List<BudgetSuggestion>> {
        val result = analysisService.getBudgetSuggestions(userId)
        return ApiResponse.ok(result)
    }
}
