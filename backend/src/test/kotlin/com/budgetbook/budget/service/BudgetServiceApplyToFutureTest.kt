package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.BudgetRowKind
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.spendingplan.repository.SpendingPlanRepository
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.util.Optional

/**
 * Phase 25 후속 C-2.6 — applyToFuture 시 같은 scope 의 활성 TEMPLATE 자동 종료.
 * V57 partial unique 충돌 회피 + 사용자 의도("이 월부터 미래 모두 새 값") 보존.
 */
class BudgetServiceApplyToFutureTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val budgetRepository = mockk<MonthlyBudgetRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val categoryRepository = mockk<CategoryRepository>()
    val categoryGroupRepository = mockk<CategoryGroupRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val moneyPocketRepository = mockk<MoneyPocketRepository>()
    val userRepository = mockk<com.budgetbook.auth.repository.UserRepository>()
    val spendingPlanRepository = mockk<SpendingPlanRepository>()
    val service = BudgetService(
        budgetRepository, coupleResolver, categoryRepository, categoryGroupRepository,
        transactionRepository, syncEventPublisher, moneyPocketRepository, userRepository,
        spendingPlanRepository
    )

    val u1 = User(email = "u1@t.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val u2 = User(email = "u2@t.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k1")
    val couple = Couple(user1 = u1, user2 = u2, status = CoupleStatus.ACTIVE)
    val foodCat = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "f", color = "#1", isDefault = true)

    every { coupleResolver.getActiveCouple(u1.id) } returns couple

    Given("OVERRIDE 행에 applyToFuture=true 로 update — 같은 scope 에 활성 TEMPLATE 이 있을 때") {
        val template = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-01", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE, amount = 250_000L
        )
        val override = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-04", endYearMonth = "2026-04",
            rowKind = BudgetRowKind.OVERRIDE, amount = 300_000L
        )
        every { budgetRepository.findById(override.id) } returns Optional.of(override)
        every { budgetRepository.findActiveTemplateInScope(
            couple.id, foodCat.id, null, "2026-04", override.id
        ) } returns template
        every { budgetRepository.save(template) } returns template
        every { budgetRepository.save(override) } returns override

        When("update(applyToFuture=true)") {
            service.updateBudget(u1.id, override.id, BudgetUpdateRequest(amount = 350_000L, applyToFuture = true))

            Then("기존 TEMPLATE 은 endYearMonth=2026-03 으로 종료") {
                template.endYearMonth shouldBe "2026-03"
                verify { budgetRepository.save(template) }
            }
            Then("override 행은 TEMPLATE 으로 승격 + endYearMonth=null + 새 금액") {
                override.rowKind shouldBe BudgetRowKind.TEMPLATE
                override.endYearMonth shouldBe null
                override.amount shouldBe 350_000L
            }
        }
    }

    Given("OVERRIDE 가 TEMPLATE 시작월과 같은 월 — 종료 시 음수 범위") {
        // 1월 시작 TEMPLATE 에 대해 1월 OVERRIDE 의 applyToFuture=true 가 들어오면
        // endYearMonth=2025-12 가 startYM(2026-01)보다 앞 → TEMPLATE 행 자체 삭제.
        val template = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-01", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE, amount = 250_000L
        )
        val override = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-01", endYearMonth = "2026-01",
            rowKind = BudgetRowKind.OVERRIDE, amount = 300_000L
        )
        every { budgetRepository.findById(override.id) } returns Optional.of(override)
        every { budgetRepository.findActiveTemplateInScope(
            couple.id, foodCat.id, null, "2026-01", override.id
        ) } returns template
        every { budgetRepository.delete(template) } returns Unit
        every { budgetRepository.save(override) } returns override

        When("update(applyToFuture=true)") {
            service.updateBudget(u1.id, override.id, BudgetUpdateRequest(amount = 350_000L, applyToFuture = true))

            Then("기존 TEMPLATE 은 행 삭제") {
                verify { budgetRepository.delete(template) }
            }
            Then("override 는 TEMPLATE 승격") {
                override.rowKind shouldBe BudgetRowKind.TEMPLATE
                override.endYearMonth shouldBe null
            }
        }
    }

    Given("OVERRIDE 행에 applyToFuture=true 로 update — 같은 scope 에 활성 TEMPLATE 없음") {
        val override = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-04", endYearMonth = "2026-04",
            rowKind = BudgetRowKind.OVERRIDE, amount = 300_000L
        )
        every { budgetRepository.findById(override.id) } returns Optional.of(override)
        every { budgetRepository.findActiveTemplateInScope(
            couple.id, foodCat.id, null, "2026-04", override.id
        ) } returns null
        every { budgetRepository.save(override) } returns override

        When("update(applyToFuture=true)") {
            service.updateBudget(u1.id, override.id, BudgetUpdateRequest(amount = 350_000L, applyToFuture = true))

            Then("종료 대상 없으므로 save(template) 호출 안 함") {
                verify(exactly = 0) { budgetRepository.delete(any<MonthlyBudget>()) }
            }
            Then("override 만 TEMPLATE 으로 승격") {
                override.rowKind shouldBe BudgetRowKind.TEMPLATE
                override.endYearMonth shouldBe null
                override.amount shouldBe 350_000L
            }
        }
    }

    Given("OVERRIDE 행에 applyToFuture=true 로 delete — 같은 scope 에 활성 TEMPLATE 있을 때") {
        val template = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-01", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE, amount = 250_000L
        )
        val override = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-04", endYearMonth = "2026-04",
            rowKind = BudgetRowKind.OVERRIDE, amount = 300_000L
        )
        every { budgetRepository.findById(override.id) } returns Optional.of(override)
        every { budgetRepository.findActiveTemplateInScope(
            couple.id, foodCat.id, null, "2026-04", override.id
        ) } returns template
        every { budgetRepository.save(template) } returns template
        every { budgetRepository.delete(override) } returns Unit

        When("delete(applyToFuture=true)") {
            service.deleteBudget(u1.id, override.id, applyToFuture = true)

            Then("OVERRIDE 행은 삭제") {
                verify { budgetRepository.delete(override) }
            }
            Then("기존 TEMPLATE 은 endYearMonth=2026-03 으로 종료") {
                template.endYearMonth shouldBe "2026-03"
                verify { budgetRepository.save(template) }
            }
        }
    }

    Given("기존 TEMPLATE 행에 applyToFuture=true 로 delete — C-2 기존 동작 유지") {
        // C-2: TEMPLATE delete(applyToFuture) → endYearMonth=(yearMonth-1) 처리.
        // findActiveTemplateInScope 는 호출되지 않아야 함 (TEMPLATE 분기).
        val templateAtApril = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-04", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE, amount = 250_000L
        )
        every { budgetRepository.findById(templateAtApril.id) } returns Optional.of(templateAtApril)
        every { budgetRepository.save(templateAtApril) } returns templateAtApril

        When("delete(applyToFuture=true)") {
            service.deleteBudget(u1.id, templateAtApril.id, applyToFuture = true)

            Then("endYearMonth=2026-03 으로 종료 (C-2 기존 동작)") {
                templateAtApril.endYearMonth shouldBe "2026-03"
                verify { budgetRepository.save(templateAtApril) }
            }
            Then("findActiveTemplateInScope 호출 안 함 (TEMPLATE 분기)") {
                verify(exactly = 0) { budgetRepository.findActiveTemplateInScope(any(), any(), any(), any(), any()) }
            }
        }
    }
})
