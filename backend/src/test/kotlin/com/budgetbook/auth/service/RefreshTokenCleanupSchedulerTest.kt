package com.budgetbook.auth.service

import com.budgetbook.auth.repository.RefreshTokenRepository
import io.kotest.core.spec.style.FunSpec
import io.mockk.clearMocks
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.Instant

class RefreshTokenCleanupSchedulerTest : FunSpec({

    val refreshTokenRepository = mockk<RefreshTokenRepository>()
    val scheduler = RefreshTokenCleanupScheduler(refreshTokenRepository)

    beforeEach { clearMocks(refreshTokenRepository) }

    test("cleanupExpiredAndRevokedTokens deletes expired and revoked tokens") {
        every { refreshTokenRepository.deleteExpiredOrRevoked(any<Instant>()) } returns 5

        scheduler.cleanupExpiredAndRevokedTokens()

        verify(exactly = 1) { refreshTokenRepository.deleteExpiredOrRevoked(any()) }
    }

    test("cleanupExpiredAndRevokedTokens handles zero deletions") {
        every { refreshTokenRepository.deleteExpiredOrRevoked(any<Instant>()) } returns 0

        scheduler.cleanupExpiredAndRevokedTokens()

        verify(exactly = 1) { refreshTokenRepository.deleteExpiredOrRevoked(any()) }
    }
})
