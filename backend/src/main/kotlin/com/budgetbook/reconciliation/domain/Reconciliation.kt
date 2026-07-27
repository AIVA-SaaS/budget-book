package com.budgetbook.reconciliation.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.couple.domain.Couple
import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.OneToMany
import jakarta.persistence.Table
import java.time.Instant
import java.util.UUID

/**
 * 정산 스냅샷 헤더 (V65).
 *
 * 장부(거래 + 이체)를 대조한 시점의 기록. 한 달에 여러 번 만들 수 있고 [seq] 로 회차를 구분한다.
 * 어떤 스냅샷에도 담기지 않은 항목은 "미기록" 으로 남아 월말 누락 점검에 쓰인다.
 *
 * 소계([totalIncome] 등)는 **BE 가 단독 계산해 저장**한다 (조회 빈도 ≫ 생성 빈도, 스냅샷은
 * 불변 기록이라 캐시 무효화 문제가 없다). FE 는 절대 재계산하지 않는다 — 과거 이중 합산 사고
 * (2026-04-14 MonthSummaryBar) 의 원인이 FE 재계산이었다.
 *
 * 단, 조회자가 볼 수 없는 파트너의 PRIVATE 항목이 섞여 있으면 조회 시점에 게이팅 후
 * 재계산해서 응답한다 (표시된 행과 합계가 어긋나지 않도록).
 */
@Entity
@Table(name = "reconciliations")
class Reconciliation(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    /** 정산 대상 월 `yyyy-MM`. */
    @Column(name = "year_month", nullable = false, length = 7)
    val yearMonth: String,

    /** 월 내 회차 (1부터). `(couple_id, year_month, seq)` UNIQUE. */
    @Column(nullable = false)
    val seq: Int,

    @Column(length = 100)
    var label: String? = null,

    @Column(name = "item_count", nullable = false)
    var itemCount: Int = 0,

    @Column(name = "total_income", nullable = false)
    var totalIncome: Long = 0,

    @Column(name = "total_expense", nullable = false)
    var totalExpense: Long = 0,

    @Column(name = "total_transfer", nullable = false)
    var totalTransfer: Long = 0,

    @Column(name = "reconciled_at", nullable = false)
    val reconciledAt: Instant = Instant.now(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reconciled_by", nullable = false)
    val reconciledBy: User,

    /**
     * 항목. 헤더 삭제 시 함께 삭제된다(DB 도 ON DELETE CASCADE).
     *
     * 집계에서 lazy proxy 를 신뢰하지 말 것 — 소계 계산은 항목 리스트를 명시적으로
     * 넘겨받는 [com.budgetbook.reconciliation.service.ReconciliationAggregator] 만 사용한다.
     */
    @OneToMany(
        mappedBy = "reconciliation",
        cascade = [CascadeType.ALL],
        orphanRemoval = true,
        fetch = FetchType.LAZY
    )
    val items: MutableList<ReconciliationItem> = mutableListOf()
) : BaseTimeEntity()
