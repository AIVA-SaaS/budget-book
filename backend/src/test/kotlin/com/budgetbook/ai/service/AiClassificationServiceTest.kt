package com.budgetbook.ai.service

import com.budgetbook.ai.config.ClaudeApiConfig
import com.budgetbook.ai.dto.ClassifyResponse
import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.category.dto.CategoryResponse
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.service.CategoryService
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.SuggestionPattern
import com.budgetbook.transaction.dto.SuggestionResponse
import com.budgetbook.transaction.service.TransactionService
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.Instant
import java.util.UUID

class AiClassificationServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val config = ClaudeApiConfig(apiKey = "test-key", enabled = true)
    val claudeApiClient = mockk<ClaudeApiClient>()
    val transactionService = mockk<TransactionService>()
    val categoryService = mockk<CategoryService>()
    val redisCacheService = mockk<RedisCacheService>(relaxed = true)
    val objectMapper = ObjectMapper().registerKotlinModule().registerModule(JavaTimeModule())
    val coupleResolver = mockk<CoupleResolver>()

    val service = AiClassificationService(
        config, claudeApiClient, transactionService, categoryService,
        redisCacheService, objectMapper, coupleResolver
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    every { coupleResolver.getActiveCouple(user1.id) } returns couple

    Given("Redis cache has a cached result") {
        val cachedResponse = ClassifyResponse(
            categoryId = UUID.randomUUID(),
            categoryName = "식비",
            confidence = 0.95,
            source = "CACHE"
        )
        every { redisCacheService.get(any()) } returns objectMapper.writeValueAsString(cachedResponse)

        When("classify is called") {
            val result = service.classify(user1.id, "스타벅스 커피", "EXPENSE")

            Then("it returns cached result without calling AI or pattern matching") {
                result.categoryId shouldBe cachedResponse.categoryId
                result.categoryName shouldBe "식비"
                result.source shouldBe "CACHE"
                verify(exactly = 0) { transactionService.getSuggestions(any(), any(), any(), any()) }
                verify(exactly = 0) { claudeApiClient.sendMessage(any(), any(), any(), any()) }
            }
        }
    }

    Given("no cache, but pattern matching finds a result") {
        every { redisCacheService.get(any()) } returns null

        val catId = UUID.randomUUID()
        val suggestions = listOf(
            SuggestionResponse(
                description = "스타벅스",
                patterns = listOf(
                    SuggestionPattern(
                        categoryId = catId,
                        categoryName = "카페",
                        categoryIcon = "coffee",
                        categoryColor = "#8B4513",
                        paymentMethodId = null,
                        paymentMethodName = null,
                        count = 10
                    )
                )
            )
        )
        every { transactionService.getSuggestions(user1.id, "스타벅스 커피", 1, TransactionType.EXPENSE) } returns suggestions

        When("classify is called") {
            val result = service.classify(user1.id, "스타벅스 커피", "EXPENSE")

            Then("it returns pattern match result") {
                result.categoryId shouldBe catId
                result.categoryName shouldBe "카페"
                result.source shouldBe "PATTERN"
                result.confidence shouldBe 0.9
                verify(exactly = 0) { claudeApiClient.sendMessage(any(), any(), any(), any()) }
            }
        }
    }

    Given("no cache, no pattern match, AI is enabled") {
        every { redisCacheService.get(any()) } returns null
        every { transactionService.getSuggestions(user1.id, "새로운 가게", 1, TransactionType.EXPENSE) } returns emptyList()

        val catId = UUID.randomUUID()
        val categories = listOf(
            CategoryResponse(
                id = catId, name = "식비", type = "EXPENSE",
                icon = "restaurant", color = "#FF5733",
                isDefault = true, displayOrder = 0, createdAt = Instant.now()
            )
        )
        every { categoryService.listCategories(user1.id, CategoryType.EXPENSE) } returns categories

        val aiJson = """{"categoryId": "$catId", "confidence": 0.85}"""
        every { claudeApiClient.sendMessage(any(), any(), any(), any()) } returns aiJson

        When("classify is called") {
            val result = service.classify(user1.id, "새로운 가게", "EXPENSE")

            Then("it returns AI classification result") {
                result.categoryId shouldBe catId
                result.categoryName shouldBe "식비"
                result.source shouldBe "AI"
                result.confidence shouldBe 0.85
            }
        }
    }

    Given("AI is disabled") {
        val disabledConfig = ClaudeApiConfig(apiKey = "test-key", enabled = false)
        val disabledService = AiClassificationService(
            disabledConfig, claudeApiClient, transactionService, categoryService,
            redisCacheService, objectMapper, coupleResolver
        )

        every { redisCacheService.get(any()) } returns null
        every { transactionService.getSuggestions(user1.id, "새로운 가게", 1, TransactionType.EXPENSE) } returns emptyList()

        When("classify is called with no pattern match") {
            val result = disabledService.classify(user1.id, "새로운 가게", "EXPENSE")

            Then("it returns empty PATTERN response without calling AI") {
                result.categoryId shouldBe null
                result.source shouldBe "PATTERN"
                verify(exactly = 0) { claudeApiClient.sendMessage(any(), any(), any(), any()) }
            }
        }
    }

    Given("AI call fails") {
        every { redisCacheService.get(any()) } returns null
        every { transactionService.getSuggestions(user1.id, "실패 테스트", 1, TransactionType.EXPENSE) } returns emptyList()

        val categories = listOf(
            CategoryResponse(
                id = UUID.randomUUID(), name = "기타", type = "EXPENSE",
                icon = null, color = null,
                isDefault = true, displayOrder = 0, createdAt = Instant.now()
            )
        )
        every { categoryService.listCategories(user1.id, CategoryType.EXPENSE) } returns categories
        every { claudeApiClient.sendMessage(any(), any(), any(), any()) } returns null

        When("classify is called") {
            val result = service.classify(user1.id, "실패 테스트", "EXPENSE")

            Then("it returns empty AI response gracefully") {
                result.categoryId shouldBe null
                result.source shouldBe "AI"
            }
        }
    }
})
