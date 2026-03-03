package com.budgetbook.auth.service

import com.budgetbook.auth.repository.RefreshTokenRepository
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Transactional
import java.time.Instant

@Component
class RefreshTokenCleanupScheduler(
    private val refreshTokenRepository: RefreshTokenRepository
) {

    private val log = LoggerFactory.getLogger(javaClass)

    @Scheduled(cron = "0 0 3 * * *") // Daily at 3 AM
    @Transactional
    fun cleanupExpiredAndRevokedTokens() {
        val deleted = refreshTokenRepository.deleteExpiredOrRevoked(Instant.now())
        if (deleted > 0) {
            log.info("Cleaned up {} expired/revoked refresh tokens", deleted)
        }
    }
}
