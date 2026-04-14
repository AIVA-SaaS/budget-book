package com.budgetbook.statistics.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.spendingplan.repository.SpendingPlanRepository
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.repository.TransferRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

class StatisticsServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val transferRepository = mockk<TransferRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val budgetRepository = mockk<MonthlyBudgetRepository>()
    val spendingPlanRepository = mockk<SpendingPlanRepository>()
    val service = StatisticsService(transactionRepository, transferRepository, coupleResolver, budgetRepository, spendingPlanRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    // Default: no transfers (individual tests can override)
    every { transferRepository.sumAmountBySourceForCoupleAndPeriod(any(), any(), any()) } returns emptyList()
    every { transferRepository.sumAmountByDestinationForCoupleAndPeriod(any(), any(), any()) } returns emptyList()

    // --- getMonthlySummary ---

    Given("a user in an active couple for monthly summary") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("there are income and expense transactions with default visibility") {
            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    any(),
                    "ALL"
                )
            } returns listOf(
                arrayOf(TransactionType.INCOME, 5000000L, 10L),
                arrayOf(TransactionType.EXPENSE, 3200000L, 35L)
            )

            val result = service.getMonthlySummary(user1.id, 2026, 3)

            Then("returns correct summary") {
                result.yearMonth shouldBe "2026-03"
                result.totalIncome shouldBe 5000000L
                result.totalExpense shouldBe 3200000L
                result.balance shouldBe 1800000L
                result.transactionCount shouldBe 45
            }
        }

        When("visibility is SHARED") {
            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    any(),
                    "SHARED"
                )
            } returns listOf(
                arrayOf(TransactionType.INCOME, 3000000L, 6L),
                arrayOf(TransactionType.EXPENSE, 2000000L, 20L)
            )

            val result = service.getMonthlySummary(user1.id, 2026, 3, "SHARED")

            Then("returns shared-only summary") {
                result.totalIncome shouldBe 3000000L
                result.totalExpense shouldBe 2000000L
                result.transactionCount shouldBe 26
            }

            Then("passes SHARED to repository") {
                verify {
                    transactionRepository.sumByTypeForCouple(
                        couple.id, any(), any(), any(), "SHARED"
                    )
                }
            }
        }

        When("visibility is PRIVATE") {
            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    any(),
                    "PRIVATE"
                )
            } returns listOf(
                arrayOf(TransactionType.EXPENSE, 500000L, 5L)
            )

            val result = service.getMonthlySummary(user1.id, 2026, 3, "PRIVATE")

            Then("returns private-only summary") {
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 500000L
                result.transactionCount shouldBe 5
            }
        }

        When("there are no transactions") {
            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id,
                    LocalDate.of(2026, 1, 1),
                    LocalDate.of(2026, 1, 31),
                    any(),
                    "ALL"
                )
            } returns emptyList()

            val result = service.getMonthlySummary(user1.id, 2026, 1)

            Then("returns zero values") {
                result.yearMonth shouldBe "2026-01"
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 0L
                result.balance shouldBe 0L
                result.transactionCount shouldBe 0
            }
        }

        When("invalid visibility is provided") {
            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    service.getMonthlySummary(user1.id, 2026, 3, "INVALID")
                }.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("a user NOT in a couple for monthly summary") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("requesting summary") {
            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    service.getMonthlySummary(user1.id, 2026, 3)
                }.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    // --- getCategoryBreakdown ---

    Given("a user in an active couple for category breakdown") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val catId1 = UUID.randomUUID()
        val catId2 = UUID.randomUUID()

        When("there are expense transactions by category with default visibility") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    TransactionType.EXPENSE,
                    any(),
                    "ALL"
                )
            } returns listOf(
                arrayOf<Any?>(800000L, 12L, catId1, "식비", com.budgetbook.category.domain.CategoryType.EXPENSE, "restaurant", "#FF5733", null, null),
                arrayOf<Any?>(320000L, 8L, catId2, "교통비", com.budgetbook.category.domain.CategoryType.EXPENSE, "directions_car", "#2196F3", null, null)
            )

            val result = service.getCategoryBreakdown(user1.id, 2026, 3, "EXPENSE")

            Then("returns category statistics sorted by amount DESC") {
                result shouldHaveSize 2
                result[0].category.name shouldBe "식비"
                result[0].amount shouldBe 800000L
                result[0].percentage shouldBe 71.4
                result[0].transactionCount shouldBe 12
                result[1].category.name shouldBe "교통비"
                result[1].amount shouldBe 320000L
                result[1].transactionCount shouldBe 8
            }
        }

        When("visibility is SHARED for category breakdown") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    TransactionType.EXPENSE,
                    any(),
                    "SHARED"
                )
            } returns listOf(
                arrayOf<Any?>(600000L, 8L, catId1, "식비", com.budgetbook.category.domain.CategoryType.EXPENSE, "restaurant", "#FF5733", null, null)
            )

            val result = service.getCategoryBreakdown(user1.id, 2026, 3, "EXPENSE", "SHARED")

            Then("returns shared-only category breakdown") {
                result shouldHaveSize 1
                result[0].amount shouldBe 600000L
            }

            Then("passes SHARED to repository") {
                verify {
                    transactionRepository.sumByCategoryForCouple(
                        couple.id, any(), any(), TransactionType.EXPENSE, any(), "SHARED"
                    )
                }
            }
        }

        When("type is null, defaults to EXPENSE") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    TransactionType.EXPENSE,
                    any(),
                    "ALL"
                )
            } returns emptyList()

            val result = service.getCategoryBreakdown(user1.id, 2026, 3, null)

            Then("returns empty list") {
                result shouldHaveSize 0
            }
        }

        When("invalid type is provided") {
            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    service.getCategoryBreakdown(user1.id, 2026, 3, "INVALID")
                }.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- getMonthlyTrend ---

    Given("a user in an active couple for monthly trend") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("requesting 3 months of trend data with default visibility") {
            val now = YearMonth.now()
            val startMonth = now.minusMonths(2)

            every {
                transactionRepository.monthlyTrendForCouple(
                    couple.id,
                    startMonth.atDay(1),
                    now.atEndOfMonth(),
                    any(),
                    "ALL"
                )
            } returns listOf(
                arrayOf(startMonth.toString(), "INCOME", 4000000L),
                arrayOf(startMonth.toString(), "EXPENSE", 3000000L),
                arrayOf(now.toString(), "INCOME", 5000000L),
                arrayOf(now.toString(), "EXPENSE", 3200000L)
            )

            val result = service.getMonthlyTrend(user1.id, 3)

            Then("returns 3 months with zeros for missing month") {
                result shouldHaveSize 3
                result[0].yearMonth shouldBe startMonth.toString()
                result[0].totalIncome shouldBe 4000000L
                result[0].totalExpense shouldBe 3000000L
                result[0].balance shouldBe 1000000L

                // Middle month has no data
                result[1].totalIncome shouldBe 0L
                result[1].totalExpense shouldBe 0L
                result[1].balance shouldBe 0L

                result[2].yearMonth shouldBe now.toString()
                result[2].totalIncome shouldBe 5000000L
                result[2].totalExpense shouldBe 3200000L
                result[2].balance shouldBe 1800000L
            }
        }

        When("requesting trend with SHARED visibility") {
            val now = YearMonth.now()
            val startMonth = now.minusMonths(2)

            every {
                transactionRepository.monthlyTrendForCouple(
                    couple.id,
                    startMonth.atDay(1),
                    now.atEndOfMonth(),
                    any(),
                    "SHARED"
                )
            } returns listOf(
                arrayOf(now.toString(), "INCOME", 2000000L),
                arrayOf(now.toString(), "EXPENSE", 1000000L)
            )

            val result = service.getMonthlyTrend(user1.id, 3, "SHARED")

            Then("returns trend data filtered by SHARED") {
                result shouldHaveSize 3
                result[2].totalIncome shouldBe 2000000L
                result[2].totalExpense shouldBe 1000000L
            }

            Then("passes SHARED to repository") {
                verify {
                    transactionRepository.monthlyTrendForCouple(
                        couple.id, any(), any(), any(), "SHARED"
                    )
                }
            }
        }

        When("months parameter exceeds max") {
            val now = YearMonth.now()
            val startMonth = now.minusMonths(23)

            every {
                transactionRepository.monthlyTrendForCouple(
                    couple.id,
                    startMonth.atDay(1),
                    now.atEndOfMonth(),
                    any(),
                    "ALL"
                )
            } returns emptyList()

            val result = service.getMonthlyTrend(user1.id, 100)

            Then("is clamped to 24 months") {
                result shouldHaveSize 24
            }
        }

        When("invalid visibility is provided for trend") {
            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    service.getMonthlyTrend(user1.id, 3, "INVALID")
                }.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- getMonthlySummary with dateFrom/dateTo (C-11) ---

    Given("a user requesting summary with custom date range") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("dateFrom and dateTo are provided") {
            val customStart = LocalDate.of(2026, 3, 10)
            val customEnd = LocalDate.of(2026, 3, 20)

            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id, customStart, customEnd, any(), "ALL"
                )
            } returns listOf(
                arrayOf(TransactionType.EXPENSE, 500000L, 5L)
            )

            val result = service.getMonthlySummary(user1.id, 2026, 3, "ALL", customStart, customEnd)

            Then("uses the custom date range instead of full month") {
                result.totalExpense shouldBe 500000L
                result.transactionCount shouldBe 5
            }
        }

        When("only dateFrom is provided, dateTo defaults to end of month") {
            val customStart = LocalDate.of(2026, 3, 15)
            val monthEnd = LocalDate.of(2026, 3, 31)

            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id, customStart, monthEnd, any(), "ALL"
                )
            } returns listOf(
                arrayOf(TransactionType.INCOME, 300000L, 3L)
            )

            val result = service.getMonthlySummary(user1.id, 2026, 3, "ALL", customStart, null)

            Then("uses dateFrom with month end as dateTo") {
                result.totalIncome shouldBe 300000L
            }
        }
    }

    // --- getCategoryBreakdown with dateFrom/dateTo (C-11) ---

    Given("a user requesting category breakdown with custom date range") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val catId = UUID.randomUUID()
        val customStart = LocalDate.of(2026, 3, 1)
        val customEnd = LocalDate.of(2026, 3, 15)

        When("dateFrom and dateTo are provided") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id, customStart, customEnd, TransactionType.EXPENSE, any(), "ALL"
                )
            } returns listOf(
                arrayOf<Any?>(200000L, 4L, catId, "식비", com.budgetbook.category.domain.CategoryType.EXPENSE, "restaurant", "#FF5733", null, null)
            )

            val result = service.getCategoryBreakdown(user1.id, 2026, 3, "EXPENSE", "ALL", customStart, customEnd)

            Then("uses the custom date range") {
                result shouldHaveSize 1
                result[0].amount shouldBe 200000L
                result[0].transactionCount shouldBe 4
            }
        }
    }

    // --- getPeriodSummary ---

    Given("a user in an active couple for period summary") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val dateFrom = LocalDate.of(2026, 3, 1)
        val dateTo = LocalDate.of(2026, 3, 31)
        val catId1 = UUID.randomUUID()
        val catId2 = UUID.randomUUID()

        When("requesting period summary with data") {
            // sumByTypeForCouple
            every {
                transactionRepository.sumByTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns listOf(
                arrayOf(TransactionType.INCOME, 5000000L, 10L),
                arrayOf(TransactionType.EXPENSE, 3200000L, 35L)
            )

            // sumByCategoryForCouple
            every {
                transactionRepository.sumByCategoryForCouple(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, any(), "ALL")
            } returns listOf(
                arrayOf<Any?>(2000000L, 15L, catId1, "식비", com.budgetbook.category.domain.CategoryType.EXPENSE, "restaurant", "#FF5733", null, null),
                arrayOf<Any?>(1200000L, 20L, catId2, "교통비", com.budgetbook.category.domain.CategoryType.EXPENSE, "directions_car", "#2196F3", null, null)
            )

            // budgets
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()

            // sumAmountByCoupleIdAndDateRange (total spent)
            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 3200000L

            // spending plan
            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id) } returns 0L

            // byPaymentMethod
            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            // dailySummary
            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns listOf(
                arrayOf<Any>(java.sql.Date.valueOf(dateFrom), "INCOME", 2000000L, 3L),
                arrayOf<Any>(java.sql.Date.valueOf(dateFrom), "EXPENSE", 1000000L, 10L),
                arrayOf<Any>(java.sql.Date.valueOf(LocalDate.of(2026, 3, 15)), "EXPENSE", 2200000L, 25L)
            )

            val result = service.getPeriodSummary(user1.id, dateFrom, dateTo)

            Then("returns correct totals") {
                result.dateFrom shouldBe "2026-03-01"
                result.dateTo shouldBe "2026-03-31"
                result.totalIncome shouldBe 5000000L
                result.totalExpense shouldBe 3200000L
                result.balance shouldBe 1800000L
            }

            Then("returns category breakdown with percentages") {
                result.byCategory shouldHaveSize 2
                result.byCategory[0].categoryName shouldBe "식비"
                result.byCategory[0].amount shouldBe 2000000L
                result.byCategory[0].percentage shouldBe 62.5
                result.byCategory[1].categoryName shouldBe "교통비"
                result.byCategory[1].amount shouldBe 1200000L
                result.byCategory[1].percentage shouldBe 37.5
            }

            Then("returns daily spending") {
                result.byDate shouldHaveSize 2
                result.byDate[0].date shouldBe "2026-03-01"
                result.byDate[0].income shouldBe 2000000L
                result.byDate[0].expense shouldBe 1000000L
                result.byDate[1].date shouldBe "2026-03-15"
                result.byDate[1].income shouldBe 0L
                result.byDate[1].expense shouldBe 2200000L
            }
        }

        When("requesting period summary with no data") {
            every {
                transactionRepository.sumByTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            every {
                transactionRepository.sumByCategoryForCouple(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, any(), "ALL")
            } returns emptyList()

            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()

            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 0L

            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id) } returns 0L

            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            val result = service.getPeriodSummary(user1.id, dateFrom, dateTo)

            Then("returns zero values") {
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 0L
                result.balance shouldBe 0L
                result.byCategory shouldHaveSize 0
                result.byBudget shouldHaveSize 0
                result.byPaymentMethod shouldHaveSize 0
                result.byDate shouldHaveSize 0
            }
        }

        When("invalid visibility is provided for period summary") {
            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    service.getPeriodSummary(user1.id, dateFrom, dateTo, "INVALID")
                }.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- getPeriodSummary: Transfer inclusion (matching getMonthlySummary behavior) ---

    Given("a user for period summary with transfers") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val dateFrom = LocalDate.of(2026, 3, 1)
        val dateTo = LocalDate.of(2026, 3, 31)

        When("transfers exist in the period") {
            // Transaction totals
            every {
                transactionRepository.sumByTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns listOf(
                arrayOf(TransactionType.INCOME, 5000000L, 10L),
                arrayOf(TransactionType.EXPENSE, 3000000L, 30L)
            )
            every {
                transactionRepository.sumByCategoryForCouple(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, any(), "ALL")
            } returns emptyList()
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()
            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 3000000L
            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id) } returns 0L
            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()
            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            // Transfer amounts: 200000 out (expense), 100000 in (income)
            val pmId = UUID.randomUUID()
            every {
                transferRepository.sumAmountBySourceForCoupleAndPeriod(couple.id, dateFrom, dateTo)
            } returns listOf(arrayOf<Any>(pmId, 200000L))
            every {
                transferRepository.sumAmountByDestinationForCoupleAndPeriod(couple.id, dateFrom, dateTo)
            } returns listOf(arrayOf<Any>(pmId, 100000L))

            val result = service.getPeriodSummary(user1.id, dateFrom, dateTo)

            Then("totalExpense includes transfer out amounts") {
                result.totalExpense shouldBe 3200000L // 3000000 + 200000
            }

            Then("totalIncome includes transfer in amounts") {
                result.totalIncome shouldBe 5100000L // 5000000 + 100000
            }

            Then("balance reflects transfer-adjusted totals") {
                result.balance shouldBe 1900000L // 5100000 - 3200000
            }
        }
    }

    // --- getPeriodSummary: summary vs period-summary consistency ---

    Given("consistency between getMonthlySummary and getPeriodSummary") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val dateFrom = LocalDate.of(2026, 4, 1)
        val dateTo = LocalDate.of(2026, 4, 30)
        val pmId = UUID.randomUUID()

        When("same period data is queried via both endpoints") {
            // Same transaction data for both
            every {
                transactionRepository.sumByTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns listOf(
                arrayOf(TransactionType.INCOME, 4000000L, 8L),
                arrayOf(TransactionType.EXPENSE, 2500000L, 20L)
            )

            // Transfers
            every {
                transferRepository.sumAmountBySourceForCoupleAndPeriod(couple.id, dateFrom, dateTo)
            } returns listOf(arrayOf<Any>(pmId, 300000L))
            every {
                transferRepository.sumAmountByDestinationForCoupleAndPeriod(couple.id, dateFrom, dateTo)
            } returns listOf(arrayOf<Any>(pmId, 150000L))

            // Additional mocks for getPeriodSummary
            every {
                transactionRepository.sumByCategoryForCouple(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, any(), "ALL")
            } returns emptyList()
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-04", user1.id) } returns emptyList()
            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 2500000L
            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id) } returns 0L
            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()
            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            val summaryResult = service.getMonthlySummary(user1.id, 2026, 4, "ALL", dateFrom, dateTo)
            val periodResult = service.getPeriodSummary(user1.id, dateFrom, dateTo)

            Then("totalIncome matches between summary and period-summary") {
                periodResult.totalIncome shouldBe summaryResult.totalIncome
            }

            Then("totalExpense matches between summary and period-summary") {
                periodResult.totalExpense shouldBe summaryResult.totalExpense
            }

            Then("balance matches between summary and period-summary") {
                periodResult.balance shouldBe summaryResult.balance
            }
        }
    }

    // --- getPeriodSummary: filters applied ---

    Given("a user for period summary with filters") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val dateFrom = LocalDate.of(2026, 3, 1)
        val dateTo = LocalDate.of(2026, 3, 31)
        val filterCategoryId = UUID.randomUUID()

        When("categoryId filter is applied") {
            // When filters are active, findAll(spec) is used instead of sumByType
            every {
                transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<com.budgetbook.transaction.domain.Transaction>>())
            } returns emptyList()

            // Budget/plan/daily/pm mocks
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()
            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 0L
            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id) } returns 0L
            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()
            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            val result = service.getPeriodSummary(
                user1.id, dateFrom, dateTo, "ALL",
                categoryId = filterCategoryId
            )

            Then("uses Specifications-based query (returns filtered data)") {
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 0L
            }

            Then("transfers are NOT included when filters are active") {
                // Verify transfer repos were NOT called
                verify(exactly = 0) {
                    transferRepository.sumAmountBySourceForCoupleAndPeriod(any(), any(), any())
                }
                verify(exactly = 0) {
                    transferRepository.sumAmountByDestinationForCoupleAndPeriod(any(), any(), any())
                }
            }
        }
    }
})
