package com.budgetbook.common.service

import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import java.util.UUID

/**
 * Interface for services that need couple context.
 * Provides getActiveCouple() to avoid duplication across 12+ services.
 */
interface CoupleAwareService {
    val coupleResolver: CoupleResolver

    fun getActiveCouple(userId: UUID): Couple =
        coupleResolver.getActiveCouple(userId)
}
