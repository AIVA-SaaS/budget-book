package com.budgetbook.budget.service

import com.budgetbook.budget.domain.BudgetRowKind
import com.budgetbook.budget.domain.MonthlyBudget

/**
 * Phase 25 후속 C-2.5 — TEMPLATE/OVERRIDE 우선순위 처리 공용 헬퍼.
 *
 * Repository 쿼리는 같은 scope 의 TEMPLATE 과 OVERRIDE 를 모두 반환할 수 있다 (V57
 * partial unique 가 TEMPLATE 1건 + OVERRIDE 1건 공존을 허용). 같은 월에서 같은 scope 가
 * 둘 다 있으면 OVERRIDE 우선이므로, 조회 결과를 호출 측에서 한 번 dedup 해야 한다.
 *
 * Scope key 는 (categoryId, groupId) — 둘 중 하나만 non-null 이거나 둘 다 null(미할당).
 */
object MonthlyBudgetResolver {

    /**
     * Repository 가 반환한 TEMPLATE+OVERRIDE 혼합 리스트에서 OVERRIDE 우선순위를 적용해
     * scope 당 1행만 남긴다. 입력 순서는 보존하지 않으며, 결과 순서는 Repository 가 준
     * `iterable.iterator()` 순서를 따른다.
     */
    fun resolveForMonth(rows: List<MonthlyBudget>): List<MonthlyBudget> {
        if (rows.size <= 1) return rows
        val byScope = LinkedHashMap<ScopeKey, MonthlyBudget>(rows.size)
        for (b in rows) {
            val key = ScopeKey(b.category?.id, b.group?.id)
            val existing = byScope[key]
            if (existing == null) {
                byScope[key] = b
                continue
            }
            // 같은 scope 가 둘 — OVERRIDE 우선. 둘 다 OVERRIDE 면 V57 unique 가 막아야 하지만,
            // 방어적으로 더 최신 yearMonth 또는 입력 순서 첫 행 유지.
            if (existing.rowKind == BudgetRowKind.OVERRIDE) continue
            if (b.rowKind == BudgetRowKind.OVERRIDE) {
                byScope[key] = b
            }
        }
        return byScope.values.toList()
    }

    private data class ScopeKey(
        val categoryId: java.util.UUID?,
        val groupId: java.util.UUID?
    )
}
