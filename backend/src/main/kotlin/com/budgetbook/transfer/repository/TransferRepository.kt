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

    @Query("""
        SELECT tr.sourcePaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr
        WHERE tr.couple.id = :coupleId
        AND tr.transferDate BETWEEN :startDate AND :endDate
        GROUP BY tr.sourcePaymentMethod.id
    """)
    fun sumAmountBySourceForCoupleAndPeriod(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>

    @Query("""
        SELECT tr.destinationPaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr
        WHERE tr.couple.id = :coupleId
        AND tr.transferDate BETWEEN :startDate AND :endDate
        GROUP BY tr.destinationPaymentMethod.id
    """)
    fun sumAmountByDestinationForCoupleAndPeriod(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>

    @Query("""
        SELECT tr FROM Transfer tr
        WHERE tr.sourcePaymentMethod.id = :paymentMethodId
        AND tr.transferDate BETWEEN :startDate AND :endDate
        AND tr.isCardSettlement = false
        ORDER BY tr.transferDate ASC
    """)
    fun findBySourcePaymentMethodAndDateRange(
        @Param("paymentMethodId") paymentMethodId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Transfer>

    // --- 통계용 쿼리 (카드 결제 이체 제외) ---

    @Query("""
        SELECT tr.sourcePaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr
        WHERE tr.couple.id = :coupleId
        AND tr.transferDate BETWEEN :startDate AND :endDate
        AND tr.isCardSettlement = false
        GROUP BY tr.sourcePaymentMethod.id
    """)
    fun sumAmountBySourceExcludingSettlement(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>

    @Query("""
        SELECT tr.destinationPaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr
        WHERE tr.couple.id = :coupleId
        AND tr.transferDate BETWEEN :startDate AND :endDate
        AND tr.isCardSettlement = false
        GROUP BY tr.destinationPaymentMethod.id
    """)
    fun sumAmountByDestinationExcludingSettlement(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>
}
