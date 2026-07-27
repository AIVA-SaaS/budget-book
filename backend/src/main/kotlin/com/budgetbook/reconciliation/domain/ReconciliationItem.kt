package com.budgetbook.reconciliation.domain

import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.common.entity.Visibility
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.time.LocalDate
import java.util.UUID

/**
 * 정산 스냅샷 항목 (V65).
 *
 * **원본 참조는 nullable 이다.** 원본 거래/이체가 삭제되면 FK 가 `ON DELETE SET NULL` 로
 * 끊기고, `snapshot*` 필드가 "정산 당시 이런 항목이 있었다" 는 기록으로 남는다.
 * (CASCADE 로 지우면 정산 이력이 조용히 사라져 스냅샷의 의미가 무너진다.)
 *
 * 그래서 어떤 종류인지는 FK 유무가 아니라 [itemKind] 로 판별한다. DB CHECK 가
 * `TRANSACTION → transfer_id IS NULL`, `TRANSFER → transaction_id IS NULL` 을 강제한다.
 *
 * `transaction_id` / `transfer_id` 에는 각각 partial UNIQUE 인덱스가 있어
 * **한 항목은 최대 1개 스냅샷에만** 속한다 (부부 동시 정산 시 한쪽은 409 로 실패).
 */
@Entity
@Table(name = "reconciliation_items")
class ReconciliationItem(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reconciliation_id", nullable = false)
    val reconciliation: Reconciliation,

    @Enumerated(EnumType.STRING)
    @Column(name = "item_kind", nullable = false, length = 20)
    val itemKind: ReconciliationItemKind,

    /** 원본 거래 id. [itemKind] 가 TRANSACTION 일 때만 값이 있고, 원본 삭제 시 null 이 된다. */
    @Column(name = "transaction_id")
    var transactionId: UUID? = null,

    /** 원본 이체 id. [itemKind] 가 TRANSFER 일 때만 값이 있고, 원본 삭제 시 null 이 된다. */
    @Column(name = "transfer_id")
    var transferId: UUID? = null,

    /** 정산 시점 금액. 원본이 나중에 바뀌어도 이 값은 고정. */
    @Column(name = "snapshot_amount", nullable = false)
    val snapshotAmount: Long,

    /** 정산 시점 거래일/이체일. */
    @Column(name = "snapshot_date", nullable = false)
    val snapshotDate: LocalDate,

    @Column(name = "snapshot_description", length = 255)
    val snapshotDescription: String? = null,

    /**
     * 정산 시점 분류. 거래면 `INCOME`/`EXPENSE`/`ADJUSTMENT`,
     * 이체면 `CARD_SETTLEMENT`/`EXPENSE_TRANSFER`/`INCOME_TRANSFER`/`GENERIC`.
     * 소계 집계는 이 값으로 한다 (원본 삭제 후에도 집계가 유지되도록).
     */
    @Column(name = "snapshot_kind", nullable = false, length = 20)
    val snapshotKind: String,

    /**
     * 조회자 게이팅 폴백. 원본이 살아 있으면 **원본의 현재 visibility** 를 쓴다
     * (원본이 PRIVATE 로 바뀌면 파트너에게 즉시 안 보여야 하므로).
     * 원본이 삭제된 뒤에는 이 복제값으로 판단한다.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "snapshot_visibility", nullable = false, length = 10)
    val snapshotVisibility: Visibility = Visibility.SHARED,

    @Column(name = "snapshot_owner_id")
    val snapshotOwnerId: UUID? = null
) : BaseTimeEntity() {

    /** 원본 참조 id (종류 무관). 원본이 삭제되면 null. */
    val refId: UUID?
        get() = if (itemKind == ReconciliationItemKind.TRANSACTION) transactionId else transferId

    /** 원본이 삭제되어 참조가 끊긴 항목인지. */
    val originDeleted: Boolean
        get() = refId == null
}

enum class ReconciliationItemKind { TRANSACTION, TRANSFER }
