package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
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
import java.util.UUID

class BudgetAlertServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val budgetRepository = mockk<MonthlyBudgetRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val service = BudgetAlertService(budgetRepository, transactionRepository, coupleResolver)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    val foodCategory = Category(couple = couple, name = "Food", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF0000")
    val transportCategory = Category(couple = couple, name = "Transport", type = CategoryType.EXPENSE, icon = "car", color = "#0000FF")
    val entertainmentCategory = Category(couple = couple, name = "Entertainment", type = CategoryType.EXPENSE, icon = "movie", color = "#00FF00")

    Given("budgets with varying spending levels") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val foodBudget = MonthlyBudget(couple = couple, category = foodCategory, yearMonth = "2026-03", amount = 500000)
        val transportBudget = MonthlyBudget(couple = couple, category = transportCategory, yearMonth = "2026-03", amount = 200000)
        val entertainmentBudget = MonthlyBudget(couple = couple, category = entertainmentCategory, yearMonth = "2026-03", amount = 100000)

        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns
            listOf(foodBudget, transportBudget, entertainmentBudget)

        // Food: 450000/500000 = 90% -> WARNING
        // Transport: 210000/200000 = 105% -> EXCEEDED
        // Entertainment: 50000/100000 = 50% -> SAFE (excluded)
        every {
            transactionRepository.sumByCategoryForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns listOf(
            arrayOf(450000L, 15L, foodCategory.id, "Food", CategoryType.EXPENSE, "restaurant", "#FF0000"),
            arrayOf(210000L, 8L, transportCategory.id, "Transport", CategoryType.EXPENSE, "car", "#0000FF"),
            arrayOf(50000L, 3L, entertainmentCategory.id, "Entertainment", CategoryType.EXPENSE, "movie", "#00FF00")
        )

        every {
            transactionRepository.sumAmountByCoupleIdAndDateRange(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns 710000L

        When("getBudgetAlerts is called") {
            val result = service.getBudgetAlerts(user1.id, "2026-03")

            Then("returns only WARNING and EXCEEDED alerts") {
                result shouldHaveSize 2
            }

            Then("food budget shows WARNING") {
                val foodAlert = result.find { it.categoryName == "Food" }!!
                foodAlert.budgetAmount shouldBe 500000
                foodAlert.spentAmount shouldBe 450000
                foodAlert.percentage shouldBe 90
                foodAlert.alertLevel shouldBe "WARNING"
            }

            Then("transport budget shows EXCEEDED") {
                val transportAlert = result.find { it.categoryName == "Transport" }!!
                transportAlert.budgetAmount shouldBe 200000
                transportAlert.spentAmount shouldBe 210000
                transportAlert.percentage shouldBe 105
                transportAlert.alertLevel shouldBe "EXCEEDED"
            }
        }
    }

    Given("all budgets are under 80%") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget = MonthlyBudget(couple = couple, category = foodCategory, yearMonth = "2026-03", amount = 500000)

        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(budget)

        every {
            transactionRepository.sumByCategoryForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns listOf(
            arrayOf(200000L, 5L, foodCategory.id, "Food", CategoryType.EXPENSE, "restaurant", "#FF0000")
        )

        every {
            transactionRepository.sumAmountByCoupleIdAndDateRange(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns 200000L

        When("getBudgetAlerts is called") {
            val result = service.getBudgetAlerts(user1.id, "2026-03")

            Then("returns empty list") {
                result shouldHaveSize 0
            }
        }
    }

    Given("no budgets for the month") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()

        When("getBudgetAlerts is called") {
            val result = service.getBudgetAlerts(user1.id, "2026-03")

            Then("returns empty list") {
                result shouldHaveSize 0
            }
        }
    }

    Given("a total budget (no category) that is exceeded") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val totalBudget = MonthlyBudget(couple = couple, category = null, yearMonth = "2026-03", amount = 1000000)

        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(totalBudget)

        every {
            transactionRepository.sumByCategoryForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns emptyList()

        every {
            transactionRepository.sumAmountByCoupleIdAndDateRange(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns 1100000L

        When("getBudgetAlerts is called") {
            val result = service.getBudgetAlerts(user1.id, "2026-03")

            Then("returns EXCEEDED alert for total budget") {
                result shouldHaveSize 1
                result[0].categoryName shouldBe "Total"
                result[0].categoryId shouldBe ""
                result[0].percentage shouldBe 110
                result[0].alertLevel shouldBe "EXCEEDED"
            }
        }
    }

    Given("a budget at exactly 80%") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget = MonthlyBudget(couple = couple, category = foodCategory, yearMonth = "2026-03", amount = 100000)

        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(budget)

        every {
            transactionRepository.sumByCategoryForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns listOf(
            arrayOf(80000L, 5L, foodCategory.id, "Food", CategoryType.EXPENSE, "restaurant", "#FF0000")
        )

        every {
            transactionRepository.sumAmountByCoupleIdAndDateRange(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns 80000L

        When("getBudgetAlerts is called") {
            val result = service.getBudgetAlerts(user1.id, "2026-03")

            Then("returns WARNING (80% is the threshold)") {
                result shouldHaveSize 1
                result[0].percentage shouldBe 80
                result[0].alertLevel shouldBe "WARNING"
            }
        }
    }

    Given("a budget at exactly 100%") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget = MonthlyBudget(couple = couple, category = foodCategory, yearMonth = "2026-03", amount = 100000)

        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(budget)

        every {
            transactionRepository.sumByCategoryForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns listOf(
            arrayOf(100000L, 10L, foodCategory.id, "Food", CategoryType.EXPENSE, "restaurant", "#FF0000")
        )

        every {
            transactionRepository.sumAmountByCoupleIdAndDateRange(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns 100000L

        When("getBudgetAlerts is called") {
            val result = service.getBudgetAlerts(user1.id, "2026-03")

            Then("returns EXCEEDED (100% threshold)") {
                result shouldHaveSize 1
                result[0].percentage shouldBe 100
                result[0].alertLevel shouldBe "EXCEEDED"
            }
        }
    }

    Given("a budget with zero amount") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget = MonthlyBudget(couple = couple, category = foodCategory, yearMonth = "2026-03", amount = 0)

        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(budget)

        every {
            transactionRepository.sumByCategoryForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns emptyList()

        every {
            transactionRepository.sumAmountByCoupleIdAndDateRange(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns 0L

        When("getBudgetAlerts is called") {
            val result = service.getBudgetAlerts(user1.id, "2026-03")

            Then("returns empty (0% is SAFE)") {
                result shouldHaveSize 0
            }
        }
    }

    Given("a user not in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("getBudgetAlerts is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.getBudgetAlerts(user1.id, "2026-03")
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    Given("a category budget with no spending") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget = MonthlyBudget(couple = couple, category = foodCategory, yearMonth = "2026-03", amount = 500000)

        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(budget)

        // No spending for food category
        every {
            transactionRepository.sumByCategoryForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns emptyList()

        every {
            transactionRepository.sumAmountByCoupleIdAndDateRange(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                TransactionType.EXPENSE,
                any()
            )
        } returns 0L

        When("getBudgetAlerts is called") {
            val result = service.getBudgetAlerts(user1.id, "2026-03")

            Then("returns empty since 0% is SAFE") {
                result shouldHaveSize 0
            }
        }
    }
})
