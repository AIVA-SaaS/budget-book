package com.budgetbook.insurance.repository

import com.budgetbook.common.entity.Visibility
import com.budgetbook.insurance.domain.Insurance
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface InsuranceRepository : JpaRepository<Insurance, UUID> {

    @Query("""
        SELECT i FROM Insurance i
        WHERE i.couple.id = :coupleId
        AND (i.visibility = com.budgetbook.common.entity.Visibility.SHARED OR i.owner.id = :userId)
        ORDER BY i.createdAt DESC
    """)
    fun findByCoupleIdAndVisible(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<Insurance>

    @Query("""
        SELECT i FROM Insurance i
        WHERE i.couple.id = :coupleId
        AND i.isActive = true
        AND (i.visibility = com.budgetbook.common.entity.Visibility.SHARED OR i.owner.id = :userId)
        ORDER BY i.createdAt DESC
    """)
    fun findByCoupleIdAndActiveAndVisible(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<Insurance>

    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): Insurance?
}
