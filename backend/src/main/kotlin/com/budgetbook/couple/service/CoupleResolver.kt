package com.budgetbook.couple.service

import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import org.springframework.stereotype.Component
import org.springframework.web.context.annotation.RequestScope
import java.util.UUID

/**
 * Request-scoped component that caches the active couple lookup for a given user,
 * avoiding redundant DB queries when multiple services need the same couple within
 * a single HTTP request.
 */
@Component
@RequestScope
class CoupleResolver(
    private val coupleRepository: CoupleRepository
) {
    private val cache = mutableMapOf<UUID, Couple>()

    /**
     * Returns the active couple for the given user, caching the result for the
     * lifetime of the current HTTP request.
     *
     * @throws NotFoundException if the user is not part of an active couple
     */
    fun getActiveCouple(userId: UUID): Couple {
        return cache.getOrPut(userId) {
            coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
                ?: throw NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")
        }
    }

    /**
     * Returns the active couple for the given user, or null if not found.
     * Also caches the result when found.
     */
    fun getActiveCoupleOrNull(userId: UUID): Couple? {
        cache[userId]?.let { return it }
        val couple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        if (couple != null) {
            cache[userId] = couple
        }
        return couple
    }
}
