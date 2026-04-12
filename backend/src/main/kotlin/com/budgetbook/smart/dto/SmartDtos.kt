package com.budgetbook.smart.dto

import java.time.Instant
import java.util.UUID

data class ClassifySuggestion(
    val categoryId: UUID,
    val categoryName: String,
    val groupName: String?,
    val confidence: Double,
    val source: String // PATTERN or HISTORY
)

data class Insight(
    val type: String, // SPENDING_CHANGE, BUDGET_WARNING, PATTERN, TIP, POSITIVE, BUDGET_ADJUST
    val title: String,
    val message: String,
    val severity: String, // INFO, WARNING, POSITIVE
    val data: Map<String, Any>? = null
)

data class InsightsResponse(
    val insights: List<Insight>,
    val generatedAt: Instant = Instant.now()
)

data class BudgetSuggestion(
    val budgetId: UUID,
    val budgetName: String,
    val currentAmount: Long,
    val suggestedAmount: Long,
    val avgSpending: Long,
    val reason: String
)
