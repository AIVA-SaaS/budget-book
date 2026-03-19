package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.domain.WeeklyBudgetSnapshot
import com.budgetbook.budget.domain.WeeklyStatus
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.budget.repository.WeeklyBudgetSnapshotRepository
import com.budgetbook.category.domain.BudgetType
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryGroup
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

class WeeklyBudgetServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val snapshotRepository = mockk<WeeklyBudgetSnapshotRepository>()
    val budgetRepository = mockk<MonthlyBudgetRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val categoryGroupRepository = mockk<CategoryGroupRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val service = WeeklyBudgetService(
        snapshotRepository, budgetRepository, coupleResolver,
        categoryGroupRepository, categoryRepository, transactionRepository
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    // --- calculateWeekRanges ---

    Given("a month with 31 days (March 2026)") {
        When("calculateWeekRanges is called") {
            val ranges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 3))

            Then("returns 5 weeks") {
                ranges.size shouldBe 5
                ranges[0] shouldBe (LocalDate.of(2026, 3, 1) to LocalDate.of(2026, 3, 7))
                ranges[1] shouldBe (LocalDate.of(2026, 3, 8) to LocalDate.of(2026, 3, 14))
                ranges[2] shouldBe (LocalDate.of(2026, 3, 15) to LocalDate.of(2026, 3, 21))
                ranges[3] shouldBe (LocalDate.of(2026, 3, 22) to LocalDate.of(2026, 3, 28))
                ranges[4] shouldBe (LocalDate.of(2026, 3, 29) to LocalDate.of(2026, 3, 31))
            }
        }
    }

    Given("February 2026 (28 days)") {
        When("calculateWeekRanges is called") {
            val ranges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 2))

            Then("returns 4 weeks exactly") {
                ranges.size shouldBe 4
                ranges[0] shouldBe (LocalDate.of(2026, 2, 1) to LocalDate.of(2026, 2, 7))
                ranges[3] shouldBe (LocalDate.of(2026, 2, 22) to LocalDate.of(2026, 2, 28))
            }
        }
    }

    // --- getWeeklyOverview ---

    Given("budgets exist for a user's couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget = MonthlyBudget(
            couple = couple, yearMonth = "2026-03", amount = 500000,
            budgetPeriod = BudgetPeriod.MONTHLY
        )
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", any()) } returns listOf(budget)
        every { snapshotRepository.findByCoupleIdAndYearMonth(couple.id, "2026-03") } returns emptyList()

        // Mock SUM queries for each week (returns 0 for all)
        every { transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id,
            startDate = any(),
            endDate = any(),
            type = TransactionType.EXPENSE,
            userId = any()
        ) } returns 0L

        When("getWeeklyOverview is called") {
            val result = service.getWeeklyOverview(user1.id, 2026, 3)

            Then("returns overview with 5 weeks for March") {
                result.yearMonth shouldBe "2026-03"
                result.weeks.size shouldBe 5
                result.weeks[0].weekNumber shouldBe 1
                result.weeks[0].weekStart shouldBe "2026-03-01"
                result.weeks[0].weekEnd shouldBe "2026-03-07"
                // 500000 / 5 weeks = 100000 per week
                result.weeks[0].budgetAmount shouldBe 100000
            }
        }
    }

    Given("snapshots already exist") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val snapshot = WeeklyBudgetSnapshot(
            couple = couple, yearMonth = "2026-03", weekNumber = 1,
            weekStart = LocalDate.of(2026, 3, 1), weekEnd = LocalDate.of(2026, 3, 7),
            budgetAmount = 100000, spentAmount = 80000, status = WeeklyStatus.UNDER
        )
        every { snapshotRepository.findByCoupleIdAndYearMonth(couple.id, "2026-03") } returns listOf(snapshot)
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", any()) } returns listOf(
            MonthlyBudget(couple = couple, yearMonth = "2026-03", amount = 500000)
        )

        every { transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id,
            startDate = any(),
            endDate = any(),
            type = TransactionType.EXPENSE,
            userId = any()
        ) } returns 0L

        When("getWeeklyOverview is called") {
            val result = service.getWeeklyOverview(user1.id, 2026, 3)

            Then("uses existing snapshot for week 1") {
                result.weeks[0].spentAmount shouldBe 80000
                result.weeks[0].budgetAmount shouldBe 100000
                result.weeks[0].status shouldBe "UNDER"
            }
        }
    }

    // --- getCurrentWeekSummary ---

    Given("weekly groups exist for the couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val weeklyGroup = CategoryGroup(
            couple = couple, name = "생활비", budgetType = BudgetType.WEEKLY
        )
        val monthlyGroup = CategoryGroup(
            couple = couple, name = "고정비", budgetType = BudgetType.MONTHLY
        )
        every { categoryGroupRepository.findByCoupleId(couple.id) } returns listOf(weeklyGroup, monthlyGroup)

        val category1 = Category(
            couple = couple, name = "식비", type = CategoryType.EXPENSE,
            group = weeklyGroup
        )
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(category1)

        val today = LocalDate.now()
        val yearMonth = "%04d-%02d".format(today.year, today.monthValue)
        val ym = YearMonth.of(today.year, today.monthValue)
        val weekRanges = WeeklyBudgetService.calculateWeekRanges(ym)

        val budget = MonthlyBudget(
            couple = couple, category = category1, yearMonth = yearMonth,
            amount = 400000, budgetPeriod = BudgetPeriod.WEEKLY,
            weeklyAmount = 400000L / weekRanges.size
        )
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, any()) } returns listOf(budget)

        every { transactionRepository.sumAmountGroupedByCategoryId(
            coupleId = couple.id,
            startDate = any(),
            endDate = any(),
            type = TransactionType.EXPENSE,
            categoryIds = setOf(category1.id),
            userId = any()
        ) } returns listOf(arrayOf(category1.id as Any, 15000L as Any))

        When("getCurrentWeekSummary is called") {
            val result = service.getCurrentWeekSummary(user1.id)

            Then("returns summary with only WEEKLY groups") {
                result.groups.size shouldBe 1
                result.groups[0].groupName shouldBe "생활비"
                result.groups[0].spentAmount shouldBe 15000
            }

            Then("returns correct week info") {
                result.yearMonth shouldBe yearMonth
                result.weekNumber shouldBe (weekRanges.indexOfFirst { (start, end) ->
                    !today.isBefore(start) && !today.isAfter(end)
                } + 1)
            }
        }
    }

    // --- user not in couple ---

    Given("a user not in any couple") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("getWeeklyOverview is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.getWeeklyOverview(user1.id, 2026, 3)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }

        When("getCurrentWeekSummary is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.getCurrentWeekSummary(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }
})
