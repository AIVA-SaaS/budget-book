package com.budgetbook.reconciliation.repository

import com.budgetbook.reconciliation.domain.ReconciliationItem
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface ReconciliationItemRepository : JpaRepository<ReconciliationItem, UUID> {

    fun findByReconciliationId(reconciliationId: UUID): List<ReconciliationItem>

    /** 헤더별 그룹핑에 `i.reconciliation.id` 를 쓰므로 함께 fetch 한다. */
    @Query(
        """
        SELECT i FROM ReconciliationItem i
        JOIN FETCH i.reconciliation
        WHERE i.reconciliation.id IN :reconciliationIds
        """
    )
    fun findByReconciliationIdIn(
        @Param("reconciliationIds") reconciliationIds: Collection<UUID>
    ): List<ReconciliationItem>

    /**
     * 주어진 거래 id 중 **이미 어떤 스냅샷에 기록된** 것들.
     * 생성/추가 시 409 판정과, 목록 응답에 정산 배지를 벌크 주입할 때 쓴다
     * (항목당 조회 = N+1 금지).
     *
     * `JOIN FETCH i.reconciliation` 이 중요하다 — 배지에는 스냅샷의 `seq`/`reconciledAt` 이
     * 필요하고, 이를 lazy proxy 로 접근하면 스냅샷 수만큼 추가 쿼리가 나간다.
     */
    @Query(
        """
        SELECT i FROM ReconciliationItem i
        JOIN FETCH i.reconciliation
        WHERE i.transactionId IN :transactionIds
        """
    )
    fun findByTransactionIdIn(@Param("transactionIds") transactionIds: Collection<UUID>): List<ReconciliationItem>

    @Query(
        """
        SELECT i FROM ReconciliationItem i
        JOIN FETCH i.reconciliation
        WHERE i.transferId IN :transferIds
        """
    )
    fun findByTransferIdIn(@Param("transferIds") transferIds: Collection<UUID>): List<ReconciliationItem>
}
