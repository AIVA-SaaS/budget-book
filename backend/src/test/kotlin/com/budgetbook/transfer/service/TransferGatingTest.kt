package com.budgetbook.transfer.service

import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.common.filter.LedgerFilterAxis
import com.budgetbook.common.filter.TransferAxisHandling
import io.kotest.assertions.withClue
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import java.util.UUID

/**
 * 이체 게이팅 단일 판정의 규칙 고정.
 *
 * 여기서 검증하는 것은 "**어떤 축이 이체를 전량 제외하는가**" 다.
 * 쿼리 조건([TransferGating.spec])이 실제로 어떤 행을 고르는지는 mock 으로 확인할 수 없어
 * `LedgerSummaryRowContractIntegrationTest` 가 실 PostgreSQL 로 담당한다.
 */
class TransferGatingTest : FunSpec({

    test("no filter keeps transfers") {
        TransferGating.excludedWholesale(CommonFilterParams()) shouldBe false
    }

    test("axes that transfers do not have exclude them wholesale") {
        // 이체엔 카테고리·포켓·needsReview·visibility 필드가 없다 → 매칭 불가 = 전량 제외.
        listOf(
            "categoryId" to CommonFilterParams(categoryId = UUID.randomUUID()),
            "categoryIds" to CommonFilterParams(categoryIds = listOf(UUID.randomUUID())),
            "categoryGroupIds" to CommonFilterParams(categoryGroupIds = listOf(UUID.randomUUID())),
            "pocketId" to CommonFilterParams(pocketId = UUID.randomUUID()),
            "pocketIds" to CommonFilterParams(pocketIds = listOf(UUID.randomUUID())),
            "needsReviewOnly" to CommonFilterParams(needsReviewOnly = true),
            "visibility=PRIVATE" to CommonFilterParams(visibility = "PRIVATE"),
            "singular type" to CommonFilterParams(type = "EXPENSE"),
            "types without TRANSFER" to CommonFilterParams(transactionTypes = listOf("EXPENSE")),
        ).forEach { (axis, filter) ->
            withClue("axis=$axis should exclude transfers") {
                TransferGating.excludedWholesale(filter) shouldBe true
            }
        }
    }

    test("axes that apply to transfers keep them") {
        listOf(
            "amount range" to CommonFilterParams(amountMin = 1_000, amountMax = 2_000),
            "payment methods" to CommonFilterParams(paymentMethodIds = listOf(UUID.randomUUID())),
            "keyword" to CommonFilterParams(keyword = "커피"),
            "date range" to CommonFilterParams(year = 2026, month = 7),
            "visibility=SHARED" to CommonFilterParams(visibility = "SHARED"),
            "visibility=ALL" to CommonFilterParams(visibility = "ALL"),
            "needsReviewOnly=false" to CommonFilterParams(needsReviewOnly = false),
            "types with TRANSFER" to CommonFilterParams(transactionTypes = listOf("EXPENSE", "TRANSFER")),
            "TRANSFER only" to CommonFilterParams(transactionTypes = listOf("TRANSFER")),
        ).forEach { (axis, filter) ->
            withClue("axis=$axis should keep transfers") {
                TransferGating.excludedWholesale(filter) shouldBe false
            }
        }
    }

    test("reconciled matching follows the three-state rule") {
        TransferGating.reconciledMatches(null, hasSnapshot = true) shouldBe true
        TransferGating.reconciledMatches(null, hasSnapshot = false) shouldBe true
        TransferGating.reconciledMatches(true, hasSnapshot = true) shouldBe true
        TransferGating.reconciledMatches(true, hasSnapshot = false) shouldBe false
        TransferGating.reconciledMatches(false, hasSnapshot = false) shouldBe true
        TransferGating.reconciledMatches(false, hasSnapshot = true) shouldBe false
    }

    test("the axis classification agrees with excludedWholesale") {
        // 분류(문서)와 실제 판정(코드)이 갈라지면 다음 사람이 문서를 믿고 틀린다.
        val wholesaleAxes = LedgerFilterAxis.entries
            .filter { TransferGating.handling(it) == TransferAxisHandling.EXCLUDES_WHOLESALE }
            .map { it.propertyName }
            .toSet()

        wholesaleAxes shouldBe setOf(
            "categoryId", "categoryIds", "categoryGroupIds",
            "pocketId", "pocketIds",
            "needsReviewOnly", "visibility", "type", "transactionTypes",
        )
    }
})
