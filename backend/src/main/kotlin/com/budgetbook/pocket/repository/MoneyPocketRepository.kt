package com.budgetbook.pocket.repository

import com.budgetbook.pocket.domain.MoneyPocket
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface MoneyPocketRepository : JpaRepository<MoneyPocket, UUID> {

    @Query("""
        SELECT p FROM MoneyPocket p
        WHERE p.couple.id = :coupleId AND p.isActive = true
        AND (p.visibility = com.budgetbook.common.entity.Visibility.SHARED OR p.owner.id = :userId)
        ORDER BY p.displayOrder ASC, p.createdAt ASC
    """)
    fun findByCoupleIdAndIsActiveTrueAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<MoneyPocket>

    @Query("""
        SELECT p FROM MoneyPocket p
        WHERE p.couple.id = :coupleId AND p.isActive = true
        ORDER BY p.displayOrder ASC, p.createdAt ASC
    """)
    fun findByCoupleIdAndIsActiveTrue(@Param("coupleId") coupleId: UUID): List<MoneyPocket>

    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): MoneyPocket?

    @Query("""
        SELECT COALESCE(MAX(p.displayOrder), 0)
        FROM MoneyPocket p
        WHERE p.couple.id = :coupleId
    """)
    fun maxDisplayOrderByCoupleId(@Param("coupleId") coupleId: UUID): Int
}
