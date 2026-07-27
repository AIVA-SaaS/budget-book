package com.budgetbook.common.dto

import org.springframework.format.annotation.DateTimeFormat
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

data class CommonFilterParams(
    @field:DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    val dateFrom: LocalDate? = null,
    @field:DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    val dateTo: LocalDate? = null,
    val year: Int? = null,
    val month: Int? = null,
    // 단수 필드 — 거래 상세 / 생성 / CSV export / period-summary 호환용. 유지.
    val categoryId: UUID? = null,
    val paymentMethodId: UUID? = null,
    val pocketId: UUID? = null,
    // 복수 필드 — 다중/그룹 필터 (PR-C2). Spring 은 `categoryIds=a&categoryIds=b` 포맷 자동 바인딩.
    // listTransactions / 통계 목록 쿼리에서 사용. 빈 리스트 = 필터 없음.
    val categoryIds: List<UUID> = emptyList(),
    val categoryGroupIds: List<UUID> = emptyList(),
    val paymentMethodIds: List<UUID> = emptyList(),
    val pocketIds: List<UUID> = emptyList(),
    val amountMin: Long? = null,
    val amountMax: Long? = null,
    val keyword: String? = null,
    val visibility: String? = null,
    val type: String? = null,
    // 복수 타입 필터 (Phase 22 T10). FE 가 `transactionTypes=EXPENSE&transactionTypes=INCOME` 포맷으로 전송.
    // 단수 `type` 과 병존 시 Service 계층에서 `transactionTypes` 우선 (FE `toQueryParams` 와 일치).
    // 빈/null = 필터 없음. 유효 값: EXPENSE / INCOME / ADJUSTMENT (TRANSFER 는 FE 의사-타입).
    val transactionTypes: List<String>? = null,
    val status: String? = null,
    // V61 (2026-05-06) — true 면 needs_review=true 거래만 (확인/입력 필요만 보기).
    val needsReviewOnly: Boolean? = null,
    // V65 (2026-07-27) — 정산 스냅샷 필터. false=미기록만, true=기록된 것만, null=전체.
    // 거래 목록과 이체 목록 **양쪽** 이 지원한다.
    val reconciled: Boolean? = null
) {
    /**
     * Resolves effective date range from dateFrom/dateTo or year/month.
     * Returns null if neither is specified.
     */
    fun getEffectiveDateRange(): Pair<LocalDate, LocalDate>? {
        if (dateFrom != null || dateTo != null) {
            return (dateFrom ?: LocalDate.of(2000, 1, 1)) to (dateTo ?: LocalDate.of(2099, 12, 31))
        }
        if (year != null && month != null) {
            val ym = YearMonth.of(year, month)
            return ym.atDay(1) to ym.atEndOfMonth()
        }
        return null
    }
}
