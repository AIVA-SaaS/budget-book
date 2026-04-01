package com.budgetbook.spendingplan.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.transaction.domain.Transaction
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.time.Instant
import java.util.UUID

@Entity
@Table(name = "spending_plan_status_history")
class SpendingPlanStatusHistory(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "spending_plan_id", nullable = false)
    val spendingPlan: SpendingPlan,

    @Enumerated(EnumType.STRING)
    @Column(name = "from_status", length = 20)
    val fromStatus: SpendingPlanStatus? = null,

    @Enumerated(EnumType.STRING)
    @Column(name = "to_status", nullable = false, length = 20)
    val toStatus: SpendingPlanStatus,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "changed_by", nullable = false)
    val changedBy: User,

    @Column(name = "actual_amount")
    val actualAmount: Long? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "linked_transaction_id")
    val linkedTransaction: Transaction? = null,

    val note: String? = null,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now()
)
