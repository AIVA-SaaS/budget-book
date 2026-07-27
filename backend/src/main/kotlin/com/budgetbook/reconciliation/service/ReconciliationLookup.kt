package com.budgetbook.reconciliation.service

import com.budgetbook.reconciliation.domain.ReconciliationItem
import com.budgetbook.reconciliation.dto.ReconciliationRef
import com.budgetbook.reconciliation.repository.ReconciliationItemRepository
import org.springframework.stereotype.Component
import java.util.UUID

/**
 * 거래/이체 목록 응답에 붙일 정산 상태를 **벌크** 로 조회하는 좁은 컴포넌트.
 *
 * 목록 서비스(TransactionService·TransferService)가 정산 도메인 전체(ReconciliationService)에
 * 의존하지 않도록 조회 전용으로 분리했다. 항목당 조회(N+1)를 막는 유일한 진입점이며,
 * 목록 서비스는 반드시 이 컴포넌트를 통해서만 정산 상태를 읽는다.
 *
 * 거래용/이체용 메서드가 **쌍으로** 존재한다는 점이 중요하다 — 장부 목록은 두 스트림 병합이라
 * 한쪽만 채우면 이체 배지가 영구 미표시되는 drift 가 난다.
 */
@Component
class ReconciliationLookup(
    private val reconciliationItemRepository: ReconciliationItemRepository
) {

    fun refsForTransactions(transactionIds: Collection<UUID>): Map<UUID, ReconciliationRef> {
        if (transactionIds.isEmpty()) return emptyMap()
        return reconciliationItemRepository.findByTransactionIdIn(transactionIds)
            .mapNotNull { item -> item.transactionId?.let { it to item.toRef() } }
            .toMap()
    }

    fun refsForTransfers(transferIds: Collection<UUID>): Map<UUID, ReconciliationRef> {
        if (transferIds.isEmpty()) return emptyMap()
        return reconciliationItemRepository.findByTransferIdIn(transferIds)
            .mapNotNull { item -> item.transferId?.let { it to item.toRef() } }
            .toMap()
    }

    private fun ReconciliationItem.toRef() = ReconciliationRef(
        reconciliationId = reconciliation.id,
        reconciliationSeq = reconciliation.seq,
        reconciledAt = reconciliation.reconciledAt
    )
}
