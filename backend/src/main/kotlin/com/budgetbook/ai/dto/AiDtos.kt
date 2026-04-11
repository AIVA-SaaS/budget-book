package com.budgetbook.ai.dto

import jakarta.validation.constraints.NotBlank
import java.time.Instant
import java.util.UUID

data class ClassifyRequest(
    @field:NotBlank
    val description: String,

    @field:NotBlank
    val type: String // INCOME or EXPENSE
)

data class ClassifyResponse(
    val categoryId: UUID? = null,
    val categoryName: String? = null,
    val groupName: String? = null,
    val confidence: Double = 0.0,
    val source: String // CACHE, PATTERN, AI
)

data class InsightResponse(
    val insights: List<Insight>,
    val generatedAt: Instant = Instant.now()
)

data class Insight(
    val type: String, // SPENDING_CHANGE, BUDGET_WARNING, PATTERN, TIP, POSITIVE
    val title: String,
    val description: String,
    val severity: String // INFO, WARNING, POSITIVE
)
