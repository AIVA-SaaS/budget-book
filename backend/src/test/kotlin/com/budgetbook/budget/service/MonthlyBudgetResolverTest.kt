package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.BudgetRowKind
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryGroup
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldContainExactlyInAnyOrder
import io.kotest.matchers.shouldBe

/**
 * Phase 25 후속 C-2.5 — Repository 가 반환한 TEMPLATE+OVERRIDE 혼합에서
 * scope 당 OVERRIDE 우선순위 dedup 이 정확히 동작하는지 검증.
 */
class MonthlyBudgetResolverTest : BehaviorSpec({

    val u1 = User(email = "a@a.com", nickname = "A", provider = AuthProvider.GOOGLE, providerId = "g1")
    val u2 = User(email = "b@b.com", nickname = "B", provider = AuthProvider.KAKAO, providerId = "k1")
    val couple = Couple(user1 = u1, user2 = u2, status = CoupleStatus.ACTIVE)
    val foodCat = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "f", color = "#1", isDefault = true)
    val transportCat = Category(couple = couple, name = "교통", type = CategoryType.EXPENSE, icon = "t", color = "#2", isDefault = true)
    val foodGroup = CategoryGroup(couple = couple, name = "식비그룹", color = "#3", icon = "fg", displayOrder = 0)

    fun budget(
        cat: Category? = null,
        group: CategoryGroup? = null,
        ym: String,
        endYm: String? = null,
        kind: BudgetRowKind,
        amount: Long
    ) = MonthlyBudget(
        couple = couple,
        category = cat,
        group = group,
        yearMonth = ym,
        endYearMonth = endYm,
        rowKind = kind,
        amount = amount
    )

    Given("empty / single row input") {
        When("empty list") {
            Then("returns empty") {
                MonthlyBudgetResolver.resolveForMonth(emptyList()) shouldBe emptyList()
            }
        }
        When("single row") {
            val row = budget(cat = foodCat, ym = "2026-04", endYm = "2026-04", kind = BudgetRowKind.OVERRIDE, amount = 100L)
            Then("returns same single row") {
                MonthlyBudgetResolver.resolveForMonth(listOf(row)) shouldBe listOf(row)
            }
        }
    }

    Given("TEMPLATE only — different scopes") {
        val tmplFood = budget(cat = foodCat, ym = "2026-01", endYm = null, kind = BudgetRowKind.TEMPLATE, amount = 100L)
        val tmplTransport = budget(cat = transportCat, ym = "2026-01", endYm = null, kind = BudgetRowKind.TEMPLATE, amount = 50L)
        val tmplGroup = budget(group = foodGroup, ym = "2026-02", endYm = "2026-12", kind = BudgetRowKind.TEMPLATE, amount = 200L)
        val rows = listOf(tmplFood, tmplTransport, tmplGroup)

        When("multiple non-overlapping scopes") {
            val resolved = MonthlyBudgetResolver.resolveForMonth(rows)
            Then("all preserved") {
                resolved shouldContainExactlyInAnyOrder rows
            }
        }
    }

    Given("OVERRIDE 가 같은 scope 의 TEMPLATE 보다 우선") {
        val tmpl = budget(cat = foodCat, ym = "2026-01", endYm = null, kind = BudgetRowKind.TEMPLATE, amount = 250_000L)
        val ovr = budget(cat = foodCat, ym = "2026-04", endYm = "2026-04", kind = BudgetRowKind.OVERRIDE, amount = 350_000L)

        When("TEMPLATE 먼저, OVERRIDE 가 뒤") {
            val resolved = MonthlyBudgetResolver.resolveForMonth(listOf(tmpl, ovr))
            Then("OVERRIDE 만 남음") {
                resolved.size shouldBe 1
                resolved[0].rowKind shouldBe BudgetRowKind.OVERRIDE
                resolved[0].amount shouldBe 350_000L
            }
        }
        When("OVERRIDE 먼저, TEMPLATE 가 뒤") {
            val resolved = MonthlyBudgetResolver.resolveForMonth(listOf(ovr, tmpl))
            Then("OVERRIDE 만 남음") {
                resolved.size shouldBe 1
                resolved[0].rowKind shouldBe BudgetRowKind.OVERRIDE
                resolved[0].amount shouldBe 350_000L
            }
        }
    }

    Given("scope key 가 (categoryId, groupId) — 둘 다 null 인 미할당 row 도 별도 scope") {
        val totalTmpl = budget(cat = null, group = null, ym = "2026-01", endYm = null, kind = BudgetRowKind.TEMPLATE, amount = 1_000_000L)
        val totalOvr = budget(cat = null, group = null, ym = "2026-04", endYm = "2026-04", kind = BudgetRowKind.OVERRIDE, amount = 1_500_000L)
        val foodTmpl = budget(cat = foodCat, ym = "2026-01", endYm = null, kind = BudgetRowKind.TEMPLATE, amount = 100L)

        When("미할당 scope 에 TEMPLATE+OVERRIDE 공존, 식비 scope 는 TEMPLATE 만") {
            val resolved = MonthlyBudgetResolver.resolveForMonth(listOf(totalTmpl, totalOvr, foodTmpl))
            Then("미할당 OVERRIDE + 식비 TEMPLATE = 2건") {
                resolved.size shouldBe 2
                val total = resolved.first { it.category == null && it.group == null }
                total.rowKind shouldBe BudgetRowKind.OVERRIDE
                total.amount shouldBe 1_500_000L
                val food = resolved.first { it.category?.id == foodCat.id }
                food.rowKind shouldBe BudgetRowKind.TEMPLATE
            }
        }
    }

    Given("같은 카테고리지만 group 이 다른 두 행은 별도 scope") {
        val foodCatTmpl = budget(cat = foodCat, group = null, ym = "2026-01", endYm = null, kind = BudgetRowKind.TEMPLATE, amount = 100L)
        val foodGroupTmpl = budget(cat = null, group = foodGroup, ym = "2026-01", endYm = null, kind = BudgetRowKind.TEMPLATE, amount = 200L)

        When("category-only TEMPLATE + group-only TEMPLATE") {
            val resolved = MonthlyBudgetResolver.resolveForMonth(listOf(foodCatTmpl, foodGroupTmpl))
            Then("둘 다 살아남음") {
                resolved shouldContainExactlyInAnyOrder listOf(foodCatTmpl, foodGroupTmpl)
            }
        }
    }
})
