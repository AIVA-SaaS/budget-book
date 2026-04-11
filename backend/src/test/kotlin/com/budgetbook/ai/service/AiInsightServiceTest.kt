package com.budgetbook.ai.service

import com.budgetbook.ai.config.ClaudeApiConfig
import com.budgetbook.ai.dto.InsightResponse
import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import com.budgetbook.statistics.service.StatisticsService
import com.budgetbook.transaction.dto.CategorySummary
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.util.UUID

class AiInsightServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val config = ClaudeApiConfig(apiKey = "test-key", enabled = true)
    val claudeApiClient = mockk<ClaudeApiClient>()
    val statisticsService = mockk<StatisticsService>()
    val redisCacheService = mockk<RedisCacheService>(relaxed = true)
    val objectMapper = ObjectMapper().registerKotlinModule().registerModule(JavaTimeModule())
    val coupleResolver = mockk<CoupleResolver>()

    val service = AiInsightService(
        config, claudeApiClient, statisticsService, redisCacheService,
        objectMapper, coupleResolver
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    every { coupleResolver.getActiveCouple(user1.id) } returns couple

    val currentSummary = StatisticsSummaryResponse("2026-04", 5000000, 3000000, 2000000, 50)
    val prevSummary = StatisticsSummaryResponse("2026-03", 5000000, 2500000, 2500000, 45)
    val catId = UUID.randomUUID()
    val currentBreakdown = listOf(
        CategoryStatisticsResponse(
            category = CategorySummary(catId, "식비", "EXPENSE", "restaurant", "#FF5733"),
            amount = 1000000, percentage = 33.3, transactionCount = 20
        )
    )
    val prevBreakdown = listOf(
        CategoryStatisticsResponse(
            category = CategorySummary(catId, "식비", "EXPENSE", "restaurant", "#FF5733"),
            amount = 800000, percentage = 32.0, transactionCount = 15
        )
    )

    Given("Redis cache has a cached insight") {
        val cached = InsightResponse(
            insights = listOf(
                com.budgetbook.ai.dto.Insight("SPENDING_CHANGE", "지출 증가", "전월 대비 20% 증가", "WARNING")
            )
        )
        every { redisCacheService.get(any()) } returns objectMapper.writeValueAsString(cached)

        When("getInsights is called") {
            val result = service.getInsights(user1.id, 2026, 4)

            Then("it returns cached result") {
                result.insights shouldHaveSize 1
                result.insights[0].type shouldBe "SPENDING_CHANGE"
                verify(exactly = 0) { claudeApiClient.sendMessage(any(), any(), any(), any()) }
            }
        }
    }

    Given("no cache, AI generates insights") {
        every { redisCacheService.get(any()) } returns null
        every { statisticsService.getMonthlySummary(user1.id, 2026, 4) } returns currentSummary
        every { statisticsService.getCategoryBreakdown(user1.id, 2026, 4, "EXPENSE") } returns currentBreakdown
        every { statisticsService.getMonthlySummary(user1.id, 2026, 3) } returns prevSummary
        every { statisticsService.getCategoryBreakdown(user1.id, 2026, 3, "EXPENSE") } returns prevBreakdown

        val aiResponse = """[
            {"type": "SPENDING_CHANGE", "title": "지출 증가", "description": "전월 대비 20% 증가", "severity": "WARNING"},
            {"type": "POSITIVE", "title": "수입 유지", "description": "수입이 안정적입니다", "severity": "POSITIVE"}
        ]"""
        every { claudeApiClient.sendMessage(any(), any(), any(), any()) } returns aiResponse

        When("getInsights is called") {
            val result = service.getInsights(user1.id, 2026, 4)

            Then("it returns parsed insights") {
                result.insights shouldHaveSize 2
                result.insights[0].type shouldBe "SPENDING_CHANGE"
                result.insights[0].title shouldBe "지출 증가"
                result.insights[1].type shouldBe "POSITIVE"
            }
        }
    }

    Given("AI is disabled") {
        val disabledConfig = ClaudeApiConfig(apiKey = "test-key", enabled = false)
        val disabledService = AiInsightService(
            disabledConfig, claudeApiClient, statisticsService, redisCacheService,
            objectMapper, coupleResolver
        )

        When("getInsights is called") {
            val result = disabledService.getInsights(user1.id, 2026, 4)

            Then("it returns empty insights without calling AI") {
                result.insights.shouldBeEmpty()
                verify(exactly = 0) { claudeApiClient.sendMessage(any(), any(), any(), any()) }
                verify(exactly = 0) { statisticsService.getMonthlySummary(any(), any(), any()) }
            }
        }
    }

    Given("AI call returns null") {
        every { redisCacheService.get(any()) } returns null
        every { statisticsService.getMonthlySummary(user1.id, 2026, 4) } returns currentSummary
        every { statisticsService.getCategoryBreakdown(user1.id, 2026, 4, "EXPENSE") } returns currentBreakdown
        every { statisticsService.getMonthlySummary(user1.id, 2026, 3) } returns prevSummary
        every { statisticsService.getCategoryBreakdown(user1.id, 2026, 3, "EXPENSE") } returns prevBreakdown
        every { claudeApiClient.sendMessage(any(), any(), any(), any()) } returns null

        When("getInsights is called") {
            val result = service.getInsights(user1.id, 2026, 4)

            Then("it returns empty insights gracefully") {
                result.insights.shouldBeEmpty()
            }
        }
    }
})
