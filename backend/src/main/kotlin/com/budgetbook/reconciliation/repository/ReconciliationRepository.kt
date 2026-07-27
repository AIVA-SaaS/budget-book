package com.budgetbook.reconciliation.repository

import com.budgetbook.reconciliation.domain.Reconciliation
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface ReconciliationRepository : JpaRepository<Reconciliation, UUID> {

    /** 해당 월 스냅샷 헤더 (최신 회차 먼저). `(couple_id, year_month)` 인덱스 사용. */
    fun findByCoupleIdAndYearMonthOrderBySeqDesc(coupleId: UUID, yearMonth: String): List<Reconciliation>

    fun countByCoupleIdAndYearMonth(coupleId: UUID, yearMonth: String): Int

    /** 다음 회차 번호 계산용. 스냅샷이 없으면 null. */
    @Query(
        """
        SELECT MAX(r.seq) FROM Reconciliation r
        WHERE r.couple.id = :coupleId AND r.yearMonth = :yearMonth
        """
    )
    fun findMaxSeq(@Param("coupleId") coupleId: UUID, @Param("yearMonth") yearMonth: String): Int?
}
