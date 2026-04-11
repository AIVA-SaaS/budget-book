package com.budgetbook.ai.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "ai.claude")
data class ClaudeApiConfig(
    val apiKey: String = "",
    val enabled: Boolean = false,
    val classifyModel: String = "claude-haiku-4-5-20251001",
    val insightModel: String = "claude-sonnet-4-6-20250514",
    val baseUrl: String = "https://api.anthropic.com",
)
