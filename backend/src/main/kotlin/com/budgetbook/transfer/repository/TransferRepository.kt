package com.budgetbook.transfer.repository

import com.budgetbook.transfer.domain.Transfer
import com.budgetbook.transfer.domain.TransferKind
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

    /**
     * destination PM 별 이체 유입 합계 (asOf 미만 시점 기준).
     * asOf 는 상한 배타(exclusive) — asOf 당일 이체는 제외된다.
     */
    @Query("""
        SELECT tr.destinationPaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr WHERE tr.couple.id = :coupleId
        AND tr.transferDate < :asOf
        GROUP BY tr.destinationPaymentMethod.id
    """)
    fun sumAmountByDestinationForCoupleUpTo(
        @Param("coupleId") coupleId: UUID,
        @Param("asOf") asOf: LocalDate
    ): List<Array<Any>>

    /**
     * source PM 별 이체 유출 합계 (asOf 미만 시점 기준).
     * asOf 는 상한 배타(exclusive) — asOf 당일 이체는 제외된다.
     */
    @Query("""
        SELECT tr.sourcePaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr WHERE tr.couple.id = :coupleId
        AND tr.transferDate < :asOf
        GROUP BY tr.sourcePaymentMethod.id
    """)
    fun sumAmountBySourceForCoupleUpTo(
        @Param("coupleId") coupleId: UUID,
        @Param("asOf") asOf: LocalDate
    ): List<Array<Any>>

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
        AND tr.kind <> com.budgetbook.transfer.domain.TransferKind.CARD_SETTLEMENT
        ORDER BY tr.transferDate ASC
    """)
    fun findBySourcePaymentMethodAndDateRange(
        @Param("paymentMethodId") paymentMethodId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Transfer>

    // --- Phase 22: kind 기반 통계 쿼리 ---

    /**
     * 주어진 kind 집합에 해당하는 Transfer 를 source PM 별로 합산.
     *
     * 예: `kinds = {EXPENSE_TRANSFER}` → 지출 집계용
     * 예: `kinds = {GENERIC}` → 순수 이체 집계용
     * 예: `kinds = {EXPENSE_TRANSFER, INCOME_TRANSFER, GENERIC}` → 카드 결제 제외 모든 OUT
     */
    @Query("""
        SELECT tr.sourcePaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr
        WHERE tr.couple.id = :coupleId
        AND tr.transferDate BETWEEN :startDate AND :endDate
        AND tr.kind IN :kinds
        GROUP BY tr.sourcePaymentMethod.id
    """)
    fun sumAmountBySourceByKind(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("kinds") kinds: Set<TransferKind>
    ): List<Array<Any>>

    /**
     * 주어진 kind 집합에 해당하는 Transfer 를 destination PM 별로 합산.
     */
    @Query("""
        SELECT tr.destinationPaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr
        WHERE tr.couple.id = :coupleId
        AND tr.transferDate BETWEEN :startDate AND :endDate
        AND tr.kind IN :kinds
        GROUP BY tr.destinationPaymentMethod.id
    """)
    fun sumAmountByDestinationByKind(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate,
        @Param("kinds") kinds: Set<TransferKind>
    ): List<Array<Any>>

    // --- Legacy: 카드 결제(CARD_SETTLEMENT) 제외 합산 ---
    // Phase 22 이전 호출부(PaymentMethodService, PaymentMethodStatisticsService 등) 호환용.
    // 신규 코드는 ExpenseCalculator + sumAmountBy...ByKind 를 사용할 것.

    /**
     * @deprecated Phase 22: `sumAmountBySourceByKind(kinds = NON_CARD_SETTLEMENT_KINDS)` 를 사용하세요.
     *   호출부 정리 후 제거 예정.
     */
    @Deprecated(
        message = "Use sumAmountBySourceByKind with kinds = {EXPENSE_TRANSFER, INCOME_TRANSFER, GENERIC}.",
        replaceWith = ReplaceWith(
            "sumAmountBySourceByKind(coupleId, startDate, endDate, TransferKinds.NON_CARD_SETTLEMENT)",
            "com.budgetbook.transfer.domain.TransferKinds"
        )
    )
    @Query("""
        SELECT tr.sourcePaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr
        WHERE tr.couple.id = :coupleId
        AND tr.transferDate BETWEEN :startDate AND :endDate
        AND tr.kind <> com.budgetbook.transfer.domain.TransferKind.CARD_SETTLEMENT
        GROUP BY tr.sourcePaymentMethod.id
    """)
    fun sumAmountBySourceExcludingSettlement(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>

    /**
     * @deprecated Phase 22: `sumAmountByDestinationByKind(kinds = NON_CARD_SETTLEMENT_KINDS)` 를 사용하세요.
     */
    @Deprecated(
        message = "Use sumAmountByDestinationByKind with kinds = {EXPENSE_TRANSFER, INCOME_TRANSFER, GENERIC}.",
        replaceWith = ReplaceWith(
            "sumAmountByDestinationByKind(coupleId, startDate, endDate, TransferKinds.NON_CARD_SETTLEMENT)",
            "com.budgetbook.transfer.domain.TransferKinds"
        )
    )
    @Query("""
        SELECT tr.destinationPaymentMethod.id, COALESCE(SUM(tr.amount), 0)
        FROM Transfer tr
        WHERE tr.couple.id = :coupleId
        AND tr.transferDate BETWEEN :startDate AND :endDate
        AND tr.kind <> com.budgetbook.transfer.domain.TransferKind.CARD_SETTLEMENT
        GROUP BY tr.destinationPaymentMethod.id
    """)
    fun sumAmountByDestinationExcludingSettlement(
        @Param("coupleId") coupleId: UUID,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Array<Any>>
}
