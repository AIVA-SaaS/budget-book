package com.budgetbook.transfer.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.couple.domain.Couple
import com.budgetbook.paymentmethod.domain.PaymentMethod
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

@Entity
@Table(name = "transfers")
class Transfer(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    val author: User,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "source_payment_method_id", nullable = false)
    var sourcePaymentMethod: PaymentMethod,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "destination_payment_method_id", nullable = false)
    var destinationPaymentMethod: PaymentMethod,

    @Column(nullable = false)
    var amount: Long,

    @Column(length = 255)
    var description: String? = null,

    var memo: String? = null,

    @Column(name = "transfer_date", nullable = false)
    var transferDate: LocalDate,

    @Column(name = "auto_settlement_key", length = 100, unique = true)
    val autoSettlementKey: String? = null,

    /**
     * 이체 의미 분류 (Phase 22).
     * - CARD_SETTLEMENT: 카드 결제 (통계 제외)
     * - EXPENSE_TRANSFER: 지출 집계
     * - INCOME_TRANSFER: 수입 집계
     * - GENERIC: 순수 내부 이동 (이체 별도 집계)
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "kind", nullable = false, length = 20)
    var kind: TransferKind = TransferKind.GENERIC,

    /**
     * @deprecated Phase 22: `kind == CARD_SETTLEMENT` 로 대체. V55 에서 컬럼 DROP 예정.
     * 백워드 호환용으로 DB 컬럼은 유지하되 신규 코드는 `kind` 를 사용할 것.
     */
    @Deprecated(
        message = "Use kind == TransferKind.CARD_SETTLEMENT. Column will be dropped in V55.",
        replaceWith = ReplaceWith("kind == TransferKind.CARD_SETTLEMENT")
    )
    @Column(name = "is_card_settlement", nullable = false)
    var isCardSettlement: Boolean = false
) : BaseTimeEntity()
