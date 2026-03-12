package com.budgetbook.report.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.domain.BudgetType
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryGroup
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.PageRequest
import java.time.LocalDate
import java.util.UUID

class ReportServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val categoryGroupRepository = mockk<CategoryGroupRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val budgetRepository = mockk<MonthlyBudgetRepository>()

    val service = ReportService(
        transactionRepository,
        coupleRepository,
        categoryGroupRepository,
        categoryRepository,
        budgetRepository
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    val foodGroup = CategoryGroup(couple = couple, name = "Food", budgetType = BudgetType.WEEKLY)
    val monthlyGroup = CategoryGroup(couple = couple, name = "Fixed", budgetType = BudgetType.MONTHLY)

    val foodCategory = Category(
        couple = couple, name = "Meals", type = CategoryType.EXPENSE,
        icon = "restaurant", color = "#FF5733", group = foodGroup
    )
    val transportCategory = Category(
        couple = couple, name = "Transport", type = CategoryType.EXPENSE,
        icon = "directions_car", color = "#2196F3", group = monthlyGroup
    )

    // --- getWeeklyReport ---

    Given("a user in an active couple for weekly report") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("requesting week 1 of March 2026 with transactions") {
            // Week 1: March 1-7
            val tx1 = Transaction(
                couple = couple, author = user1, category = foodCategory,
                type = TransactionType.EXPENSE, amount = 50000, description = "Lunch",
                transactionDate = LocalDate.of(2026, 3, 2)
            )
            val tx2 = Transaction(
                couple = couple, author = user1, category = foodCategory,
                type = TransactionType.EXPENSE, amount = 30000, description = "Dinner",
                transactionDate = LocalDate.of(2026, 3, 4)
            )
            val tx3 = Transaction(
                couple = couple, author = user2, category = transportCategory,
                type = TransactionType.EXPENSE, amount = 20000, description = "Taxi",
                transactionDate = LocalDate.of(2026, 3, 1)
            )

            every {
                transactionRepository.findByCoupleIdAndFilters(
                    coupleId = couple.id,
                    startDate = LocalDate.of(2026, 3, 1),
                    endDate = LocalDate.of(2026, 3, 7),
                    type = TransactionType.EXPENSE,
                    categoryId = null,
                    pageable = any()
                )
            } returns PageImpl(listOf(tx1, tx2, tx3))

            // Weekly budget setup: foodGroup is WEEKLY
            every { categoryGroupRepository.findByCoupleId(couple.id) } returns listOf(foodGroup, monthlyGroup)
            every { categoryRepository.findByCoupleIdAndGroupId(couple.id, foodGroup.id) } returns listOf(foodCategory)
            every { categoryRepository.findByCoupleIdAndGroupId(couple.id, monthlyGroup.id) } returns listOf(transportCategory)

            val foodBudget = MonthlyBudget(couple = couple, category = foodCategory, yearMonth = "2026-03", amount = 500000)
            val transportBudget = MonthlyBudget(couple = couple, category = transportCategory, yearMonth = "2026-03", amount = 200000)
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-03") } returns listOf(foodBudget, transportBudget)

            // Current week category breakdown
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 7),
                    TransactionType.EXPENSE
                )
            } returns listOf(
                arrayOf(80000L, 2L, foodCategory.id, "Meals", CategoryType.EXPENSE, "restaurant", "#FF5733"),
                arrayOf(20000L, 1L, transportCategory.id, "Transport", CategoryType.EXPENSE, "directions_car", "#2196F3")
            )

            // Previous 4 weeks category breakdown (Feb 1-28)
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 2, 1),
                    LocalDate.of(2026, 2, 28),
                    TransactionType.EXPENSE
                )
            } returns listOf(
                arrayOf(200000L, 8L, foodCategory.id, "Meals", CategoryType.EXPENSE, "restaurant", "#FF5733"),
                arrayOf(60000L, 4L, transportCategory.id, "Transport", CategoryType.EXPENSE, "directions_car", "#2196F3")
            )

            val result = service.getWeeklyReport(user1.id, 2026, 3, 1)

            Then("returns correct weekly report") {
                result.yearMonth shouldBe "2026-03"
                result.weekNumber shouldBe 1
                result.weekStart shouldBe "2026-03-01"
                result.weekEnd shouldBe "2026-03-07"
                result.totalSpent shouldBe 100000 // 50000+30000+20000
                // Weekly budget: foodCategory budget 500000 / 5 weeks = 100000
                result.totalBudget shouldBe 100000
                result.remainingAmount shouldBe 0
                result.usageRate shouldBe 100.0
            }

            Then("returns category spending with deviation") {
                result.topOverspendCategories shouldHaveSize 2
                // Food: amount=80000, avg=200000/4=50000, deviation=30000
                val foodItem = result.topOverspendCategories[0]
                foodItem.category!!.name shouldBe "Meals"
                foodItem.amount shouldBe 80000
                foodItem.averageAmount shouldBe 50000
                foodItem.deviation shouldBe 30000
            }

            Then("returns daily spending for 7 days") {
                result.dailySpending shouldHaveSize 7
                // March 1 (Sunday) has tx3=20000
                result.dailySpending[0].date shouldBe "2026-03-01"
                result.dailySpending[0].dayOfWeek shouldBe "SUN"
                result.dailySpending[0].amount shouldBe 20000
                result.dailySpending[0].transactionCount shouldBe 1

                // March 2 (Monday) has tx1=50000
                result.dailySpending[1].date shouldBe "2026-03-02"
                result.dailySpending[1].dayOfWeek shouldBe "MON"
                result.dailySpending[1].amount shouldBe 50000

                // March 4 (Wednesday) has tx2=30000
                result.dailySpending[3].date shouldBe "2026-03-04"
                result.dailySpending[3].amount shouldBe 30000
            }

            Then("identifies peak spending day") {
                result.peakSpendingDay shouldBe "MON"
            }
        }

        When("requesting a week with no transactions") {
            every {
                transactionRepository.findByCoupleIdAndFilters(
                    coupleId = couple.id,
                    startDate = LocalDate.of(2026, 3, 8),
                    endDate = LocalDate.of(2026, 3, 14),
                    type = TransactionType.EXPENSE,
                    categoryId = null,
                    pageable = any()
                )
            } returns PageImpl(emptyList())

            every { categoryGroupRepository.findByCoupleId(couple.id) } returns emptyList()
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-03") } returns emptyList()

            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 8),
                    LocalDate.of(2026, 3, 14),
                    TransactionType.EXPENSE
                )
            } returns emptyList()

            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 2, 8),
                    LocalDate.of(2026, 3, 7),
                    TransactionType.EXPENSE
                )
            } returns emptyList()

            // Use a past month to avoid IN_PROGRESS status from today's date
            every {
                transactionRepository.findByCoupleIdAndFilters(
                    coupleId = couple.id,
                    startDate = LocalDate.of(2026, 1, 8),
                    endDate = LocalDate.of(2026, 1, 14),
                    type = TransactionType.EXPENSE,
                    categoryId = null,
                    pageable = any()
                )
            } returns PageImpl(emptyList())

            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-01") } returns emptyList()

            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 1, 8),
                    LocalDate.of(2026, 1, 14),
                    TransactionType.EXPENSE
                )
            } returns emptyList()

            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2025, 12, 11),
                    LocalDate.of(2026, 1, 7),
                    TransactionType.EXPENSE
                )
            } returns emptyList()

            val result = service.getWeeklyReport(user1.id, 2026, 1, 2)

            Then("returns zero amounts and UNDER status") {
                result.totalSpent shouldBe 0
                result.totalBudget shouldBe 0
                result.status shouldBe "UNDER"
                result.topOverspendCategories shouldHaveSize 0
                result.peakSpendingDay.shouldBeNull()
            }
        }
    }

    Given("a user NOT in a couple for weekly report") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("requesting weekly report") {
            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    service.getWeeklyReport(user1.id, 2026, 3, 1)
                }.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    // --- getMonthlyReport ---

    Given("a user in an active couple for monthly report") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("requesting March 2026 monthly report") {
            // Income/expense totals
            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31)
                )
            } returns listOf(
                arrayOf(TransactionType.INCOME, 5000000L, 10L),
                arrayOf(TransactionType.EXPENSE, 3200000L, 35L)
            )

            // Group summaries setup
            every { categoryGroupRepository.findByCoupleId(couple.id) } returns listOf(foodGroup, monthlyGroup)
            every { categoryRepository.findByCoupleIdAndGroupId(couple.id, foodGroup.id) } returns listOf(foodCategory)
            every { categoryRepository.findByCoupleIdAndGroupId(couple.id, monthlyGroup.id) } returns listOf(transportCategory)

            val foodBudget = MonthlyBudget(couple = couple, category = foodCategory, yearMonth = "2026-03", amount = 500000)
            val transportBudget = MonthlyBudget(couple = couple, category = transportCategory, yearMonth = "2026-03", amount = 200000)
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-03") } returns listOf(foodBudget, transportBudget)

            // Category expenses for group summaries + top categories
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    TransactionType.EXPENSE
                )
            } returns listOf(
                arrayOf(800000L, 12L, foodCategory.id, "Meals", CategoryType.EXPENSE, "restaurant", "#FF5733"),
                arrayOf(320000L, 8L, transportCategory.id, "Transport", CategoryType.EXPENSE, "directions_car", "#2196F3")
            )

            // Previous month comparison (February)
            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id,
                    LocalDate.of(2026, 2, 1),
                    LocalDate.of(2026, 2, 28)
                )
            } returns listOf(
                arrayOf(TransactionType.INCOME, 4000000L, 8L),
                arrayOf(TransactionType.EXPENSE, 2800000L, 30L)
            )

            // Previous month categories for top categories comparison
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 2, 1),
                    LocalDate.of(2026, 2, 28),
                    TransactionType.EXPENSE
                )
            } returns listOf(
                arrayOf(600000L, 10L, foodCategory.id, "Meals", CategoryType.EXPENSE, "restaurant", "#FF5733"),
                arrayOf(280000L, 6L, transportCategory.id, "Transport", CategoryType.EXPENSE, "directions_car", "#2196F3")
            )

            // Card pending summary (single grouped query)
            val creditCardId = UUID.randomUUID()
            every {
                transactionRepository.sumBySettlementDateGroupedByPaymentMethod(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31)
                )
            } returns listOf(arrayOf(creditCardId, 150000L))

            // Day of week pattern needs expense transactions for the month
            val expenseTx = Transaction(
                couple = couple, author = user1, category = foodCategory,
                type = TransactionType.EXPENSE, amount = 150000, description = "Expense",
                transactionDate = LocalDate.of(2026, 3, 15)
            )
            every {
                transactionRepository.findByCoupleIdAndFilters(
                    coupleId = couple.id,
                    startDate = LocalDate.of(2026, 3, 1),
                    endDate = LocalDate.of(2026, 3, 31),
                    type = TransactionType.EXPENSE,
                    categoryId = null,
                    pageable = any()
                )
            } returns PageImpl(listOf(expenseTx))

            val result = service.getMonthlyReport(user1.id, 2026, 3)

            Then("returns correct income, expense, balance") {
                result.yearMonth shouldBe "2026-03"
                result.totalIncome shouldBe 5000000
                result.totalExpense shouldBe 3200000
                result.balance shouldBe 1800000
            }

            Then("returns group summaries") {
                result.groupSummaries shouldHaveSize 2
                val foodGroupSummary = result.groupSummaries.find { it.groupName == "Food" }
                foodGroupSummary.shouldNotBeNull()
                foodGroupSummary.totalBudget shouldBe 500000
                foodGroupSummary.totalSpent shouldBe 800000
                foodGroupSummary.budgetType shouldBe "WEEKLY"
                foodGroupSummary.usageRate shouldBe 160.0
            }

            Then("returns top categories with deviation from previous month") {
                result.topCategories shouldHaveSize 2
                result.topCategories[0].category!!.name shouldBe "Meals"
                result.topCategories[0].amount shouldBe 800000
                result.topCategories[0].averageAmount shouldBe 600000
                result.topCategories[0].deviation shouldBe 200000
            }

            Then("returns previous month comparison") {
                val comparison = result.previousMonthComparison
                comparison.shouldNotBeNull()
                comparison.previousYearMonth shouldBe "2026-02"
                comparison.incomeChange shouldBe 1000000
                comparison.expenseChange shouldBe 400000
                comparison.incomeChangeRate shouldBe 25.0
                comparison.expenseChangeRate shouldBe 14.3
            }

            Then("returns card pending summary") {
                val pending = result.cardPendingSummary
                pending.shouldNotBeNull()
                pending.totalPendingAmount shouldBe 150000
                pending.cardCount shouldBe 1
            }

            Then("returns day of week pattern") {
                result.dayOfWeekPattern shouldHaveSize 7
                // The single unsettled transaction is on March 15 (Sunday)
                val sunPattern = result.dayOfWeekPattern.find { it.dayOfWeek == "SUN" }
                sunPattern.shouldNotBeNull()
                sunPattern.totalSpending shouldBe 150000
                sunPattern.transactionCount shouldBe 1
            }
        }

        When("there is no previous month data") {
            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id,
                    LocalDate.of(2026, 1, 1),
                    LocalDate.of(2026, 1, 31)
                )
            } returns listOf(
                arrayOf(TransactionType.INCOME, 3000000L, 5L),
                arrayOf(TransactionType.EXPENSE, 1000000L, 10L)
            )

            every { categoryGroupRepository.findByCoupleId(couple.id) } returns emptyList()
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-01") } returns emptyList()

            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 1, 1),
                    LocalDate.of(2026, 1, 31),
                    TransactionType.EXPENSE
                )
            } returns emptyList()

            // No previous month
            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id,
                    LocalDate.of(2025, 12, 1),
                    LocalDate.of(2025, 12, 31)
                )
            } returns emptyList()

            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2025, 12, 1),
                    LocalDate.of(2025, 12, 31),
                    TransactionType.EXPENSE
                )
            } returns emptyList()

            every {
                transactionRepository.sumBySettlementDateGroupedByPaymentMethod(
                    couple.id,
                    LocalDate.of(2026, 1, 1),
                    LocalDate.of(2026, 1, 31)
                )
            } returns emptyList()

            every {
                transactionRepository.findByCoupleIdAndFilters(
                    coupleId = couple.id,
                    startDate = LocalDate.of(2026, 1, 1),
                    endDate = LocalDate.of(2026, 1, 31),
                    type = TransactionType.EXPENSE,
                    categoryId = null,
                    pageable = any()
                )
            } returns PageImpl(emptyList())

            val result = service.getMonthlyReport(user1.id, 2026, 1)

            Then("previousMonthComparison is null when no prior data") {
                result.previousMonthComparison.shouldBeNull()
            }

            Then("cardPendingSummary is null when no credit cards") {
                result.cardPendingSummary.shouldBeNull()
            }
        }
    }

    Given("a user NOT in a couple for monthly report") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("requesting monthly report") {
            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    service.getMonthlyReport(user1.id, 2026, 3)
                }.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    // --- calculateWeekRange ---

    Given("week range calculation") {
        When("calculating week ranges for a 31-day month") {
            val ym = java.time.YearMonth.of(2026, 3)

            Then("week 1 is days 1-7") {
                val (start, end) = service.calculateWeekRange(ym, 1)
                start shouldBe LocalDate.of(2026, 3, 1)
                end shouldBe LocalDate.of(2026, 3, 7)
            }

            Then("week 4 is days 22-28") {
                val (start, end) = service.calculateWeekRange(ym, 4)
                start shouldBe LocalDate.of(2026, 3, 22)
                end shouldBe LocalDate.of(2026, 3, 28)
            }

            Then("week 5 is days 29-31") {
                val (start, end) = service.calculateWeekRange(ym, 5)
                start shouldBe LocalDate.of(2026, 3, 29)
                end shouldBe LocalDate.of(2026, 3, 31)
            }
        }

        When("calculating week ranges for February (28 days)") {
            val ym = java.time.YearMonth.of(2026, 2)

            Then("week 4 is days 22-28") {
                val (start, end) = service.calculateWeekRange(ym, 4)
                start shouldBe LocalDate.of(2026, 2, 22)
                end shouldBe LocalDate.of(2026, 2, 28)
            }

            Then("week 5 collapses to last day") {
                val (start, end) = service.calculateWeekRange(ym, 5)
                start shouldBe LocalDate.of(2026, 2, 28)
                end shouldBe LocalDate.of(2026, 2, 28)
            }
        }
    }

    // --- getWeeksInMonth ---

    Given("weeks in month calculation") {
        When("month has 28 days") {
            Then("returns 4 weeks") {
                service.getWeeksInMonth(java.time.YearMonth.of(2026, 2)) shouldBe 4
            }
        }

        When("month has 31 days") {
            Then("returns 5 weeks") {
                service.getWeeksInMonth(java.time.YearMonth.of(2026, 3)) shouldBe 5
            }
        }

        When("month has 30 days") {
            Then("returns 5 weeks") {
                service.getWeeksInMonth(java.time.YearMonth.of(2026, 4)) shouldBe 5
            }
        }
    }
})
