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

    // March 2026 starts on Sunday, 31 days
    // Week 1: Mar 1 (Sun) -- 1 day partial
    // Week 2: Mar 2 (Mon) - Mar 8 (Sun) -- 7 days
    // Week 3: Mar 9 (Mon) - Mar 15 (Sun) -- 7 days
    // Week 4: Mar 16 (Mon) - Mar 22 (Sun) -- 7 days
    // Week 5: Mar 23 (Mon) - Mar 29 (Sun) -- 7 days
    // Week 6: Mar 30 (Mon) - Mar 31 (Tue) -- 2 days partial
    Given("a month with 31 days (March 2026, starts Sunday)") {
        When("calculateWeekRanges is called") {
            val ranges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 3))

            Then("returns 6 weeks with real Mon-Sun boundaries clipped to month") {
                ranges.size shouldBe 6
                ranges[0] shouldBe (LocalDate.of(2026, 3, 1) to LocalDate.of(2026, 3, 1))   // Sun only
                ranges[1] shouldBe (LocalDate.of(2026, 3, 2) to LocalDate.of(2026, 3, 8))   // Mon-Sun
                ranges[2] shouldBe (LocalDate.of(2026, 3, 9) to LocalDate.of(2026, 3, 15))  // Mon-Sun
                ranges[3] shouldBe (LocalDate.of(2026, 3, 16) to LocalDate.of(2026, 3, 22)) // Mon-Sun
                ranges[4] shouldBe (LocalDate.of(2026, 3, 23) to LocalDate.of(2026, 3, 29)) // Mon-Sun
                ranges[5] shouldBe (LocalDate.of(2026, 3, 30) to LocalDate.of(2026, 3, 31)) // Mon-Tue
            }
        }
    }

    // February 2026 starts on Sunday, 28 days
    // Week 1: Feb 1 (Sun) -- 1 day partial
    // Week 2: Feb 2 (Mon) - Feb 8 (Sun) -- 7 days
    // Week 3: Feb 9 (Mon) - Feb 15 (Sun) -- 7 days
    // Week 4: Feb 16 (Mon) - Feb 22 (Sun) -- 7 days
    // Week 5: Feb 23 (Mon) - Feb 28 (Sat) -- 6 days partial
    Given("February 2026 (28 days, starts Sunday)") {
        When("calculateWeekRanges is called") {
            val ranges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 2))

            Then("returns 5 weeks with month boundary clipping") {
                ranges.size shouldBe 5
                ranges[0] shouldBe (LocalDate.of(2026, 2, 1) to LocalDate.of(2026, 2, 1))   // Sun only
                ranges[1] shouldBe (LocalDate.of(2026, 2, 2) to LocalDate.of(2026, 2, 8))   // Mon-Sun
                ranges[2] shouldBe (LocalDate.of(2026, 2, 9) to LocalDate.of(2026, 2, 15))  // Mon-Sun
                ranges[3] shouldBe (LocalDate.of(2026, 2, 16) to LocalDate.of(2026, 2, 22)) // Mon-Sun
                ranges[4] shouldBe (LocalDate.of(2026, 2, 23) to LocalDate.of(2026, 2, 28)) // Mon-Sat
            }
        }
    }

    // April 2026 starts on Wednesday, 30 days
    // Week 1: Apr 1 (Wed) - Apr 5 (Sun) -- 5 days partial
    // Week 2: Apr 6 (Mon) - Apr 12 (Sun) -- 7 days
    // Week 3: Apr 13 (Mon) - Apr 19 (Sun) -- 7 days
    // Week 4: Apr 20 (Mon) - Apr 26 (Sun) -- 7 days
    // Week 5: Apr 27 (Mon) - Apr 30 (Thu) -- 4 days partial
    Given("April 2026 (30 days, starts Wednesday)") {
        When("calculateWeekRanges is called") {
            val ranges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 4))

            Then("returns 5 weeks with correct boundary clipping") {
                ranges.size shouldBe 5
                ranges[0] shouldBe (LocalDate.of(2026, 4, 1) to LocalDate.of(2026, 4, 5))   // Wed-Sun
                ranges[1] shouldBe (LocalDate.of(2026, 4, 6) to LocalDate.of(2026, 4, 12))  // Mon-Sun
                ranges[2] shouldBe (LocalDate.of(2026, 4, 13) to LocalDate.of(2026, 4, 19)) // Mon-Sun
                ranges[3] shouldBe (LocalDate.of(2026, 4, 20) to LocalDate.of(2026, 4, 26)) // Mon-Sun
                ranges[4] shouldBe (LocalDate.of(2026, 4, 27) to LocalDate.of(2026, 4, 30)) // Mon-Thu
            }
        }
    }

    // Month that starts on Monday -- no partial first week
    // June 2026 starts on Monday, 30 days
    // Week 1: Jun 1 (Mon) - Jun 7 (Sun)
    // Week 2: Jun 8 (Mon) - Jun 14 (Sun)
    // Week 3: Jun 15 (Mon) - Jun 21 (Sun)
    // Week 4: Jun 22 (Mon) - Jun 28 (Sun)
    // Week 5: Jun 29 (Mon) - Jun 30 (Tue)
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
                result shouldBe 70000  // 70000 * 7 / 7
            }
        }

        When("calculating pro-rata for a 1-day partial week") {
            val result = WeeklyBudgetService.calculateProRataBudget(
                70000, LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 1)
            )
            Then("returns 1/7 of the weekly amount") {
                result shouldBe 10000  // 70000 * 1 / 7
            }
        }

        When("calculating pro-rata for a 2-day partial week") {
            val result = WeeklyBudgetService.calculateProRataBudget(
                70000, LocalDate.of(2026, 3, 30), LocalDate.of(2026, 3, 31)
            )
            Then("returns 2/7 of the weekly amount") {
                result shouldBe 20000  // 70000 * 2 / 7
            }
        }

        When("calculating pro-rata for a 5-day partial week") {
            val result = WeeklyBudgetService.calculateProRataBudget(
                70000, LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 5)
            )
            Then("returns 5/7 of the weekly amount") {
                result shouldBe 50000  // 70000 * 5 / 7
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

            Then("returns overview with 6 weeks for March 2026 (Mon-Sun)") {
                result.yearMonth shouldBe "2026-03"
                result.weeks.size shouldBe 6
                result.weeks[0].weekNumber shouldBe 1
                result.weeks[0].weekStart shouldBe "2026-03-01"
                result.weeks[0].weekEnd shouldBe "2026-03-01"

                // Per-week budget = (500000 * 7) / 31 = 112903 (integer division)
                // Week 1 (1 day): 112903 * 1 / 7 = 16129
                result.weeks[0].budgetAmount shouldBe 16129

                // Week 2 (7 days): 112903 * 7 / 7 = 112903
                result.weeks[1].weekStart shouldBe "2026-03-02"
                result.weeks[1].weekEnd shouldBe "2026-03-08"
                result.weeks[1].budgetAmount shouldBe 112903
            }
        }
    }

    Given("snapshots already exist") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val snapshot = WeeklyBudgetSnapshot(
            couple = couple, yearMonth = "2026-03", weekNumber = 1,
            weekStart = LocalDate.of(2026, 3, 1), weekEnd = LocalDate.of(2026, 3, 1),
            budgetAmount = 16129, spentAmount = 8000, status = WeeklyStatus.UNDER
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
                result.weeks[0].spentAmount shouldBe 8000
                result.weeks[0].budgetAmount shouldBe 16129
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

    // --- Pro-rata sum across all weeks equals approximately the monthly total ---

    Given("verifying pro-rata budget sums approximate the total monthly budget") {
        When("summing pro-rata budgets for all weeks in March 2026 (31 days)") {
            val weekRanges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 3))
            // Per-week amount for 500000 monthly: (500000 * 7) / 31 = 112903
            val perWeek = (500000L * 7) / 31
            val totalProRata = weekRanges.sumOf { (s, e) ->
                WeeklyBudgetService.calculateProRataBudget(perWeek, s, e)
            }
            Then("total pro-rata is close to 500000") {
                // Due to integer division, there may be a small rounding loss
                // 31 days: 112903*(1+7+7+7+7+2)/7 = 112903*31/7 = 500013 (approx)
                // Exact: each full week = 112903, partial weeks are scaled
                // The sum should be within a few units of 500000
                (totalProRata in 499900..500100) shouldBe true
            }
        }

        When("summing pro-rata budgets for all weeks in Feb 2026 (28 days)") {
            val weekRanges = WeeklyBudgetService.calculateWeekRanges(YearMonth.of(2026, 2))
            val perWeek = (500000L * 7) / 28  // = 125000
            val totalProRata = weekRanges.sumOf { (s, e) ->
                WeeklyBudgetService.calculateProRataBudget(perWeek, s, e)
            }
            Then("total pro-rata is close to 500000") {
                // 28 is divisible by 7, per-week = 125000
                // But partial weeks (1 day + 6 days) lose 1 each due to integer division
                // 125000*1/7=17857, 125000*6/7=107142 -> 17857+107142=124999 vs 125000
                (totalProRata in 499990..500010) shouldBe true
            }
        }
    }
})
