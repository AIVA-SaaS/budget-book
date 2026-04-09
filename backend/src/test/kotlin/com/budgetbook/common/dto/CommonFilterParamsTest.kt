package com.budgetbook.common.dto

import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.nulls.shouldBeNull
import java.time.LocalDate

class CommonFilterParamsTest : FunSpec({

    test("getEffectiveDateRange returns null when no date params") {
        val params = CommonFilterParams()
        params.getEffectiveDateRange().shouldBeNull()
    }

    test("getEffectiveDateRange from year/month") {
        val params = CommonFilterParams(year = 2026, month = 4)
        val range = params.getEffectiveDateRange()!!
        range.first shouldBe LocalDate.of(2026, 4, 1)
        range.second shouldBe LocalDate.of(2026, 4, 30)
    }

    test("getEffectiveDateRange prefers dateFrom/dateTo over year/month") {
        val from = LocalDate.of(2026, 1, 15)
        val to = LocalDate.of(2026, 3, 20)
        val params = CommonFilterParams(dateFrom = from, dateTo = to, year = 2026, month = 4)
        val range = params.getEffectiveDateRange()!!
        range.first shouldBe from
        range.second shouldBe to
    }

    test("getEffectiveDateRange with dateFrom only") {
        val from = LocalDate.of(2026, 1, 1)
        val params = CommonFilterParams(dateFrom = from)
        val range = params.getEffectiveDateRange()!!
        range.first shouldBe from
        range.second shouldBe LocalDate.of(2099, 12, 31)
    }

    test("getEffectiveDateRange with dateTo only") {
        val to = LocalDate.of(2026, 12, 31)
        val params = CommonFilterParams(dateTo = to)
        val range = params.getEffectiveDateRange()!!
        range.first shouldBe LocalDate.of(2000, 1, 1)
        range.second shouldBe to
    }

    test("getEffectiveDateRange returns null with year only (no month)") {
        val params = CommonFilterParams(year = 2026)
        params.getEffectiveDateRange().shouldBeNull()
    }
})
