package com.budgetbook.statistics.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

class StatisticsServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val service = StatisticsService(transactionRepository, coupleRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    // --- getMonthlySummary ---

    Given("a user in an active couple for monthly summary") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("there are income and expense transactions") {
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

            val result = service.getMonthlySummary(user1.id, 2026, 3)

            Then("returns correct summary") {
                result.yearMonth shouldBe "2026-03"
                result.totalIncome shouldBe 5000000L
                result.totalExpense shouldBe 3200000L
                result.balance shouldBe 1800000L
                result.transactionCount shouldBe 45
            }
        }

        When("there are no transactions") {
            every {
                transactionRepository.sumByTypeForCouple(
                    couple.id,
                    LocalDate.of(2026, 1, 1),
                    LocalDate.of(2026, 1, 31)
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
    }

    Given("a user NOT in a couple for monthly summary") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

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
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val catId1 = UUID.randomUUID()
        val catId2 = UUID.randomUUID()

        When("there are expense transactions by category") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    TransactionType.EXPENSE
                )
            } returns listOf(
                arrayOf(800000L, 12L, catId1, "식비", com.budgetbook.category.domain.CategoryType.EXPENSE, "restaurant", "#FF5733"),
                arrayOf(320000L, 8L, catId2, "교통비", com.budgetbook.category.domain.CategoryType.EXPENSE, "directions_car", "#2196F3")
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

        When("type is null, defaults to EXPENSE") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    TransactionType.EXPENSE
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
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("requesting 3 months of trend data") {
            val now = YearMonth.now()
            val startMonth = now.minusMonths(2)

            every {
                transactionRepository.monthlyTrendForCouple(
                    couple.id,
                    startMonth.atDay(1),
                    now.atEndOfMonth()
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

        When("months parameter exceeds max") {
            val now = YearMonth.now()
            val startMonth = now.minusMonths(23)

            every {
                transactionRepository.monthlyTrendForCouple(
                    couple.id,
                    startMonth.atDay(1),
                    now.atEndOfMonth()
                )
            } returns emptyList()

            val result = service.getMonthlyTrend(user1.id, 100)

            Then("is clamped to 24 months") {
                result shouldHaveSize 24
            }
        }
    }
})
