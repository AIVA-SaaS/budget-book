package com.budgetbook.common.filter

import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.transfer.service.TransferGating
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe

/**
 * **축 가드** — 장부 필터에 필드를 추가하면 이 테스트가 실패한다.
 *
 * 왜: 필터 축이 늘 때 한쪽 스트림(거래/이체)에서만 축이 누락되는 사고가 4회 반복됐다.
 * 컴파일 단계에서는 [TransferGating.handling] 의 exhaustive `when` 이 막고,
 * 여기서는 **enum 과 VO 프로퍼티의 1:1 대응**을 막는다. 둘 중 하나만으로는
 * "enum 에 추가하고 VO 는 안 고침"(또는 반대)을 못 잡는다.
 *
 * 실패했다면 순서는 이렇다:
 *  1. `CommonFilterParams` 에 추가한 필드에 대응하는 [LedgerFilterAxis] 항목을 추가
 *  2. [TransferGating.handling] 에서 그 축을 어떻게 다룰지 선언 (컴파일이 강제)
 *  3. 이체에 적용되는 축이면 `TransferGating.spec`(또는 `excludedWholesale`)에 판정 추가
 *  4. `TransferService.listTransfers` 와 합계가 같은 판정을 쓰는지 확인
 *     (같은 함수를 쓰므로 자동이지만, 새 축이 후처리라면 양쪽에 넣어야 한다)
 */
class LedgerFilterAxisGuardTest : FunSpec({

    // Kotlin data class 의 프로퍼티는 private 필드로 컴파일된다. 합성 필드는 제외.
    val voPropertyNames = CommonFilterParams::class.java.declaredFields
        .filterNot { it.isSynthetic }
        .map { it.name }
        .toSet()

    test("every LedgerFilterAxis maps to a real CommonFilterParams property") {
        val unknown = LedgerFilterAxis.entries
            .map { it.propertyName }
            .filterNot { it in voPropertyNames }

        unknown.shouldBeEmpty()
    }

    test("every CommonFilterParams property has a LedgerFilterAxis") {
        val covered = LedgerFilterAxis.entries.map { it.propertyName }.toSet()
        val uncovered = voPropertyNames - covered

        // 실패 시: 위 KDoc 의 1~4 순서를 따르라.
        uncovered.shouldBeEmpty()
    }

    test("axis count matches property count (1:1, no duplicates)") {
        LedgerFilterAxis.entries.size shouldBe voPropertyNames.size
        LedgerFilterAxis.entries.map { it.propertyName }.toSet().size shouldBe LedgerFilterAxis.entries.size
    }

    test("every axis declares how transfers handle it") {
        // handling 은 exhaustive when 이라 컴파일이 이미 강제한다.
        // 여기서는 호출이 예외 없이 끝나는지(= 모든 항목이 분류됐는지)를 확인한다.
        LedgerFilterAxis.entries.forEach { axis ->
            TransferGating.handling(axis) shouldNotBe null
        }
    }
})
