package com.budgetbook.common.security

import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.couple.domain.Couple
import java.util.UUID

/**
 * Validates that a resource belongs to the expected couple.
 * Replaces repeated `if (entity.couple.id != couple.id) throw ForbiddenException(...)` checks.
 */
object OwnershipValidator {

    fun validateOwnership(resourceCoupleId: UUID, expectedCouple: Couple, resourceName: String = "Resource") {
        if (resourceCoupleId != expectedCouple.id) {
            throw ForbiddenException("FORBIDDEN", "$resourceName belongs to a different couple.")
        }
    }
}
