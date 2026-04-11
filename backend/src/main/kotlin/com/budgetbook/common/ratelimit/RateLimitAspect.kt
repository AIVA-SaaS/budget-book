package com.budgetbook.common.ratelimit

import com.budgetbook.common.exception.TooManyRequestsException
import jakarta.servlet.http.HttpServletRequest
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.annotation.Around
import org.aspectj.lang.annotation.Aspect
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Component
import org.springframework.web.context.request.RequestContextHolder
import org.springframework.web.context.request.ServletRequestAttributes
import java.util.UUID

@Aspect
@Component
class RateLimitAspect(
    private val rateLimiter: RateLimiter
) {

    @Around("@annotation(rateLimit)")
    fun checkRateLimit(joinPoint: ProceedingJoinPoint, rateLimit: RateLimit): Any? {
        val key = resolveKey(rateLimit.keyType)
        val limitKey = "$key:${joinPoint.signature.name}"
        val windowMillis = rateLimit.windowSeconds * 1000L

        if (!rateLimiter.tryAcquire(limitKey, rateLimit.maxRequests, windowMillis)) {
            throw TooManyRequestsException(
                "RATE_LIMIT_EXCEEDED",
                "Rate limit exceeded. Please try again later."
            )
        }

        return joinPoint.proceed()
    }

    private fun resolveKey(keyType: RateLimitKeyType): String {
        return when (keyType) {
            RateLimitKeyType.USER -> {
                val authentication = SecurityContextHolder.getContext().authentication
                val userId = authentication?.principal as? UUID
                userId?.toString() ?: resolveClientIp()
            }
            RateLimitKeyType.IP -> resolveClientIp()
        }
    }

    private fun resolveClientIp(): String {
        val request = (RequestContextHolder.getRequestAttributes() as? ServletRequestAttributes)
            ?.request
        return extractClientIp(request)
    }

    private fun extractClientIp(request: HttpServletRequest?): String {
        if (request == null) return "unknown"
        return request.getHeader("X-Forwarded-For")?.split(",")?.firstOrNull()?.trim()
            ?: request.remoteAddr
    }
}
