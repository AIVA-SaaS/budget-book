package com.budgetbook.smart.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.domain.PeriodType
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import com.budgetbook.statistics.service.StatisticsService
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CategorySummary
import com.budgetbook.transaction.repository.TransactionRepository
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.mockk.every
import io.mockk.mockk
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

class SmartAnalysisServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val budgetRepository = mockk<MonthlyBudgetRepository>()
    val statisticsService = mockk<StatisticsService>()
    val redisCacheService = mockk<RedisCacheService>(relaxed = true)
    val objectMapper = ObjectMapper().registerKotlinModule().registerModule(JavaTimeModule())
    val coupleResolver = mockk<CoupleResolver>()

    val service = SmartAnalysisService(
        transactionRepository, budgetRepository, statisticsService,
        redisCacheService, objectMapper, coupleResolver
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    every { coupleResolver.getActiveCouple(user1.id) } returns couple
    // Default: no cache hit
    every { redisCacheService.get(any()) } returns null

    val catId1 = UUID.randomUUID()
    val catId2 = UUID.randomUUID()

    fun makeCategoryStat(catName: String, catId: UUID, amount: Long, pct: Double = 0.0) = CategoryStatisticsResponse(
        category = CategorySummary(id = catId, name = catName, type = "EXPENSE", icon = null, color = null, groupId = null, groupName = null),
        amount = amount,
        percentage = pct,
        transactionCount = 1
    )

    // Helper for summary
    fun makeSummary(ym: String, income: Long, expense: Long) = StatisticsSummaryResponse(
        yearMonth = ym,
        totalIncome = income,
        totalExpense = expense,
        totalTransfer = 0,
        balance = income - expense,
        transactionCount = 0
    )

    // --- generateInsights ---

    Given("generating insights") {
        val year = 2026
        val month = 4
        val currentYm = YearMonth.of(year, month)
        val prevYm = currentYm.minusMonths(1)
        val twoMonthsAgoYm = currentYm.minusMonths(2)

        // Default mocks for all rules
        every { statisticsService.getCategoryBreakdown(user1.id, year, month, "EXPENSE") } returns listOf(
            makeCategoryStat("식비", catId1, 500000L),
            makeCategoryStat("교통비", catId2, 200000L)
        )
        every { statisticsService.getCategoryBreakdown(user1.id, prevYm.year, prevYm.monthValue, "EXPENSE") } returns listOf(
            makeCategoryStat("식비", catId1, 400000L),
            makeCategoryStat("교통비", catId2, 200000L)
        )
        every { statisticsService.getMonthlySummary(user1.id, year, month) } returns makeSummary("$currentYm", 3000000L, 700000L)
        every { statisticsService.getMonthlySummary(user1.id, prevYm.year, prevYm.monthValue) } returns makeSummary("$prevYm", 3000000L, 800000L)
        every { statisticsService.getMonthlySummary(user1.id, twoMonthsAgoYm.year, twoMonthsAgoYm.monthValue) } returns makeSummary("$twoMonthsAgoYm", 3000000L, 900000L)

        // Default: no budgets, no daily data
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, currentYm.toString(), user1.id) } returns emptyList()
        every { transactionRepository.dailySummaryForCouple(couple.id, any(), any(), any(), "ALL") } returns emptyList()

        When("식비 increased >20% from previous month") {
            val result = service.generateInsights(user1.id, year, month)

            Then("generates SPENDING_CHANGE insight for 식비 with categoryId") {
                val spendingChange = result.insights.filter { it.type == "SPENDING_CHANGE" }
                spendingChange shouldHaveSize 1
                spendingChange[0].title shouldContain "식비"
                spendingChange[0].severity shouldBe "WARNING"
                spendingChange[0].data?.get("categoryId") shouldBe catId1.toString()
            }
        }

        When("3 consecutive months of decreasing spending") {
            Then("generates POSITIVE insight") {
                val result = service.generateInsights(user1.id, year, month)
                val positiveInsights = result.insights.filter { it.type == "POSITIVE" }
                positiveInsights shouldHaveSize 1
                positiveInsights[0].title shouldContain "3개월"
            }
        }

        When("no significant changes") {
            every { statisticsService.getCategoryBreakdown(user1.id, year, month, "EXPENSE") } returns listOf(
                makeCategoryStat("식비", catId1, 100000L)
            )
            every { statisticsService.getCategoryBreakdown(user1.id, prevYm.year, prevYm.monthValue, "EXPENSE") } returns listOf(
                makeCategoryStat("식비", catId1, 100000L)
            )
            every { statisticsService.getMonthlySummary(user1.id, year, month) } returns makeSummary("$currentYm", 3000000L, 100000L)
            every { statisticsService.getMonthlySummary(user1.id, prevYm.year, prevYm.monthValue) } returns makeSummary("$prevYm", 3000000L, 100000L)
            every { statisticsService.getMonthlySummary(user1.id, twoMonthsAgoYm.year, twoMonthsAgoYm.monthValue) } returns makeSummary("$twoMonthsAgoYm", 3000000L, 100000L)

            val result = service.generateInsights(user1.id, year, month)

            Then("no SPENDING_CHANGE or POSITIVE insights") {
                result.insights.filter { it.type == "SPENDING_CHANGE" }.shouldBeEmpty()
                result.insights.filter { it.type == "POSITIVE" }.shouldBeEmpty()
            }
        }

        When("weekend spending exceeds weekday by 1.5x") {
            // Monday and Saturday data
            val monday = currentYm.atDay(6) // 2026-04-06 is a Monday
            val saturday = currentYm.atDay(4) // 2026-04-04 is a Saturday

            every {
                transactionRepository.dailySummaryForCouple(couple.id, any(), any(), any(), "ALL")
            } returns listOf(
                arrayOf<Any>(java.sql.Date.valueOf(monday), "EXPENSE", 10000L, 1L),
                arrayOf<Any>(java.sql.Date.valueOf(saturday), "EXPENSE", 20000L, 1L)
            )

            val result = service.generateInsights(user1.id, year, month)

            Then("generates PATTERN insight") {
                val patternInsights = result.insights.filter { it.type == "PATTERN" }
                patternInsights shouldHaveSize 1
                patternInsights[0].title shouldContain "주말"
            }
        }
    }

    // --- getBudgetSuggestions ---

    Given("budget suggestions") {
        val currentYm = YearMonth.now()
        val category = Category(
            id = catId1, couple = couple, name = "식비", type = CategoryType.EXPENSE
        )

        When("budget has >30% difference from 3-month avg spending") {
            val budget = MonthlyBudget(
                couple = couple,
                category = category,
                yearMonth = currentYm.toString(),
                amount = 500000L,
                budgetPeriod = BudgetPeriod.MONTHLY,
                periodType = PeriodType.MONTHLY
            )

            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, currentYm.toString(), user1.id) } returns listOf(budget)

            // 3-month avg: each month spent 800000 -> avg = 800000 (>30% diff from 500000)
            for (i in 1..3) {
                val ym = currentYm.minusMonths(i.toLong())
                every {
                    transactionRepository.sumAmountByCoupleIdAndDateRangeAndCategories(
                        couple.id, ym.atDay(1), ym.atEndOfMonth(), TransactionType.EXPENSE, setOf(catId1), user1.id
                    )
                } returns 800000L
            }

            val suggestions = service.getBudgetSuggestions(user1.id)

            Then("returns suggestion with recommended amount") {
                suggestions shouldHaveSize 1
                suggestions[0].budgetName shouldBe "식비"
                suggestions[0].currentAmount shouldBe 500000L
                suggestions[0].suggestedAmount shouldBe 800000L
                suggestions[0].avgSpending shouldBe 800000L
                suggestions[0].reason shouldContain "높습니다"
            }
        }

        When("no budgets exist") {
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, currentYm.toString(), user1.id) } returns emptyList()

            val suggestions = service.getBudgetSuggestions(user1.id)

            Then("returns empty list") {
                suggestions.shouldBeEmpty()
            }
        }

        When("budget matches spending within 30%") {
            val budget = MonthlyBudget(
                couple = couple,
                category = category,
                yearMonth = currentYm.toString(),
                amount = 500000L,
                budgetPeriod = BudgetPeriod.MONTHLY,
                periodType = PeriodType.MONTHLY
            )

            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, currentYm.toString(), user1.id) } returns listOf(budget)

            for (i in 1..3) {
                val ym = currentYm.minusMonths(i.toLong())
                every {
                    transactionRepository.sumAmountByCoupleIdAndDateRangeAndCategories(
                        couple.id, ym.atDay(1), ym.atEndOfMonth(), TransactionType.EXPENSE, setOf(catId1), user1.id
                    )
                } returns 480000L
            }

            val suggestions = service.getBudgetSuggestions(user1.id)

            Then("returns no suggestions") {
                suggestions.shouldBeEmpty()
            }
        }
    }
})
