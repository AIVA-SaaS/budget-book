package com.budgetbook.couple.repository

import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface CoupleRepository : JpaRepository<Couple, UUID> {

    @Query("""
        SELECT c FROM Couple c
        WHERE (c.user1.id = :userId OR c.user2.id = :userId)
        AND c.status = :status
    """)
    fun findByUserIdAndStatus(@Param("userId") userId: UUID, @Param("status") status: CoupleStatus): Couple?

    @Query("""
        SELECT c FROM Couple c
        WHERE c.user1.id = :userId
        AND c.isSelf = true
        AND c.status = 'ACTIVE'
    """)
    fun findActiveSelfCouple(@Param("userId") userId: UUID): Couple?

    @Query("""
        SELECT c FROM Couple c
        WHERE (c.user1.id = :userId OR c.user2.id = :userId)
        AND c.isSelf = false
        AND c.status = :status
    """)
    fun findRealCoupleByUserIdAndStatus(@Param("userId") userId: UUID, @Param("status") status: CoupleStatus): Couple?
}
