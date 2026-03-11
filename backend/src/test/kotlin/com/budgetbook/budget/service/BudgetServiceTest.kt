package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.ForbiddenException
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
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.Pageable
import java.time.LocalDate
import java.util.Optional
import java.util.UUID

class BudgetServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val budgetRepository = mockk<MonthlyBudgetRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val service = BudgetService(budgetRepository, coupleRepository, categoryRepository, transactionRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val category = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF5733", isDefault = true)

    // --- createBudget ---

    Given("a user in an active couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("creating a budget with a category") {
            every { categoryRepository.findById(category.id) } returns Optional.of(category)
            every { budgetRepository.existsByCoupleIdAndCategoryIdAndYearMonth(couple.id, category.id, "2026-03") } returns false
            val budgetSlot = slot<MonthlyBudget>()
            every { budgetRepository.save(capture(budgetSlot)) } answers { budgetSlot.captured }

            val request = BudgetRequest(categoryId = category.id, yearMonth = "2026-03", amount = 150000)
            val result = service.createBudget(user1.id, request)

            Then("creates budget with correct fields") {
                result.yearMonth shouldBe "2026-03"
                result.amount shouldBe 150000
                result.category!!.id shouldBe category.id
                result.category!!.name shouldBe "식비"
                result.coupleId shouldBe couple.id
            }
        }

        When("creating a total budget (null category)") {
            every { budgetRepository.existsByCoupleIdAndCategoryIdAndYearMonth(couple.id, null, "2026-03") } returns false
            val budgetSlot = slot<MonthlyBudget>()
            every { budgetRepository.save(capture(budgetSlot)) } answers { budgetSlot.captured }

            val request = BudgetRequest(categoryId = null, yearMonth = "2026-03", amount = 3000000)
            val result = service.createBudget(user1.id, request)

            Then("creates budget without category") {
                result.category shouldBe null
                result.amount shouldBe 3000000
            }
        }

        When("creating a duplicate budget") {
            every { categoryRepository.findById(category.id) } returns Optional.of(category)
            every { budgetRepository.existsByCoupleIdAndCategoryIdAndYearMonth(couple.id, category.id, "2026-03") } returns true

            val request = BudgetRequest(categoryId = category.id, yearMonth = "2026-03", amount = 150000)

            Then("throws ConflictException") {
                val ex = shouldThrow<ConflictException> {
                    service.createBudget(user1.id, request)
                }
                ex.code shouldBe "DUPLICATE_BUDGET"
            }
        }

        When("creating with a category from a different couple") {
            val otherCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)
            val otherCat = Category(couple = otherCouple, name = "Other", type = CategoryType.EXPENSE)
            every { categoryRepository.findById(otherCat.id) } returns Optional.of(otherCat)

            val request = BudgetRequest(categoryId = otherCat.id, yearMonth = "2026-03", amount = 100000)

            Then("throws ForbiddenException") {
                val ex = shouldThrow<ForbiddenException> {
                    service.createBudget(user1.id, request)
                }
                ex.code shouldBe "FORBIDDEN"
            }
        }

        When("creating with a non-existent category") {
            val fakeId = UUID.randomUUID()
            every { categoryRepository.findById(fakeId) } returns Optional.empty()

            val request = BudgetRequest(categoryId = fakeId, yearMonth = "2026-03", amount = 100000)

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.createBudget(user1.id, request)
                }
                ex.code shouldBe "CATEGORY_NOT_FOUND"
            }
        }
    }

    // --- getBudgetsByMonth ---

    Given("budgets exist for the user's couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val budget1 = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-03", amount = 150000)
        val budget2 = MonthlyBudget(couple = couple, category = null, yearMonth = "2026-03", amount = 3000000)
        every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-03") } returns listOf(budget1, budget2)

        When("getBudgetsByMonth is called") {
            val result = service.getBudgetsByMonth(user1.id, 2026, 3)

            Then("returns all budgets for the month") {
                result.size shouldBe 2
                result[0].amount shouldBe 150000
                result[0].category!!.name shouldBe "식비"
                result[1].amount shouldBe 3000000
                result[1].category shouldBe null
            }
        }
    }

    // --- updateBudget ---

    Given("an existing budget to update") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val budget = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-03", amount = 150000)
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every { budgetRepository.save(budget) } returns budget

        When("updateBudget is called with new amount") {
            val request = BudgetUpdateRequest(amount = 200000)
            val result = service.updateBudget(user1.id, budget.id, request)

            Then("updates the amount") {
                result.amount shouldBe 200000
            }
        }
    }

    Given("a budget from a different couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val otherCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)
        val budget = MonthlyBudget(couple = otherCouple, yearMonth = "2026-03", amount = 100000)
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)

        When("updateBudget is called") {
            Then("throws ForbiddenException") {
                shouldThrow<ForbiddenException> {
                    service.updateBudget(user1.id, budget.id, BudgetUpdateRequest(amount = 200000))
                }
            }
        }
    }

    Given("a non-existent budget to update") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val fakeId = UUID.randomUUID()
        every { budgetRepository.findById(fakeId) } returns Optional.empty()

        When("updateBudget is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.updateBudget(user1.id, fakeId, BudgetUpdateRequest(amount = 200000))
                }
                ex.code shouldBe "BUDGET_NOT_FOUND"
            }
        }
    }

    // --- deleteBudget ---

    Given("a budget to delete") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val budget = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-03", amount = 150000)
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every { budgetRepository.delete(budget) } returns Unit

        When("deleteBudget is called") {
            service.deleteBudget(user1.id, budget.id)

            Then("deletes the budget") {
                verify(exactly = 1) { budgetRepository.delete(budget) }
            }
        }
    }

    Given("a budget from a different couple to delete") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val otherCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)
        val budget = MonthlyBudget(couple = otherCouple, yearMonth = "2026-03", amount = 100000)
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)

        When("deleteBudget is called") {
            Then("throws ForbiddenException") {
                shouldThrow<ForbiddenException> {
                    service.deleteBudget(user1.id, budget.id)
                }
            }
        }
    }

    // --- getBudgetSummary ---

    Given("budgets and transactions exist for summary") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val budget1 = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-03", amount = 150000)
        val budget2 = MonthlyBudget(couple = couple, category = null, yearMonth = "2026-03", amount = 3000000)
        every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-03") } returns listOf(budget1, budget2)

        val tx1 = Transaction(
            couple = couple, author = user1, category = category, type = TransactionType.EXPENSE,
            amount = 95000, description = "식비 지출", transactionDate = LocalDate.of(2026, 3, 10)
        )
        val tx2 = Transaction(
            couple = couple, author = user1, category = null, type = TransactionType.EXPENSE,
            amount = 50000, description = "기타 지출", transactionDate = LocalDate.of(2026, 3, 15)
        )

        every { transactionRepository.findByCoupleIdAndFilters(
            coupleId = couple.id,
            startDate = LocalDate.of(2026, 3, 1),
            endDate = LocalDate.of(2026, 3, 31),
            type = TransactionType.EXPENSE,
            categoryId = null,
            pageable = any()
        ) } returns PageImpl(listOf(tx1, tx2))

        When("getBudgetSummary is called") {
            val result = service.getBudgetSummary(user1.id, 2026, 3)

            Then("returns correct summary") {
                result.yearMonth shouldBe "2026-03"
                result.totalBudget shouldBe 3150000
                result.items.size shouldBe 2
            }

            Then("calculates category budget correctly") {
                val catItem = result.items.first { it.category != null }
                catItem.budgetAmount shouldBe 150000
                catItem.spentAmount shouldBe 95000
                catItem.remainingAmount shouldBe 55000
                catItem.usageRate shouldBe 63.3
            }

            Then("calculates total budget correctly") {
                val totalItem = result.items.first { it.category == null }
                totalItem.budgetAmount shouldBe 3000000
                totalItem.spentAmount shouldBe 145000 // 95000 + 50000
                totalItem.remainingAmount shouldBe 2855000
            }
        }
    }

    // --- user not in couple ---

    Given("a user not in any couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("any budget operation is called") {
            Then("throws NotFoundException for createBudget") {
                val ex = shouldThrow<NotFoundException> {
                    service.createBudget(user1.id, BudgetRequest(yearMonth = "2026-03", amount = 100000))
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }
})
