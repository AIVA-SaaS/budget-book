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
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.spendingplan.repository.SpendingPlanRepository
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.util.Optional

/**
 * Phase 25 후속 C-2.7 — TEMPLATE 행 편집 시 split semantic.
 * applyToFuture=false + 편집 대상 = TEMPLATE 시 viewingMonth 단일 OVERRIDE 신규 생성 (TEMPLATE 보존).
 */
class BudgetServiceTemplateSplitTest : BehaviorSpec({

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

    Given("TEMPLATE 식비(1월~무기한, 25만) — 5월 편집, applyToFuture=false") {
        val template = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-01", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE, amount = 250_000L
        )
        every { budgetRepository.findById(template.id) } returns Optional.of(template)
        every { budgetRepository.existsOverrideByCoupleIdAndCategoryGroupAndYearMonth(
            couple.id, foodCat.id, null, "2026-05"
        ) } returns false
        val savedSlot = slot<MonthlyBudget>()
        every { budgetRepository.save(capture(savedSlot)) } answers { savedSlot.captured }

        When("amount=300000, yearMonth=2026-05, applyToFuture=false 로 update") {
            val result = service.updateBudget(u1.id, template.id,
                BudgetUpdateRequest(amount = 300_000L, yearMonth = "2026-05", applyToFuture = false))

            Then("원본 TEMPLATE 그대로 유지 (yearMonth=2026-01, endYearMonth=null, amount=25만)") {
                template.yearMonth shouldBe "2026-01"
                template.endYearMonth shouldBe null
                template.amount shouldBe 250_000L
                template.rowKind shouldBe BudgetRowKind.TEMPLATE
            }
            Then("새 OVERRIDE 가 5월 단일월로 저장됨") {
                val saved = savedSlot.captured
                saved.rowKind shouldBe BudgetRowKind.OVERRIDE
                saved.yearMonth shouldBe "2026-05"
                saved.endYearMonth shouldBe "2026-05"
                saved.amount shouldBe 300_000L
                saved.category?.id shouldBe foodCat.id
            }
            Then("응답은 새 OVERRIDE 의 정보") {
                result.amount shouldBe 300_000L
                result.yearMonth shouldBe "2026-05"
            }
        }
    }

    Given("TEMPLATE 행 편집 시 5월에 이미 OVERRIDE 가 존재") {
        val template = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-01", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE, amount = 250_000L
        )
        every { budgetRepository.findById(template.id) } returns Optional.of(template)
        every { budgetRepository.existsOverrideByCoupleIdAndCategoryGroupAndYearMonth(
            couple.id, foodCat.id, null, "2026-05"
        ) } returns true

        When("split 시도") {
            Then("ConflictException — V57 partial unique 충돌 사전 차단") {
                val ex = shouldThrow<ConflictException> {
                    service.updateBudget(u1.id, template.id,
                        BudgetUpdateRequest(amount = 300_000L, yearMonth = "2026-05", applyToFuture = false))
                }
                ex.code shouldBe "BUDGET_ALREADY_EXISTS"
            }
        }
    }

    // E-3 회귀 방지: viewingMonth == TEMPLATE.yearMonth 케이스 — 자기 자신을
    // false-positive 매칭하던 버그 (이전 existsByCoupleIdAndCategoryGroupAndYearMonth
    // 가 rowKind 무관하게 매칭) 검증.
    Given("TEMPLATE 시작월 == viewingMonth (예: 5월에 신규 등록한 TEMPLATE 을 5월 편집)") {
        val template = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-05", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE, amount = 250_000L
        )
        every { budgetRepository.findById(template.id) } returns Optional.of(template)
        // OVERRIDE 만 검사하므로 false (TEMPLATE 자체는 매칭 안됨)
        every { budgetRepository.existsOverrideByCoupleIdAndCategoryGroupAndYearMonth(
            couple.id, foodCat.id, null, "2026-05"
        ) } returns false
        val savedSlot = slot<MonthlyBudget>()
        every { budgetRepository.save(capture(savedSlot)) } answers { savedSlot.captured }

        When("amount=300000, yearMonth=2026-05, applyToFuture=false 로 update") {
            val result = service.updateBudget(u1.id, template.id,
                BudgetUpdateRequest(amount = 300_000L, yearMonth = "2026-05", applyToFuture = false))

            Then("ConflictException 안 던지고 split 정상 동작 — TEMPLATE 보존 + OVERRIDE 신규") {
                template.amount shouldBe 250_000L
                template.rowKind shouldBe BudgetRowKind.TEMPLATE
                val saved = savedSlot.captured
                saved.rowKind shouldBe BudgetRowKind.OVERRIDE
                saved.yearMonth shouldBe "2026-05"
                saved.amount shouldBe 300_000L
                result.amount shouldBe 300_000L
            }
        }
    }

    Given("TEMPLATE 활성 범위 밖 — viewingMonth < startMonth") {
        val template = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-05", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE, amount = 250_000L
        )
        every { budgetRepository.findById(template.id) } returns Optional.of(template)
        every { budgetRepository.save(template) } returns template

        When("viewingMonth=2026-03 (시작월보다 앞) 으로 update") {
            service.updateBudget(u1.id, template.id,
                BudgetUpdateRequest(amount = 300_000L, yearMonth = "2026-03", applyToFuture = false))

            Then("split 안 일어나고 기존 TEMPLATE 그대로 update (활성 범위 밖이므로)") {
                template.amount shouldBe 300_000L
                template.rowKind shouldBe BudgetRowKind.TEMPLATE
            }
        }
    }

    Given("OVERRIDE 행 편집 (split 미적용)") {
        val override = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-05", endYearMonth = "2026-05",
            rowKind = BudgetRowKind.OVERRIDE, amount = 300_000L
        )
        every { budgetRepository.findById(override.id) } returns Optional.of(override)
        every { budgetRepository.save(override) } returns override

        When("amount=350000, yearMonth=2026-05, applyToFuture=false 로 update") {
            service.updateBudget(u1.id, override.id,
                BudgetUpdateRequest(amount = 350_000L, yearMonth = "2026-05", applyToFuture = false))

            Then("기존 OVERRIDE 행을 그대로 update (split 안 함)") {
                override.amount shouldBe 350_000L
                override.rowKind shouldBe BudgetRowKind.OVERRIDE
                override.yearMonth shouldBe "2026-05"
            }
            Then("split 의 unique check 호출 안 됨") {
                verify(exactly = 0) { budgetRepository.existsByCoupleIdAndCategoryGroupAndYearMonth(any(), any(), any(), any()) }
            }
        }
    }

    Given("TEMPLATE 행 + applyToFuture=true (split 미적용, 기존 C-2 동작 유지)") {
        val template = MonthlyBudget(
            couple = couple, category = foodCat,
            yearMonth = "2026-01", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE, amount = 250_000L
        )
        every { budgetRepository.findById(template.id) } returns Optional.of(template)
        every { budgetRepository.findActiveTemplateInScope(any(), any(), any(), any(), any()) } returns null
        every { budgetRepository.save(template) } returns template

        When("amount=350000, yearMonth=2026-05, applyToFuture=true 로 update") {
            service.updateBudget(u1.id, template.id,
                BudgetUpdateRequest(amount = 350_000L, yearMonth = "2026-05", applyToFuture = true))

            Then("기존 TEMPLATE 의 amount 만 변경 (split 안 함, endYearMonth=null 유지)") {
                template.amount shouldBe 350_000L
                template.rowKind shouldBe BudgetRowKind.TEMPLATE
                template.endYearMonth shouldBe null
            }
        }
    }
})
