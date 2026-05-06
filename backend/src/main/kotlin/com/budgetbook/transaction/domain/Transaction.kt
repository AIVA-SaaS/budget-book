package com.budgetbook.transaction.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.category.domain.Category
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.common.entity.Visibility
import com.budgetbook.couple.domain.Couple
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.pocket.domain.MoneyPocket
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
@Table(name = "transactions")
class Transaction(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "author_id", nullable = false)
    val author: User,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    var category: Category? = null,

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    val type: TransactionType,

    @Column(nullable = false)
    var amount: Long,

    @Column(nullable = false, length = 255)
    var description: String,

    var memo: String? = null,

    @Column(name = "transaction_date", nullable = false)
    var transactionDate: LocalDate,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "payment_method_id")
    var paymentMethod: PaymentMethod? = null,

    @Column(name = "settlement_date")
    var settlementDate: LocalDate? = null,

    /**
     * 카드 결제 완료 날짜. null이면 미결제 상태 (결제 대상).
     * 결제 이체(Transfer with is_card_settlement=true) 생성 시 해당 거래들의 paid_at이 설정됨.
     */
    @Column(name = "paid_at")
    var paidAt: LocalDate? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "pocket_id")
    var pocket: MoneyPocket? = null,

    @Enumerated(EnumType.STRING)
    @Column(name = "visibility", nullable = false, length = 10)
    var visibility: Visibility = Visibility.SHARED,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id")
    var owner: User? = null,

    /**
     * 사용자가 "확인/입력 필요" 로 마킹한 거래 여부.
     * V61 (2026-05-06) — 메모만으로는 부족한 follow-up 항목을 별도 플래그로 빠르게 식별.
     * 통계/예산 합계 계산에는 영향 없음 (단순 디스플레이 + 필터링용).
     */
    @Column(name = "needs_review", nullable = false)
    var needsReview: Boolean = false
) : BaseTimeEntity()

/**
 * 거래 유형.
 *
 * - `INCOME` / `EXPENSE`: 통상 수입/지출 — 모든 통계에 집계됨
 * - `ADJUSTMENT` (Phase 22): 실잔액 보정용. `amount` 는 부호 있는 증감값.
 *   - 모든 통계(totalExpense/totalIncome/totalTransfer) 에서 **제외**
 *   - 잔액 계산(`PaymentMethodService.recomputeBalance`) 에는 **포함**
 */
enum class TransactionType { INCOME, EXPENSE, ADJUSTMENT }

