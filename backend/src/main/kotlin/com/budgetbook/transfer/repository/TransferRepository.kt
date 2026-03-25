package com.budgetbook.transfer.repository

import com.budgetbook.transfer.domain.Transfer
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.LocalDate
import java.util.UUID

interface TransferRepository : JpaRepository<Transfer, UUID> {

    fun findByCoupleIdAndTransferDateBetweenOrderByTransferDateDesc(
        coupleId: UUID,
        startDate: LocalDate,
        endDate: LocalDate
    ): List<Transfer>

    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): Transfer?

    @Query("""
        SELECT tr.destinationPaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr WHERE tr.couple.id = :coupleId
        GROUP BY tr.destinationPaymentMethod.id
    """)
    fun sumAmountByDestinationForCouple(@Param("coupleId") coupleId: UUID): List<Array<Any>>

    @Query("""
        SELECT tr.sourcePaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr WHERE tr.couple.id = :coupleId
        GROUP BY tr.sourcePaymentMethod.id
    """)
    fun sumAmountBySourceForCouple(@Param("coupleId") coupleId: UUID): List<Array<Any>>
}
