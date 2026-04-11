package com.budgetbook.ai.service

import com.budgetbook.ai.config.ClaudeApiConfig
import com.budgetbook.ai.dto.Insight
import com.budgetbook.ai.dto.InsightResponse
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.statistics.service.StatisticsService
import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Duration
import java.time.YearMonth
import java.util.UUID

@Service
class AiInsightService(
    private val config: ClaudeApiConfig,
    private val claudeApiClient: ClaudeApiClient,
    private val statisticsService: StatisticsService,
    private val redisCacheService: RedisCacheService,
    private val objectMapper: ObjectMapper,
    override val coupleResolver: CoupleResolver
) : CoupleAwareService {

    private val log = LoggerFactory.getLogger(javaClass)

    companion object {
        private val CACHE_TTL = Duration.ofDays(7)
        private const val CACHE_PREFIX = "ai:insight"
    }

    @Transactional(readOnly = true)
    fun getInsights(userId: UUID, year: Int, month: Int): InsightResponse {
        if (!config.enabled) {
            return InsightResponse(insights = emptyList())
        }

        val couple = getActiveCouple(userId)
        val yearMonth = YearMonth.of(year, month)
        val cacheKey = "$CACHE_PREFIX:${couple.id}:$yearMonth"

        // 1. Check Redis cache
        redisCacheService.get(cacheKey)?.let { cached ->
            return try {
                objectMapper.readValue(cached, InsightResponse::class.java)
            } catch (e: Exception) {
                log.warn("Failed to deserialize cached insight response: {}", e.message)
                redisCacheService.evict(cacheKey)
                generateInsights(userId, year, month, cacheKey)
            }
        }

        return generateInsights(userId, year, month, cacheKey)
    }

    private fun generateInsights(userId: UUID, year: Int, month: Int, cacheKey: String): InsightResponse {
        // 2. Collect statistics data
        val currentSummary = statisticsService.getMonthlySummary(userId, year, month)
        val currentBreakdown = statisticsService.getCategoryBreakdown(userId, year, month, "EXPENSE")

        val prevMonth = YearMonth.of(year, month).minusMonths(1)
        val prevSummary = statisticsService.getMonthlySummary(userId, prevMonth.year, prevMonth.monthValue)
        val prevBreakdown = statisticsService.getCategoryBreakdown(userId, prevMonth.year, prevMonth.monthValue, "EXPENSE")

        val statsData = mapOf(
            "currentMonth" to mapOf(
                "yearMonth" to currentSummary.yearMonth,
                "totalIncome" to currentSummary.totalIncome,
                "totalExpense" to currentSummary.totalExpense,
                "balance" to currentSummary.balance,
                "categories" to currentBreakdown.map { cat ->
                    mapOf(
                        "name" to cat.category.name,
                        "amount" to cat.amount,
                        "percentage" to cat.percentage
                    )
                }
            ),
            "previousMonth" to mapOf(
                "yearMonth" to prevSummary.yearMonth,
                "totalIncome" to prevSummary.totalIncome,
                "totalExpense" to prevSummary.totalExpense,
                "balance" to prevSummary.balance,
                "categories" to prevBreakdown.map { cat ->
                    mapOf(
                        "name" to cat.category.name,
                        "amount" to cat.amount,
                        "percentage" to cat.percentage
                    )
                }
            )
        )

        val systemPrompt = """당신은 가계부 AI 어드바이저입니다. 한국어로 3-5개의 소비 인사이트를 제공하세요.
반드시 아래 JSON 배열 형식으로만 응답하세요. 다른 텍스트를 포함하지 마세요.
[{"type": "SPENDING_CHANGE|BUDGET_WARNING|PATTERN|TIP|POSITIVE", "title": "제목", "description": "설명", "severity": "INFO|WARNING|POSITIVE"}]
- SPENDING_CHANGE: 전월 대비 지출 변화
- BUDGET_WARNING: 예산 초과 경고
- PATTERN: 소비 패턴 분석
- TIP: 절약 팁
- POSITIVE: 긍정적 피드백"""

        val userMessage = objectMapper.writeValueAsString(statsData)

        val aiResponse = claudeApiClient.sendMessage(
            model = config.insightModel,
            systemPrompt = systemPrompt,
            userMessage = userMessage,
            maxTokens = 1024
        ) ?: return InsightResponse(insights = emptyList())

        return try {
            val insights = objectMapper.readTree(aiResponse).map { node ->
                Insight(
                    type = node.get("type")?.asText() ?: "TIP",
                    title = node.get("title")?.asText() ?: "",
                    description = node.get("description")?.asText() ?: "",
                    severity = node.get("severity")?.asText() ?: "INFO"
                )
            }

            val response = InsightResponse(insights = insights)
            try {
                redisCacheService.set(cacheKey, objectMapper.writeValueAsString(response), CACHE_TTL)
            } catch (e: Exception) {
                log.warn("Failed to cache insight response: {}", e.message)
            }
            response
        } catch (e: Exception) {
            log.warn("Failed to parse AI insight response: {}", e.message)
            InsightResponse(insights = emptyList())
        }
    }
}
