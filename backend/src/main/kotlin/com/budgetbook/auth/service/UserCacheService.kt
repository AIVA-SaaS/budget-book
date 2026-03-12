package com.budgetbook.auth.service

import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.github.benmanes.caffeine.cache.Caffeine
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.util.UUID
import java.util.concurrent.TimeUnit

@Service
class UserCacheService(
    private val userRepository: UserRepository
) {

    private val log = LoggerFactory.getLogger(javaClass)

    private val userCache = Caffeine.newBuilder()
        .maximumSize(1000)
        .expireAfterWrite(5, TimeUnit.MINUTES)
        .build<UUID, User>()

    fun findById(userId: UUID): User? {
        return userCache.get(userId) { id ->
            log.debug("Cache miss for userId={}, loading from DB", id)
            userRepository.findById(id).orElse(null)
        }
    }

    fun evict(userId: UUID) {
        log.debug("Evicting user cache for userId={}", userId)
        userCache.invalidate(userId)
    }

    fun evictAll() {
        log.debug("Evicting all user cache entries")
        userCache.invalidateAll()
    }
}
