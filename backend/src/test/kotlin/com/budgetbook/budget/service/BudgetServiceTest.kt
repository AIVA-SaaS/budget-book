package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.dto.CopyBudgetRequest
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
import com.budgetbook.sync.SyncEventPublisher
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
import java.time.LocalDate
import java.util.Optional
import java.util.UUID

class BudgetServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val budgetRepository = mockk<MonthlyBudgetRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val service = BudgetService(budgetRepository, coupleRepository, categoryRepository, transactionRepository, syncEventPublisher)

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

    Given("an existing MONTHLY budget switching to WEEKLY") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val budget = MonthlyBudget(
            couple = couple, category = category, yearMonth = "2026-03", amount = 150000,
            budgetPeriod = BudgetPeriod.MONTHLY, weeklyAmount = null
        )
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every { budgetRepository.save(budget) } returns budget

        When("updateBudget is called with budgetPeriod=WEEKLY") {
            val request = BudgetUpdateRequest(amount = 200000, budgetPeriod = "WEEKLY")
            val result = service.updateBudget(user1.id, budget.id, request)

            Then("updates amount, budgetPeriod, and calculates weeklyAmount") {
                result.amount shouldBe 200000
                result.budgetPeriod shouldBe "WEEKLY"
                // 2026-03 has 31 days -> 5 weeks, so 200000 / 5 = 40000
                result.weeklyAmount shouldBe 40000
            }
        }
    }

    Given("an existing WEEKLY budget updating amount only") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val budget = MonthlyBudget(
            couple = couple, category = category, yearMonth = "2026-03", amount = 150000,
            budgetPeriod = BudgetPeriod.WEEKLY, weeklyAmount = 30000
        )
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every { budgetRepository.save(budget) } returns budget

        When("updateBudget is called with only a new amount") {
            val request = BudgetUpdateRequest(amount = 250000)
            val result = service.updateBudget(user1.id, budget.id, request)

            Then("recalculates weeklyAmount from new amount") {
                result.amount shouldBe 250000
                result.budgetPeriod shouldBe "WEEKLY"
                // 250000 / 5 = 50000
                result.weeklyAmount shouldBe 50000
            }
        }
    }

    Given("an existing WEEKLY budget with explicit weeklyAmount") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val budget = MonthlyBudget(
            couple = couple, category = category, yearMonth = "2026-03", amount = 200000,
            budgetPeriod = BudgetPeriod.WEEKLY, weeklyAmount = 40000
        )
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every { budgetRepository.save(budget) } returns budget

        When("updateBudget is called with explicit weeklyAmount") {
            val request = BudgetUpdateRequest(amount = 200000, weeklyAmount = 45000)
            val result = service.updateBudget(user1.id, budget.id, request)

            Then("uses the explicit weeklyAmount") {
                result.amount shouldBe 200000
                result.weeklyAmount shouldBe 45000
            }
        }
    }

    Given("an existing WEEKLY budget switching to MONTHLY") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val budget = MonthlyBudget(
            couple = couple, category = category, yearMonth = "2026-03", amount = 200000,
            budgetPeriod = BudgetPeriod.WEEKLY, weeklyAmount = 40000
        )
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every { budgetRepository.save(budget) } returns budget

        When("updateBudget is called with budgetPeriod=MONTHLY") {
            val request = BudgetUpdateRequest(amount = 300000, budgetPeriod = "MONTHLY")
            val result = service.updateBudget(user1.id, budget.id, request)

            Then("clears weeklyAmount") {
                result.amount shouldBe 300000
                result.budgetPeriod shouldBe "MONTHLY"
                result.weeklyAmount shouldBe null
            }
        }
    }

    Given("an existing budget with invalid budgetPeriod in update") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val budget = MonthlyBudget(
            couple = couple, category = category, yearMonth = "2026-03", amount = 150000
        )
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)

        When("updateBudget is called with invalid budgetPeriod") {
            Then("throws BusinessException") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.updateBudget(user1.id, budget.id, BudgetUpdateRequest(amount = 200000, budgetPeriod = "INVALID"))
                }
                ex.code shouldBe "VALIDATION_ERROR"
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

        // Mock category expense aggregation query: category -> 95000
        every { transactionRepository.sumByCategoryForCouple(
            couple.id,
            LocalDate.of(2026, 3, 1),
            LocalDate.of(2026, 3, 31),
            TransactionType.EXPENSE
        ) } returns listOf(
            arrayOf(95000L, 1L, category.id, "식비", CategoryType.EXPENSE, "restaurant", "#FF5733")
        )

        // Mock total expense SUM query: 95000 + 50000 = 145000
        every { transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id,
            startDate = LocalDate.of(2026, 3, 1),
            endDate = LocalDate.of(2026, 3, 31),
            type = TransactionType.EXPENSE
        ) } returns 145000L

        When("getBudgetSummary is called") {
            val result = service.getBudgetSummary(user1.id, 2026, 3)

            Then("returns correct summary with no double-counting") {
                result.yearMonth shouldBe "2026-03"
                // When a "total" budget (categoryId=null) exists, use that as totalBudget
                // instead of summing all budgets (which would double-count)
                result.totalBudget shouldBe 3000000
                result.items.size shouldBe 2
                // totalSpent is calculated independently as the direct sum of ALL expenses (95000 + 50000)
                result.totalSpent shouldBe 145000
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

    // --- copyFromPreviousMonth ---

    Given("a user in an active couple for copy") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("copying budgets from a month with budgets to an empty month") {
            val sourceBudget1 = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-02", amount = 150000)
            val sourceBudget2 = MonthlyBudget(couple = couple, category = null, yearMonth = "2026-02", amount = 3000000)
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-02") } returns listOf(sourceBudget1, sourceBudget2)
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-03") } returns emptyList()
            every { budgetRepository.saveAll(any<List<MonthlyBudget>>()) } answers { firstArg() }

            val request = CopyBudgetRequest(sourceYear = 2026, sourceMonth = 2, targetYear = 2026, targetMonth = 3)
            val result = service.copyFromPreviousMonth(user1.id, request)

            Then("creates budgets for the target month") {
                result.size shouldBe 2
                result[0].yearMonth shouldBe "2026-03"
                result[0].amount shouldBe 150000
                result[1].yearMonth shouldBe "2026-03"
                result[1].amount shouldBe 3000000
            }
        }

        When("copying budgets when target month already has some budgets") {
            val sourceBudget1 = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-02", amount = 150000)
            val sourceBudget2 = MonthlyBudget(couple = couple, category = null, yearMonth = "2026-02", amount = 3000000)
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-02") } returns listOf(sourceBudget1, sourceBudget2)

            // Target month already has the category budget
            val existingBudget = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-03", amount = 200000)
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-03") } returns listOf(existingBudget)
            every { budgetRepository.saveAll(any<List<MonthlyBudget>>()) } answers { firstArg() }

            val request = CopyBudgetRequest(sourceYear = 2026, sourceMonth = 2, targetYear = 2026, targetMonth = 3)
            val result = service.copyFromPreviousMonth(user1.id, request)

            Then("only creates budgets for categories not yet in target") {
                result.size shouldBe 1
                result[0].category shouldBe null
                result[0].amount shouldBe 3000000
            }
        }

        When("copying budgets from a month with no budgets") {
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-01") } returns emptyList()

            val request = CopyBudgetRequest(sourceYear = 2026, sourceMonth = 1, targetYear = 2026, targetMonth = 3)

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.copyFromPreviousMonth(user1.id, request)
                }
                ex.code shouldBe "BUDGET_NOT_FOUND"
            }
        }

        When("copying budgets with same source and target month") {
            val request = CopyBudgetRequest(sourceYear = 2026, sourceMonth = 3, targetYear = 2026, targetMonth = 3)

            Then("throws BusinessException") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.copyFromPreviousMonth(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("all source categories already exist in target") {
            val sourceBudget = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-02", amount = 150000)
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-02") } returns listOf(sourceBudget)

            val existingBudget = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-04", amount = 200000)
            every { budgetRepository.findByCoupleIdAndYearMonth(couple.id, "2026-04") } returns listOf(existingBudget)

            val request = CopyBudgetRequest(sourceYear = 2026, sourceMonth = 2, targetYear = 2026, targetMonth = 4)
            val result = service.copyFromPreviousMonth(user1.id, request)

            Then("returns empty list") {
                result.size shouldBe 0
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
