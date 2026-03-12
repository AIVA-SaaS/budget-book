package com.budgetbook.common.cache

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.redis.core.RedisTemplate
import org.springframework.stereotype.Service
import java.time.Duration

@Service
class RedisCacheService {

    private val log = LoggerFactory.getLogger(javaClass)

    @Autowired(required = false)
    private var redisTemplate: RedisTemplate<String, String>? = null

    val isAvailable: Boolean get() = redisTemplate != null

    fun get(key: String): String? {
        val template = redisTemplate ?: return null
        return try {
            template.opsForValue().get(key)
        } catch (e: Exception) {
            log.warn("Redis GET failed for key={}: {}", key, e.message)
            null
        }
    }

    fun set(key: String, value: String, ttl: Duration = Duration.ofMinutes(10)) {
        val template = redisTemplate ?: return
        try {
            template.opsForValue().set(key, value, ttl)
        } catch (e: Exception) {
            log.warn("Redis SET failed for key={}: {}", key, e.message)
        }
    }

    fun evict(key: String) {
        val template = redisTemplate ?: return
        try {
            template.delete(key)
        } catch (e: Exception) {
            log.warn("Redis EVICT failed for key={}: {}", key, e.message)
        }
    }

    fun evictByPattern(pattern: String) {
        val template = redisTemplate ?: return
        try {
            val keys = template.keys(pattern)
            if (!keys.isNullOrEmpty()) {
                template.delete(keys)
            }
        } catch (e: Exception) {
            log.warn("Redis EVICT by pattern failed for pattern={}: {}", pattern, e.message)
        }
    }
}
