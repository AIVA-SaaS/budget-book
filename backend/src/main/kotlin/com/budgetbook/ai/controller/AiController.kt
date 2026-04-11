package com.budgetbook.ai.controller

import com.budgetbook.ai.dto.ClassifyRequest
import com.budgetbook.ai.dto.ClassifyResponse
import com.budgetbook.ai.dto.InsightResponse
import com.budgetbook.ai.service.AiClassificationService
import com.budgetbook.ai.service.AiInsightService
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/ai")
class AiController(
    private val classificationService: AiClassificationService,
    private val insightService: AiInsightService
) {

    @PostMapping("/classify")
    fun classify(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: ClassifyRequest
    ): ApiResponse<ClassifyResponse> {
        val result = classificationService.classify(userId, request.description, request.type)
        return ApiResponse.ok(result)
    }

    @GetMapping("/insights")
    fun getInsights(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<InsightResponse> {
        val result = insightService.getInsights(userId, year, month)
        return ApiResponse.ok(result)
    }
}
