package com.budgetbook.common.ratelimit

import org.springframework.stereotype.Component
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

@Component
class RateLimiter {

    private val requestCounts = ConcurrentHashMap<String, RateLimitEntry>()

    /**
     * Check if the given key has exceeded the rate limit.
     * @return true if the request is allowed, false if rate limited
     */
    fun tryAcquire(key: String, maxRequests: Int, windowMillis: Long): Boolean {
        val now = System.currentTimeMillis()

        val entry = requestCounts.compute(key) { _, existing ->
            if (existing == null || now - existing.windowStart.get() > windowMillis) {
                // New window
                RateLimitEntry(AtomicLong(now), AtomicInteger(1))
            } else {
                existing.count.incrementAndGet()
                existing
            }
        }!!

        return entry.count.get() <= maxRequests
    }

    /**
     * Periodically clean up expired entries to prevent memory leaks.
     * Called by a scheduled task or manually.
     */
    fun cleanup(windowMillis: Long) {
        val now = System.currentTimeMillis()
        requestCounts.entries.removeIf { (_, entry) ->
            now - entry.windowStart.get() > windowMillis
        }
    }

    data class RateLimitEntry(
        val windowStart: AtomicLong,
        val count: AtomicInteger
    )
}
