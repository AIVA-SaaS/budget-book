package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.domain.PeriodType
import com.budgetbook.budget.domain.SettlementStatus
import com.budgetbook.budget.domain.WeeklyBudgetSettlement
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.budget.repository.WeeklyBudgetSettlementRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.time.LocalDate
import java.util.Optional
import java.util.UUID

class WeeklySettlementServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val coupleResolver = mockk<CoupleResolver>()
    val settlementRepository = mockk<WeeklyBudgetSettlementRepository>()
    val budgetRepository = mockk<MonthlyBudgetRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val userRepository = mockk<UserRepository>()
    val syncEventPublisher = mockk<SyncEventPublisher>()

    val service = WeeklySettlementService(
        coupleResolver, settlementRepository, budgetRepository,
        transactionRepository, categoryRepository, userRepository, syncEventPublisher
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val category = Category(
        name = "식비", type = CategoryType.EXPENSE, couple = couple, owner = user1
    )

    val budget = MonthlyBudget(
        couple = couple,
        category = category,
        yearMonth = "2026-04",
        amount = 400000,
        budgetPeriod = BudgetPeriod.WEEKLY,
        weeklyAmount = 100000,
        periodType = PeriodType.WEEKLY
    )

    justRun { syncEventPublisher.publish(any()) }

    Given("getSettlementOverview") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-04", user1.id) } returns listOf(budget)
        every { settlementRepository.findByCoupleIdAndYearMonth(couple.id, "2026-04") } returns emptyList()
        every { categoryRepository.findAllById(any<Iterable<UUID>>()) } returns listOf(category)
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(category)

        // Mock spending queries
        every {
            transactionRepository.sumAmountGroupedByCategoryId(
                coupleId = couple.id,
                startDate = any(),
                endDate = any(),
                type = TransactionType.EXPENSE,
                categoryIds = any(),
                userId = user1.id
            )
        } returns listOf(arrayOf(category.id as Any, 25000L as Any))

        When("called for April 2026") {
            val result = service.getSettlementOverview(user1.id, 2026, 4)

            Then("returns overview with weeks and PENDING items") {
                result.yearMonth shouldBe "2026-04"
                result.weeks.size shouldBe 5 // April 2026 has 5 weeks
                result.weeks[0].items.size shouldBe 1
                result.weeks[0].items[0].status shouldBe "PENDING"
                result.weeks[0].items[0].categoryId shouldBe category.id
                result.weeks[0].items[0].amount shouldBe 25000L
                result.weeks[0].allSettled shouldBe false
            }
        }
    }

    Given("getSettlementOverview with no weekly budgets") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-04", user1.id) } returns emptyList()
        every { settlementRepository.findByCoupleIdAndYearMonth(couple.id, "2026-04") } returns emptyList()

        When("called") {
            val result = service.getSettlementOverview(user1.id, 2026, 4)

            Then("returns empty weeks with no items") {
                result.yearMonth shouldBe "2026-04"
                result.weeks.forEach { it.items shouldBe emptyList() }
            }
        }
    }

    Given("settleWeek") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every {
            settlementRepository.findByBudgetIdAndYearMonthAndWeekNumber(budget.id, "2026-04", 1)
        } returns emptyList()
        every {
            transactionRepository.sumAmountGroupedByCategoryId(
                coupleId = couple.id,
                startDate = any(),
                endDate = any(),
                type = TransactionType.EXPENSE,
                categoryIds = setOf(category.id),
                userId = user1.id
            )
        } returns listOf(arrayOf(category.id as Any, 30000L as Any))
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(category)
        every { categoryRepository.findById(category.id) } returns Optional.of(category)

        val savedSettlement = slot<WeeklyBudgetSettlement>()
        every { settlementRepository.save(capture(savedSettlement)) } answers { savedSettlement.captured }

        When("settling week 1 for the budget") {
            service.settleWeek(
                user1.id,
                com.budgetbook.budget.dto.SettleWeekRequest(
                    budgetId = budget.id,
                    yearMonth = "2026-04",
                    weekNumber = 1
                )
            )

            Then("creates a SETTLED settlement record") {
                savedSettlement.captured.status shouldBe SettlementStatus.SETTLED
                savedSettlement.captured.settledAmount shouldBe 30000L
                savedSettlement.captured.weekNumber shouldBe 1
                savedSettlement.captured.category?.id shouldBe category.id
            }

            Then("publishes sync event") {
                verify(exactly = 1) { syncEventPublisher.publish(any()) }
            }
        }
    }

    Given("unsettleWeek") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(category)

        val existingSettlement = WeeklyBudgetSettlement(
            couple = couple,
            budget = budget,
            yearMonth = "2026-04",
            weekNumber = 1,
            weekStart = LocalDate.of(2026, 4, 1),
            weekEnd = LocalDate.of(2026, 4, 5),
            category = category,
            settledAmount = 30000,
            status = SettlementStatus.SETTLED,
            settledBy = user1
        )

        every {
            settlementRepository.findByBudgetIdAndYearMonthAndWeekNumber(budget.id, "2026-04", 1)
        } returns listOf(existingSettlement)
        every { settlementRepository.save(any()) } answers { firstArg() }

        When("unsettling week 1") {
            service.unsettleWeek(
                user1.id,
                com.budgetbook.budget.dto.UnsettleWeekRequest(
                    budgetId = budget.id,
                    yearMonth = "2026-04",
                    weekNumber = 1
                )
            )

            Then("sets status back to PENDING") {
                existingSettlement.status shouldBe SettlementStatus.PENDING
                existingSettlement.settledAt shouldBe null
                existingSettlement.settledBy shouldBe null
            }

            Then("publishes sync event") {
                verify(exactly = 1) { syncEventPublisher.publish(any()) }
            }
        }
    }

    Given("settleWeek with existing PENDING settlement") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(category)

        val pendingSettlement = WeeklyBudgetSettlement(
            couple = couple,
            budget = budget,
            yearMonth = "2026-04",
            weekNumber = 1,
            weekStart = LocalDate.of(2026, 4, 1),
            weekEnd = LocalDate.of(2026, 4, 5),
            category = category,
            settledAmount = 0,
            status = SettlementStatus.PENDING
        )

        every {
            settlementRepository.findByBudgetIdAndYearMonthAndWeekNumber(budget.id, "2026-04", 1)
        } returns listOf(pendingSettlement)
        every {
            transactionRepository.sumAmountGroupedByCategoryId(
                coupleId = couple.id,
                startDate = any(),
                endDate = any(),
                type = TransactionType.EXPENSE,
                categoryIds = setOf(category.id),
                userId = user1.id
            )
        } returns listOf(arrayOf(category.id as Any, 50000L as Any))
        every { settlementRepository.save(any()) } answers { firstArg() }

        When("settling the week") {
            service.settleWeek(
                user1.id,
                com.budgetbook.budget.dto.SettleWeekRequest(
                    budgetId = budget.id,
                    yearMonth = "2026-04",
                    weekNumber = 1
                )
            )

            Then("updates the existing record to SETTLED") {
                pendingSettlement.status shouldBe SettlementStatus.SETTLED
                pendingSettlement.settledAmount shouldBe 50000L
                pendingSettlement.settledBy shouldBe user1
            }
        }
    }
})
