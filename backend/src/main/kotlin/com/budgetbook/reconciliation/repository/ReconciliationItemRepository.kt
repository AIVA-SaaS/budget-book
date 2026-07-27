package com.budgetbook.reconciliation.repository

import com.budgetbook.reconciliation.domain.ReconciliationItem
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface ReconciliationItemRepository : JpaRepository<ReconciliationItem, UUID> {

    fun findByReconciliationId(reconciliationId: UUID): List<ReconciliationItem>

    fun findByReconciliationIdIn(reconciliationIds: Collection<UUID>): List<ReconciliationItem>

    /**
     * 주어진 거래 id 중 **이미 어떤 스냅샷에 기록된** 것들.
     * 생성/추가 시 409 판정과, 목록 응답에 정산 배지를 벌크 주입할 때 쓴다
     * (항목당 조회 = N+1 금지).
     */
    @Query(
        """
        SELECT i FROM ReconciliationItem i
        WHERE i.transactionId IN :transactionIds
        """
    )
    fun findByTransactionIdIn(@Param("transactionIds") transactionIds: Collection<UUID>): List<ReconciliationItem>

    @Query(
        """
        SELECT i FROM ReconciliationItem i
        WHERE i.transferId IN :transferIds
        """
    )
    fun findByTransferIdIn(@Param("transferIds") transferIds: Collection<UUID>): List<ReconciliationItem>
}
