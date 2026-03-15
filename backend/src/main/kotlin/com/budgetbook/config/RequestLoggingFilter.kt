package com.budgetbook.config

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.slf4j.MDC
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.util.UUID

/**
 * Filter that:
 *  1. Generates or reads a correlation ID (X-Correlation-Id header)
 *  2. Sets it in MDC for structured logging
 *  3. Logs request start (method, path, user_id)
 *  4. Logs request end (method, path, status, duration_ms)
 *  5. Warns on slow requests (>1000ms), errors on very slow (>3000ms)
 *  6. Clears MDC after the request
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
class RequestLoggingFilter : OncePerRequestFilter() {

    private val log = LoggerFactory.getLogger(javaClass)

    companion object {
        private const val CORRELATION_ID_HEADER = "X-Correlation-Id"
        private const val MDC_CORRELATION_ID = "correlationId"
        private const val MDC_REQUEST_PATH = "requestPath"
        private const val SLOW_REQUEST_THRESHOLD_MS = 1000L
        private const val VERY_SLOW_REQUEST_THRESHOLD_MS = 3000L
    }

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val correlationId = request.getHeader(CORRELATION_ID_HEADER)
            ?: UUID.randomUUID().toString()
        val method = request.method
        val path = request.requestURI

        MDC.put(MDC_CORRELATION_ID, correlationId)
        MDC.put(MDC_REQUEST_PATH, path)

        // Add correlation ID to response header for client traceability
        response.setHeader(CORRELATION_ID_HEADER, correlationId)

        val userId = resolveUserId()
        log.info("Request start: method={}, path={}, user_id={}", method, path, userId ?: "anonymous")

        val startTime = System.nanoTime()
        try {
            filterChain.doFilter(request, response)
        } finally {
            val durationMs = (System.nanoTime() - startTime) / 1_000_000
            val status = response.status
            // Re-resolve userId after filter chain (auth may have been set by JWT filter)
            val resolvedUserId = resolveUserId() ?: userId

            when {
                durationMs >= VERY_SLOW_REQUEST_THRESHOLD_MS ->
                    log.error(
                        "Request end (VERY SLOW): method={}, path={}, status={}, duration_ms={}, user_id={}",
                        method, path, status, durationMs, resolvedUserId ?: "anonymous"
                    )
                durationMs >= SLOW_REQUEST_THRESHOLD_MS ->
                    log.warn(
                        "Request end (SLOW): method={}, path={}, status={}, duration_ms={}, user_id={}",
                        method, path, status, durationMs, resolvedUserId ?: "anonymous"
                    )
                else ->
                    log.info(
                        "Request end: method={}, path={}, status={}, duration_ms={}, user_id={}",
                        method, path, status, durationMs, resolvedUserId ?: "anonymous"
                    )
            }

            MDC.clear()
        }
    }

    override fun shouldNotFilter(request: HttpServletRequest): Boolean {
        val path = request.requestURI
        // Skip logging for actuator endpoints to reduce noise
        return path.startsWith("/actuator/")
    }

    private fun resolveUserId(): Any? {
        return try {
            SecurityContextHolder.getContext().authentication?.principal
        } catch (_: Exception) {
            null
        }
    }
}
