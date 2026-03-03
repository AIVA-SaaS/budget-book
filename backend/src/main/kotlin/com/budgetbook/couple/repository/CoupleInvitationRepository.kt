package com.budgetbook.couple.repository

import com.budgetbook.couple.domain.CoupleInvitation
import com.budgetbook.couple.domain.InvitationStatus
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface CoupleInvitationRepository : JpaRepository<CoupleInvitation, UUID> {

    fun findByInvitationCode(invitationCode: String): CoupleInvitation?

    @Modifying
    @Query("""
        UPDATE CoupleInvitation ci
        SET ci.status = :newStatus
        WHERE ci.inviter.id = :inviterId AND ci.status = :currentStatus
    """)
    fun updateStatusByInviterIdAndStatus(
        @Param("inviterId") inviterId: UUID,
        @Param("currentStatus") currentStatus: InvitationStatus,
        @Param("newStatus") newStatus: InvitationStatus
    )
}
