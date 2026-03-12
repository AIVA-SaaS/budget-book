package com.budgetbook.config

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression
import org.springframework.cache.CacheManager
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.data.redis.cache.RedisCacheConfiguration
import org.springframework.data.redis.cache.RedisCacheManager
import org.springframework.data.redis.connection.RedisConnectionFactory
import org.springframework.data.redis.connection.RedisStandaloneConfiguration
import org.springframework.data.redis.connection.lettuce.LettuceClientConfiguration
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory
import org.springframework.data.redis.core.RedisTemplate
import org.springframework.data.redis.serializer.StringRedisSerializer
import java.net.URI
import java.time.Duration

@Configuration
@ConditionalOnExpression("'\${spring.data.redis.url:}' != ''")
class RedisConfig(
    @Value("\${spring.data.redis.url}") private val redisUrl: String
) {

    private val log = LoggerFactory.getLogger(javaClass)

    @Bean
    fun redisConnectionFactory(): RedisConnectionFactory {
        val uri = URI(redisUrl)
        val useSsl = redisUrl.startsWith("rediss://")

        val standaloneConfig = RedisStandaloneConfiguration(uri.host, uri.port)
        if (uri.userInfo != null) {
            val parts = uri.userInfo.split(":")
            if (parts.size == 2) {
                standaloneConfig.setPassword(parts[1])
            }
        }

        val clientConfig = if (useSsl) {
            LettuceClientConfiguration.builder().useSsl().build()
        } else {
            LettuceClientConfiguration.builder().build()
        }

        log.info("Redis connection configured: host={}, port={}, ssl={}",
            uri.host, uri.port, useSsl)
        return LettuceConnectionFactory(standaloneConfig, clientConfig)
    }

    @Bean
    fun redisTemplate(connectionFactory: RedisConnectionFactory): RedisTemplate<String, String> {
        return RedisTemplate<String, String>().apply {
            setConnectionFactory(connectionFactory)
            keySerializer = StringRedisSerializer()
            valueSerializer = StringRedisSerializer()
            hashKeySerializer = StringRedisSerializer()
            hashValueSerializer = StringRedisSerializer()
        }
    }

    @Bean
    fun redisCacheManager(connectionFactory: RedisConnectionFactory): CacheManager {
        val config = RedisCacheConfiguration.defaultCacheConfig()
            .entryTtl(Duration.ofMinutes(10))
            .disableCachingNullValues()

        return RedisCacheManager.builder(connectionFactory)
            .cacheDefaults(config)
            .build()
    }
}
