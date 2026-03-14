package com.budgetbook.pocket.repository

import com.budgetbook.pocket.domain.DistributionRatio
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface DistributionRatioRepository : JpaRepository<DistributionRatio, UUID> {

    fun findByCoupleId(coupleId: UUID): List<DistributionRatio>

    fun deleteByCoupleId(coupleId: UUID)
}
