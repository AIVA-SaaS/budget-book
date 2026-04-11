package com.budgetbook.common.ratelimit

@Target(AnnotationTarget.FUNCTION)
@Retention(AnnotationRetention.RUNTIME)
annotation class RateLimit(
    val maxRequests: Int = 30,
    val windowSeconds: Int = 60,
    val keyType: RateLimitKeyType = RateLimitKeyType.USER,
)

enum class RateLimitKeyType {
    USER,
    IP,
}
