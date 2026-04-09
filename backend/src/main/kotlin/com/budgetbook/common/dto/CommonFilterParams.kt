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
    val categoryId: UUID? = null,
    val paymentMethodId: UUID? = null,
    val pocketId: UUID? = null,
    val amountMin: Long? = null,
    val amountMax: Long? = null,
    val keyword: String? = null,
    val visibility: String? = null,
    val type: String? = null,
    val status: String? = null
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
