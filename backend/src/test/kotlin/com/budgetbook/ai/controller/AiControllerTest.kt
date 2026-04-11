package com.budgetbook.ai.controller

import com.budgetbook.ai.dto.ClassifyResponse
import com.budgetbook.ai.dto.Insight
import com.budgetbook.ai.dto.InsightResponse
import com.budgetbook.ai.service.AiClassificationService
import com.budgetbook.ai.service.AiInsightService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.util.UUID

class AiControllerTest : FunSpec({

    val classificationService = mockk<AiClassificationService>()
    val insightService = mockk<AiInsightService>()
    val controller = AiController(classificationService, insightService)
    val testUserId = UUID.randomUUID()

    test("classify returns AI classification result") {
        val catId = UUID.randomUUID()
        val classifyResponse = ClassifyResponse(
            categoryId = catId,
            categoryName = "식비",
            groupName = "생활비",
            confidence = 0.92,
            source = "AI"
        )
        every { classificationService.classify(testUserId, "스타벅스", "EXPENSE") } returns classifyResponse

        val request = com.budgetbook.ai.dto.ClassifyRequest(description = "스타벅스", type = "EXPENSE")
        val result = controller.classify(testUserId, request)

        result.success shouldBe true
        result.data!!.categoryId shouldBe catId
        result.data!!.categoryName shouldBe "식비"
        result.data!!.confidence shouldBe 0.92
        result.data!!.source shouldBe "AI"
    }

    test("classify returns empty result when no match") {
        val classifyResponse = ClassifyResponse(source = "PATTERN")
        every { classificationService.classify(testUserId, "알수없는", "EXPENSE") } returns classifyResponse

        val request = com.budgetbook.ai.dto.ClassifyRequest(description = "알수없는", type = "EXPENSE")
        val result = controller.classify(testUserId, request)

        result.success shouldBe true
        result.data!!.categoryId shouldBe null
        result.data!!.source shouldBe "PATTERN"
    }

    test("getInsights returns AI insights") {
        val insightResponse = InsightResponse(
            insights = listOf(
                Insight("SPENDING_CHANGE", "지출 증가", "전월 대비 20% 증가", "WARNING"),
                Insight("POSITIVE", "저축 증가", "저축률이 40%입니다", "POSITIVE")
            )
        )
        every { insightService.getInsights(testUserId, 2026, 4) } returns insightResponse

        val result = controller.getInsights(testUserId, 2026, 4)

        result.success shouldBe true
        result.data!!.insights.size shouldBe 2
        result.data!!.insights[0].type shouldBe "SPENDING_CHANGE"
        result.data!!.insights[1].severity shouldBe "POSITIVE"
    }

    test("getInsights returns empty when AI disabled") {
        val emptyResponse = InsightResponse(insights = emptyList())
        every { insightService.getInsights(testUserId, 2026, 4) } returns emptyResponse

        val result = controller.getInsights(testUserId, 2026, 4)

        result.success shouldBe true
        result.data!!.insights.size shouldBe 0
    }
})
