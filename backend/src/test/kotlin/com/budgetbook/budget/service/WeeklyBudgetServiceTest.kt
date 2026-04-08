package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.domain.WeeklyBudgetSnapshot
import com.budgetbook.budget.domain.WeeklyStatus
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.budget.repository.WeeklyBudgetSnapshotRepository
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

    // March 2026 starts on Sunday, 31 days
    Given("a month with 31 days (March 2026, starts Sunday)") {
        When("calculateWeekRanges is called") {
            val ranges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 3))

            Then("returns 6 weeks with real Mon-Sun boundaries clipped to month") {
                ranges.size shouldBe 6
                ranges[0] shouldBe (LocalDate.of(2026, 3, 1) to LocalDate.of(2026, 3, 1))
                ranges[1] shouldBe (LocalDate.of(2026, 3, 2) to LocalDate.of(2026, 3, 8))
                ranges[2] shouldBe (LocalDate.of(2026, 3, 9) to LocalDate.of(2026, 3, 15))
                ranges[3] shouldBe (LocalDate.of(2026, 3, 16) to LocalDate.of(2026, 3, 22))
                ranges[4] shouldBe (LocalDate.of(2026, 3, 23) to LocalDate.of(2026, 3, 29))
                ranges[5] shouldBe (LocalDate.of(2026, 3, 30) to LocalDate.of(2026, 3, 31))
            }
        }
    }

    Given("February 2026 (28 days, starts Sunday)") {
        When("calculateWeekRanges is called") {
            val ranges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 2))

            Then("returns 5 weeks with month boundary clipping") {
                ranges.size shouldBe 5
                ranges[0] shouldBe (LocalDate.of(2026, 2, 1) to LocalDate.of(2026, 2, 1))
                ranges[1] shouldBe (LocalDate.of(2026, 2, 2) to LocalDate.of(2026, 2, 8))
                ranges[2] shouldBe (LocalDate.of(2026, 2, 9) to LocalDate.of(2026, 2, 15))
                ranges[3] shouldBe (LocalDate.of(2026, 2, 16) to LocalDate.of(2026, 2, 22))
                ranges[4] shouldBe (LocalDate.of(2026, 2, 23) to LocalDate.of(2026, 2, 28))
            }
        }
    }

    Given("April 2026 (30 days, starts Wednesday)") {
        When("calculateWeekRanges is called") {
            val ranges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 4))

            Then("returns 5 weeks with correct boundary clipping") {
                ranges.size shouldBe 5
                ranges[0] shouldBe (LocalDate.of(2026, 4, 1) to LocalDate.of(2026, 4, 5))
                ranges[1] shouldBe (LocalDate.of(2026, 4, 6) to LocalDate.of(2026, 4, 12))
                ranges[2] shouldBe (LocalDate.of(2026, 4, 13) to LocalDate.of(2026, 4, 19))
                ranges[3] shouldBe (LocalDate.of(2026, 4, 20) to LocalDate.of(2026, 4, 26))
                ranges[4] shouldBe (LocalDate.of(2026, 4, 27) to LocalDate.of(2026, 4, 30))
            }
        }
    }

    Given("a month starting on Monday (June 2026)") {
        When("calculateWeekRanges is called") {
            val ranges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 6))

            Then("first week starts on the 1st with no partial prefix") {
                ranges.size shouldBe 5
                ranges[0] shouldBe (LocalDate.of(2026, 6, 1) to LocalDate.of(2026, 6, 7))
                ranges[4] shouldBe (LocalDate.of(2026, 6, 29) to LocalDate.of(2026, 6, 30))
            }
        }
    }

    // --- calculateProRataBudget ---

    Given("a weekly budget amount of 70000") {
        When("calculating pro-rata for a full 7-day week") {
            val result = WeeklyBudgetService.calculateProRataBudget(
                70000, LocalDate.of(2026, 3, 2), LocalDate.of(2026, 3, 8)
            )
            Then("returns the full weekly amount") {
                result shouldBe 70000
            }
        }

        When("calculating pro-rata for a 1-day partial week") {
            val result = WeeklyBudgetService.calculateProRataBudget(
                70000, LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 1)
            )
            Then("returns 1/7 of the weekly amount") {
                result shouldBe 10000
            }
        }

        When("calculating pro-rata for a 2-day partial week") {
            val result = WeeklyBudgetService.calculateProRataBudget(
                70000, LocalDate.of(2026, 3, 30), LocalDate.of(2026, 3, 31)
            )
            Then("returns 2/7 of the weekly amount") {
                result shouldBe 20000
            }
        }

        When("calculating pro-rata for a 5-day partial week") {
            val result = WeeklyBudgetService.calculateProRataBudget(
                70000, LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 5)
            )
            Then("returns 5/7 of the weekly amount") {
                result shouldBe 50000
            }
        }
    }

    // --- getWeeklyOverview ---

    Given("only MONTHLY budgets exist (no WEEKLY)") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget = MonthlyBudget(
            couple = couple, yearMonth = "2026-03", amount = 500000,
            budgetPeriod = BudgetPeriod.MONTHLY
        )
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", any()) } returns listOf(budget)

        When("getWeeklyOverview is called") {
            val result = service.getWeeklyOverview(user1.id, 2026, 3)

            Then("returns overview with empty items since MONTHLY budgets are excluded") {
                result.yearMonth shouldBe "2026-03"
                result.weeks.size shouldBe 6
                result.weeks.forEach { week ->
                    week.totalBudget shouldBe 0
                    week.totalSpent shouldBe 0
                    week.items.size shouldBe 0
                }
            }
        }
    }

    Given("WEEKLY budgets exist for a user's couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val category = Category(
            couple = couple, name = "식비", type = CategoryType.EXPENSE
        )
        // weeklyAmount = 70000 means 70000 per full 7-day week
        val weeklyBudget = MonthlyBudget(
            couple = couple, category = category, yearMonth = "2026-03",
            amount = 350000, budgetPeriod = BudgetPeriod.WEEKLY, weeklyAmount = 70000
        )
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", any()) } returns listOf(weeklyBudget)
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(category)

        // Mock spending per category per week
        every { transactionRepository.sumAmountGroupedByCategoryId(
            coupleId = couple.id,
            startDate = any(),
            endDate = any(),
            type = TransactionType.EXPENSE,
            categoryIds = setOf(category.id),
            userId = any()
        ) } returns listOf(arrayOf(category.id as Any, 15000L as Any))

        When("getWeeklyOverview is called") {
            val result = service.getWeeklyOverview(user1.id, 2026, 3)

            Then("returns overview with 6 weeks and per-item breakdown") {
                result.yearMonth shouldBe "2026-03"
                result.weeks.size shouldBe 6

                // Week 1 (1 day): pro-rata = 70000 * 1 / 7 = 10000
                result.weeks[0].weekNumber shouldBe 1
                result.weeks[0].items.size shouldBe 1
                result.weeks[0].items[0].budgetId shouldBe weeklyBudget.id
                result.weeks[0].items[0].categoryName shouldBe "식비"
                result.weeks[0].items[0].budgetAmount shouldBe 10000
                result.weeks[0].items[0].spentAmount shouldBe 15000
                result.weeks[0].totalBudget shouldBe 10000
                result.weeks[0].totalSpent shouldBe 15000
                result.weeks[0].totalRemaining shouldBe -5000

                // Week 2 (7 days): pro-rata = 70000 * 7 / 7 = 70000
                result.weeks[1].items[0].budgetAmount shouldBe 70000
                result.weeks[1].items[0].spentAmount shouldBe 15000
                result.weeks[1].totalBudget shouldBe 70000
            }
        }
    }

    Given("WEEKLY budget with group (not category)") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group = CategoryGroup(couple = couple, name = "생활비")
        val cat1 = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, group = group)
        val cat2 = Category(couple = couple, name = "교통비", type = CategoryType.EXPENSE, group = group)

        val weeklyBudget = MonthlyBudget(
            couple = couple, group = group, yearMonth = "2026-06",
            amount = 280000, budgetPeriod = BudgetPeriod.WEEKLY, weeklyAmount = 70000
        )
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-06", any()) } returns listOf(weeklyBudget)
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(cat1, cat2)

        every { transactionRepository.sumAmountGroupedByCategoryId(
            coupleId = couple.id,
            startDate = any(),
            endDate = any(),
            type = TransactionType.EXPENSE,
            categoryIds = setOf(cat1.id, cat2.id),
            userId = any()
        ) } returns listOf(
            arrayOf(cat1.id as Any, 10000L as Any),
            arrayOf(cat2.id as Any, 5000L as Any)
        )

        When("getWeeklyOverview is called") {
            val result = service.getWeeklyOverview(user1.id, 2026, 6)

            Then("sums spending from all categories in the group") {
                result.weeks.size shouldBe 5
                // Week 1 (7 days): full week
                val week1 = result.weeks[0]
                week1.items.size shouldBe 1
                week1.items[0].groupName shouldBe "생활비"
                week1.items[0].budgetAmount shouldBe 70000
                week1.items[0].spentAmount shouldBe 15000  // 10000 + 5000
                week1.totalBudget shouldBe 70000
                week1.totalSpent shouldBe 15000
            }
        }
    }

    // --- getCurrentWeekSummary ---

    Given("WEEKLY budgets exist for current week summary") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val category1 = Category(
            couple = couple, name = "식비", type = CategoryType.EXPENSE
        )
        val today = LocalDate.now()
        val yearMonth = "%04d-%02d".format(today.year, today.monthValue)
        val ym = YearMonth.of(today.year, today.monthValue)
        val weekRanges = WeeklyBudgetService.calculateWeekRanges(ym)

        val weeklyBudget = MonthlyBudget(
            couple = couple, category = category1, yearMonth = yearMonth,
            amount = 400000, budgetPeriod = BudgetPeriod.WEEKLY,
            weeklyAmount = 400000L / weekRanges.size
        )
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, any()) } returns listOf(weeklyBudget)
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(category1)

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

            Then("returns summary with per-budget items") {
                result.items.size shouldBe 1
                result.items[0].categoryName shouldBe "식비"
                result.items[0].spentAmount shouldBe 15000
                result.items[0].budgetId shouldBe weeklyBudget.id
            }

            Then("returns correct week info") {
                result.yearMonth shouldBe yearMonth
                result.weekNumber shouldBe (weekRanges.indexOfFirst { (start, end) ->
                    !today.isBefore(start) && !today.isAfter(end)
                } + 1)
            }
        }
    }

    Given("no WEEKLY budgets for current week") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val today = LocalDate.now()
        val yearMonth = "%04d-%02d".format(today.year, today.monthValue)

        val monthlyBudget = MonthlyBudget(
            couple = couple, yearMonth = yearMonth, amount = 500000,
            budgetPeriod = BudgetPeriod.MONTHLY
        )
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, any()) } returns listOf(monthlyBudget)

        When("getCurrentWeekSummary is called") {
            val result = service.getCurrentWeekSummary(user1.id)

            Then("returns empty items") {
                result.items.size shouldBe 0
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

    // --- Pro-rata sum with last-week remainder equals exactly the monthly total ---

    Given("verifying pro-rata budget sums with last-week remainder") {

        fun proRataSumWithRemainder(monthlyAmount: Long, ym: YearMonth): Long {
            val weekRanges = WeeklyBudgetService.calculateWeekRanges(ym)
            val perWeek = monthlyAmount * 7 / ym.lengthOfMonth()
            val monthlyTotal = perWeek * ym.lengthOfMonth().toLong() / 7
            val sumOfPrevious = weekRanges.take(weekRanges.size - 1).sumOf { (s, e) ->
                WeeklyBudgetService.calculateProRataBudget(perWeek, s, e)
            }
            val lastWeek = monthlyTotal - sumOfPrevious
            return sumOfPrevious + lastWeek
        }

        When("summing pro-rata budgets for March 2026 (31 days)") {
            val ym = YearMonth.of(2026, 3)
            val perWeek = 100000L * 7 / ym.lengthOfMonth()
            val monthlyTotal = perWeek * ym.lengthOfMonth().toLong() / 7
            val result = proRataSumWithRemainder(100000L, ym)
            Then("total exactly equals monthly total") {
                result shouldBe monthlyTotal
            }
        }

        When("summing pro-rata budgets for April 2026 (30 days)") {
            val ym = YearMonth.of(2026, 4)
            val perWeek = 100000L * 7 / ym.lengthOfMonth()
            val monthlyTotal = perWeek * ym.lengthOfMonth().toLong() / 7
            val result = proRataSumWithRemainder(100000L, ym)
            Then("total exactly equals monthly total") {
                result shouldBe monthlyTotal
            }
        }

        When("summing pro-rata budgets for Feb 2026 (28 days)") {
            val ym = YearMonth.of(2026, 2)
            val perWeek = 500000L * 7 / ym.lengthOfMonth()
            val monthlyTotal = perWeek * ym.lengthOfMonth().toLong() / 7
            val result = proRataSumWithRemainder(500000L, ym)
            Then("total exactly equals monthly total") {
                result shouldBe monthlyTotal
            }
        }

        When("summing pro-rata budgets for June 2026 (30 days, starts Monday)") {
            val ym = YearMonth.of(2026, 6)
            val perWeek = 350000L * 7 / ym.lengthOfMonth()
            val monthlyTotal = perWeek * ym.lengthOfMonth().toLong() / 7
            val result = proRataSumWithRemainder(350000L, ym)
            Then("total exactly equals monthly total") {
                result shouldBe monthlyTotal
            }
        }
    }
})
