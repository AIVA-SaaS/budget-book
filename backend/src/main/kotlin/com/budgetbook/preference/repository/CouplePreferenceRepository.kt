package com.budgetbook.preference.repository

import com.budgetbook.preference.domain.CouplePreference
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface CouplePreferenceRepository : JpaRepository<CouplePreference, UUID> {

    fun findByCoupleId(coupleId: UUID): CouplePreference?
}
