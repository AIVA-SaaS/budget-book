package com.budgetbook.ai.service

import com.budgetbook.ai.config.ClaudeApiConfig
import com.budgetbook.ai.dto.ClassifyResponse
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.service.CategoryService
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.transaction.service.TransactionService
import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.security.MessageDigest
import java.time.Duration
import java.util.UUID

@Service
class AiClassificationService(
    private val config: ClaudeApiConfig,
    private val claudeApiClient: ClaudeApiClient,
    private val transactionService: TransactionService,
    private val categoryService: CategoryService,
    private val redisCacheService: RedisCacheService,
    private val objectMapper: ObjectMapper,
    override val coupleResolver: CoupleResolver
) : CoupleAwareService {

    private val log = LoggerFactory.getLogger(javaClass)

    companion object {
        private val CACHE_TTL = Duration.ofDays(30)
        private const val CACHE_PREFIX = "ai:classify"
    }

    @Transactional(readOnly = true)
    fun classify(userId: UUID, description: String, type: String): ClassifyResponse {
        val couple = getActiveCouple(userId)
        val cacheKey = "$CACHE_PREFIX:${couple.id}:${hash("$description:$type")}"

        // 1. Check Redis cache
        redisCacheService.get(cacheKey)?.let { cached ->
            return try {
                objectMapper.readValue(cached, ClassifyResponse::class.java)
            } catch (e: Exception) {
                log.warn("Failed to deserialize cached classify response: {}", e.message)
                redisCacheService.evict(cacheKey)
                // continue to pattern matching
                classifyFresh(userId, description, type, cacheKey)
            }
        }

        return classifyFresh(userId, description, type, cacheKey)
    }

    private fun classifyFresh(
        userId: UUID,
        description: String,
        type: String,
        cacheKey: String
    ): ClassifyResponse {
        // 2. Try pattern matching from existing transactions
        val suggestions = transactionService.getSuggestions(userId, description, 1)
        if (suggestions.isNotEmpty()) {
            val topPattern = suggestions.first().patterns.first()
            if (topPattern.categoryId != null) {
                val response = ClassifyResponse(
                    categoryId = topPattern.categoryId,
                    categoryName = topPattern.categoryName,
                    groupName = null,
                    confidence = 0.9,
                    source = "PATTERN"
                )
                cacheResponse(cacheKey, response)
                return response
            }
        }

        // 3. AI classification (if enabled)
        if (!config.enabled) {
            return ClassifyResponse(source = "PATTERN")
        }

        return classifyWithAi(userId, description, type, cacheKey)
    }

    private fun classifyWithAi(
        userId: UUID,
        description: String,
        type: String,
        cacheKey: String
    ): ClassifyResponse {
        val categoryType = if (type.uppercase() == "INCOME") CategoryType.INCOME else CategoryType.EXPENSE
        val categories = categoryService.listCategories(userId, categoryType)

        val categoriesJson = objectMapper.writeValueAsString(
            categories.map { cat ->
                mapOf(
                    "id" to cat.id.toString(),
                    "name" to cat.name,
                    "groupId" to cat.groupId?.toString(),
                )
            }
        )

        val systemPrompt = """당신은 가계부 거래 카테고리 분류 전문가입니다.
주어진 카테고리 목록에서 거래 설명에 가장 적합한 카테고리를 선택하세요.
반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트를 포함하지 마세요.
{"categoryId": "uuid-string", "confidence": 0.0~1.0}
적합한 카테고리가 없으면 {"categoryId": null, "confidence": 0.0}"""

        val userMessage = """카테고리 목록: $categoriesJson
거래 설명: $description
거래 유형: $type"""

        val aiResponse = claudeApiClient.sendMessage(
            model = config.classifyModel,
            systemPrompt = systemPrompt,
            userMessage = userMessage,
            maxTokens = 128
        ) ?: return ClassifyResponse(source = "AI")

        return try {
            val parsed = objectMapper.readTree(aiResponse)
            val categoryIdStr = parsed.get("categoryId")?.asText()
            val confidence = parsed.get("confidence")?.asDouble() ?: 0.0

            if (categoryIdStr.isNullOrBlank() || categoryIdStr == "null") {
                return ClassifyResponse(confidence = confidence, source = "AI")
            }

            val categoryId = UUID.fromString(categoryIdStr)
            val matchedCategory = categories.find { it.id == categoryId }

            val response = ClassifyResponse(
                categoryId = categoryId,
                categoryName = matchedCategory?.name,
                groupName = null,
                confidence = confidence,
                source = "AI"
            )
            cacheResponse(cacheKey, response)
            response
        } catch (e: Exception) {
            log.warn("Failed to parse AI classify response: {}", e.message)
            ClassifyResponse(source = "AI")
        }
    }

    private fun cacheResponse(cacheKey: String, response: ClassifyResponse) {
        try {
            redisCacheService.set(cacheKey, objectMapper.writeValueAsString(response), CACHE_TTL)
        } catch (e: Exception) {
            log.warn("Failed to cache classify response: {}", e.message)
        }
    }

    private fun hash(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(input.toByteArray()).joinToString("") { "%02x".format(it) }.take(16)
    }
}
