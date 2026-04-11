package com.budgetbook.ai.service

import com.budgetbook.ai.config.ClaudeApiConfig
import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.boot.web.client.RestTemplateBuilder
import org.springframework.http.HttpEntity
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.stereotype.Component
import java.time.Duration

@Component
class ClaudeApiClient(
    private val config: ClaudeApiConfig,
    private val objectMapper: ObjectMapper,
    restTemplateBuilder: RestTemplateBuilder
) {

    private val log = LoggerFactory.getLogger(javaClass)

    private val restTemplate = restTemplateBuilder
        .setConnectTimeout(Duration.ofSeconds(10))
        .setReadTimeout(Duration.ofSeconds(30))
        .build()

    fun sendMessage(
        model: String,
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = 1024
    ): String? {
        if (config.apiKey.isBlank()) {
            log.warn("Claude API key not configured, skipping API call")
            return null
        }

        return try {
            val headers = HttpHeaders().apply {
                contentType = MediaType.APPLICATION_JSON
                set("x-api-key", config.apiKey)
                set("anthropic-version", "2023-06-01")
            }

            val body = mapOf(
                "model" to model,
                "max_tokens" to maxTokens,
                "system" to systemPrompt,
                "messages" to listOf(
                    mapOf("role" to "user", "content" to userMessage)
                )
            )

            val request = HttpEntity(objectMapper.writeValueAsString(body), headers)
            val url = "${config.baseUrl}/v1/messages"

            val response = restTemplate.postForObject(url, request, Map::class.java)

            val content = response?.get("content") as? List<*>
            val firstBlock = content?.firstOrNull() as? Map<*, *>
            firstBlock?.get("text") as? String
        } catch (e: Exception) {
            log.error("Claude API call failed: {}", e.message)
            null
        }
    }
}
