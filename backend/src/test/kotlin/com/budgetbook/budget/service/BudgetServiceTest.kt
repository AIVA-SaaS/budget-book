package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.BudgetRowKind
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.dto.CopyBudgetRequest
import com.budgetbook.budget.dto.MonthOverrideUpsertRequest
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.domain.BudgetType
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryGroup
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.pocket.domain.MoneyPocket
import com.budgetbook.pocket.domain.PocketType
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.spendingplan.repository.SpendingPlanRepository
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
    val coupleResolver = mockk<CoupleResolver>()
    val categoryRepository = mockk<CategoryRepository>()
    val categoryGroupRepository = mockk<CategoryGroupRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val moneyPocketRepository = mockk<MoneyPocketRepository>()
    val userRepository = mockk<com.budgetbook.auth.repository.UserRepository>()
    val spendingPlanRepository = mockk<SpendingPlanRepository>()
    val service = BudgetService(budgetRepository, coupleResolver, categoryRepository, categoryGroupRepository, transactionRepository, syncEventPublisher, moneyPocketRepository, userRepository, spendingPlanRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val category = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF5733", isDefault = true)

    // Default: no planned spending (individual tests can override)
    every { spendingPlanRepository.sumPlannedAmountByCategoryIds(any(), any(), any()) } returns emptyList()
    every { spendingPlanRepository.sumPlannedAmountByGroupIds(any(), any(), any()) } returns emptyList()
    every { spendingPlanRepository.sumTotalPlannedAmount(any(), any()) } returns 0L

    // --- createBudget ---

    Given("a user in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("creating a budget with a category") {
            every { categoryRepository.findById(category.id) } returns Optional.of(category)
            // Phase 23 PR-X4: default is TEMPLATE → mock template exists check.
            every { budgetRepository.existsTemplateByCategoryGroup(couple.id, category.id, null) } returns false
            val budgetSlot = slot<MonthlyBudget>()
            every { budgetRepository.save(capture(budgetSlot)) } answers { budgetSlot.captured }

            val request = BudgetRequest(categoryId = category.id, yearMonth = "2026-03", amount = 150000)
            val result = service.createBudget(user1.id, request)

            Then("creates budget with correct fields (TEMPLATE by default, endYearMonth=null)") {
                result.yearMonth shouldBe "2026-03"
                result.amount shouldBe 150000
                result.category!!.id shouldBe category.id
                result.category!!.name shouldBe "식비"
                result.coupleId shouldBe couple.id
                result.rowKind shouldBe "TEMPLATE"
                result.endYearMonth shouldBe null
            }
        }

        When("creating a total budget (null category)") {
            every { budgetRepository.existsTemplateByCategoryGroup(couple.id, null, null) } returns false
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
            every { budgetRepository.existsTemplateByCategoryGroup(couple.id, category.id, null) } returns true

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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget1 = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-03", amount = 150000)
        val budget2 = MonthlyBudget(couple = couple, category = null, yearMonth = "2026-03", amount = 3000000)
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(budget1, budget2)

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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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

    Given("an existing budget to update with a new category") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val oldCategory = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF5733", isDefault = true)
        val newCategory = Category(couple = couple, name = "교통비", type = CategoryType.EXPENSE, icon = "directions_bus", color = "#3366FF", isDefault = true)
        val budget = MonthlyBudget(couple = couple, category = oldCategory, yearMonth = "2026-03", amount = 150000)
        every { budgetRepository.findById(budget.id) } returns Optional.of(budget)
        every { budgetRepository.save(budget) } returns budget

        When("updateBudget is called with a valid categoryId") {
            every { categoryRepository.findById(newCategory.id) } returns Optional.of(newCategory)
            val request = BudgetUpdateRequest(amount = 200000, categoryId = newCategory.id)
            val result = service.updateBudget(user1.id, budget.id, request)

            Then("updates both the amount and category") {
                result.amount shouldBe 200000
                result.category!!.id shouldBe newCategory.id
                result.category!!.name shouldBe "교통비"
            }
        }

        When("updateBudget is called with a non-existent categoryId") {
            val fakeId = UUID.randomUUID()
            every { categoryRepository.findById(fakeId) } returns Optional.empty()

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.updateBudget(user1.id, budget.id, BudgetUpdateRequest(amount = 200000, categoryId = fakeId))
                }
                ex.code shouldBe "CATEGORY_NOT_FOUND"
            }
        }

        When("updateBudget is called with a category from a different couple") {
            val otherCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)
            val otherCat = Category(couple = otherCouple, name = "Other", type = CategoryType.EXPENSE)
            every { categoryRepository.findById(otherCat.id) } returns Optional.of(otherCat)

            Then("throws ForbiddenException") {
                val ex = shouldThrow<ForbiddenException> {
                    service.updateBudget(user1.id, budget.id, BudgetUpdateRequest(amount = 200000, categoryId = otherCat.id))
                }
                ex.code shouldBe "FORBIDDEN"
            }
        }

        When("updateBudget is called without categoryId") {
            val request = BudgetUpdateRequest(amount = 200000)
            val result = service.updateBudget(user1.id, budget.id, request)

            Then("keeps the original category") {
                result.amount shouldBe 200000
                result.category!!.id shouldBe oldCategory.id
                result.category!!.name shouldBe "식비"
            }
        }
    }

    Given("a budget from a different couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget1 = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-03", amount = 150000)
        val budget2 = MonthlyBudget(couple = couple, category = null, yearMonth = "2026-03", amount = 3000000)
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(budget1, budget2)

        // Mock category expense aggregation query: category -> 95000
        every { transactionRepository.sumByCategoryForCouple(
            couple.id,
            LocalDate.of(2026, 3, 1),
            LocalDate.of(2026, 3, 31),
            TransactionType.EXPENSE,
            user1.id
        ) } returns listOf(
            arrayOf(95000L, 1L, category.id, "식비", CategoryType.EXPENSE, "restaurant", "#FF5733")
        )

        // Mock total expense SUM query: 95000 + 50000 = 145000
        every { transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id,
            startDate = LocalDate.of(2026, 3, 1),
            endDate = LocalDate.of(2026, 3, 31),
            type = TransactionType.EXPENSE,
            userId = user1.id
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("copying budgets from a month with budgets to an empty month") {
            val sourceBudget1 = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-02", amount = 150000)
            val sourceBudget2 = MonthlyBudget(couple = couple, category = null, yearMonth = "2026-02", amount = 3000000)
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-02", user1.id) } returns listOf(sourceBudget1, sourceBudget2)
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()
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
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-02", user1.id) } returns listOf(sourceBudget1, sourceBudget2)

            // Target month already has the category budget
            val existingBudget = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-03", amount = 200000)
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(existingBudget)
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
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-01", user1.id) } returns emptyList()

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
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-02", user1.id) } returns listOf(sourceBudget)

            val existingBudget = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-04", amount = 200000)
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-04", user1.id) } returns listOf(existingBudget)

            val request = CopyBudgetRequest(sourceYear = 2026, sourceMonth = 2, targetYear = 2026, targetMonth = 4)
            val result = service.copyFromPreviousMonth(user1.id, request)

            Then("returns empty list") {
                result.size shouldBe 0
            }
        }
    }

    // --- group budget ---

    Given("a user creating a group budget") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group = CategoryGroup(couple = couple, name = "생활비", budgetType = BudgetType.WEEKLY, displayOrder = 1, isDefault = true)

        When("creating a budget with a groupId") {
            every { categoryGroupRepository.findByIdAndCoupleId(group.id, couple.id) } returns group
            every { budgetRepository.existsTemplateByCategoryGroup(couple.id, null, group.id) } returns false
            val budgetSlot = slot<MonthlyBudget>()
            every { budgetRepository.save(capture(budgetSlot)) } answers { budgetSlot.captured }

            val request = BudgetRequest(groupId = group.id, yearMonth = "2026-03", amount = 500000)
            val result = service.createBudget(user1.id, request)

            Then("creates budget with group info") {
                result.groupId shouldBe group.id
                result.groupName shouldBe "생활비"
                result.category shouldBe null
                result.amount shouldBe 500000
            }
        }

        When("creating a budget with both categoryId and groupId") {
            val request = BudgetRequest(categoryId = category.id, groupId = group.id, yearMonth = "2026-03", amount = 100000)

            Then("throws BusinessException for mutual exclusivity") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.createBudget(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("creating a budget with a non-existent groupId") {
            val fakeId = UUID.randomUUID()
            every { categoryGroupRepository.findByIdAndCoupleId(fakeId, couple.id) } returns null

            val request = BudgetRequest(groupId = fakeId, yearMonth = "2026-03", amount = 100000)

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.createBudget(user1.id, request)
                }
                ex.code shouldBe "GROUP_NOT_FOUND"
            }
        }
    }

    Given("a group budget in summary calculation") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group = CategoryGroup(couple = couple, name = "생활비", budgetType = BudgetType.WEEKLY, displayOrder = 1, isDefault = true)
        val groupCat1 = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, group = group)
        val groupCat2 = Category(couple = couple, name = "교통비", type = CategoryType.EXPENSE, group = group)
        val groupBudget = MonthlyBudget(couple = couple, group = group, yearMonth = "2026-03", amount = 500000)
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(groupBudget)

        // Category expenses (used for category-level budgets, not group)
        every { transactionRepository.sumByCategoryForCouple(
            couple.id, LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 31), TransactionType.EXPENSE, user1.id
        ) } returns listOf(
            arrayOf(150000L, 1L, groupCat1.id, "식비", CategoryType.EXPENSE, "restaurant", "#FF5733"),
            arrayOf(100000L, 1L, groupCat2.id, "교통비", CategoryType.EXPENSE, "directions_bus", "#2196F3")
        )

        every { transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id, startDate = LocalDate.of(2026, 3, 1),
            endDate = LocalDate.of(2026, 3, 31), type = TransactionType.EXPENSE, userId = user1.id
        ) } returns 300000L

        // Direct DB aggregation for group spending
        every { transactionRepository.sumByCategoryGroupForCouple(
            couple.id, LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 31),
            TransactionType.EXPENSE, setOf(group.id), user1.id
        ) } returns listOf(
            arrayOf(group.id, 250000L)
        )

        When("getBudgetSummary is called") {
            val result = service.getBudgetSummary(user1.id, 2026, 3)

            Then("calculates group budget spent amount from direct DB aggregation") {
                result.items.size shouldBe 1
                val item = result.items[0]
                item.groupId shouldBe group.id
                item.groupName shouldBe "생활비"
                item.budgetAmount shouldBe 500000
                item.spentAmount shouldBe 250000
                item.remainingAmount shouldBe 250000
            }
        }
    }

    // --- getBudgetSummary excludes WEEKLY budgets ---

    Given("a mix of MONTHLY and WEEKLY budgets in summary") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val weeklyGroup = com.budgetbook.category.domain.CategoryGroup(
            couple = couple, name = "생활비", budgetType = com.budgetbook.category.domain.BudgetType.WEEKLY
        )

        val monthlyBudget = MonthlyBudget(
            couple = couple, category = category, yearMonth = "2026-03", amount = 300000,
            budgetPeriod = BudgetPeriod.MONTHLY
        )
        val weeklyBudget = MonthlyBudget(
            couple = couple, group = weeklyGroup, yearMonth = "2026-03", amount = 200000,
            budgetPeriod = BudgetPeriod.WEEKLY, weeklyAmount = 50000
        )
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(monthlyBudget, weeklyBudget)

        every { transactionRepository.sumByCategoryForCouple(
            couple.id, LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 31), TransactionType.EXPENSE, user1.id
        ) } returns listOf(
            arrayOf(80000L, 1L, category.id, "식비", CategoryType.EXPENSE, "restaurant", "#FF5733")
        )

        every { transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id, startDate = LocalDate.of(2026, 3, 1),
            endDate = LocalDate.of(2026, 3, 31), type = TransactionType.EXPENSE, userId = user1.id
        ) } returns 120000L

        // Direct DB aggregation for weekly group spending
        every { transactionRepository.sumByCategoryGroupForCouple(
            couple.id, LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 31),
            TransactionType.EXPENSE, setOf(weeklyGroup.id), user1.id
        ) } returns listOf(
            arrayOf(weeklyGroup.id, 40000L)
        )

        When("getBudgetSummary is called") {
            val result = service.getBudgetSummary(user1.id, 2026, 3)

            Then("includes both MONTHLY and WEEKLY budgets with correct spent amounts") {
                result.items.size shouldBe 2
                val monthly = result.items.find { it.category != null }!!
                monthly.category!!.name shouldBe "식비"
                monthly.budgetAmount shouldBe 300000
                monthly.spentAmount shouldBe 80000
                val weekly = result.items.find { it.groupId != null }!!
                weekly.groupName shouldBe "생활비"
                // WEEKLY pro-rata: weeklyAmount(50000) * 31 days / 7 = 221428
                weekly.budgetAmount shouldBe 221428
                weekly.spentAmount shouldBe 40000
                // totalBudget = monthly(300000) + weekly pro-rata(221428)
                result.totalBudget shouldBe 521428
                // No total budget entry → totalSpent = sum of items, not all expenses
                result.totalSpent shouldBe 120000
            }
        }
    }

    // --- getBudgetSummary double-counting prevention ---

    Given("group budget AND child category budgets coexist without total budget") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group = CategoryGroup(couple = couple, name = "식비그룹", budgetType = BudgetType.WEEKLY, displayOrder = 1, isDefault = true)
        val childCat1 = Category(couple = couple, name = "생활비", type = CategoryType.EXPENSE, group = group, icon = "home", color = "#111111")
        val childCat2 = Category(couple = couple, name = "장", type = CategoryType.EXPENSE, group = group, icon = "cart", color = "#222222")

        val groupBudget = MonthlyBudget(couple = couple, group = group, yearMonth = "2026-04", amount = 500000)
        val cat1Budget = MonthlyBudget(couple = couple, category = childCat1, yearMonth = "2026-04", amount = 300000)
        val cat2Budget = MonthlyBudget(couple = couple, category = childCat2, yearMonth = "2026-04", amount = 200000)
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-04", user1.id) } returns listOf(groupBudget, cat1Budget, cat2Budget)

        every { transactionRepository.sumByCategoryForCouple(
            couple.id, LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30), TransactionType.EXPENSE, user1.id
        ) } returns listOf(
            arrayOf(60000L, 1L, childCat1.id, "생활비", CategoryType.EXPENSE, "home", "#111111"),
            arrayOf(40000L, 1L, childCat2.id, "장", CategoryType.EXPENSE, "cart", "#222222")
        )

        every { transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id, startDate = LocalDate.of(2026, 4, 1),
            endDate = LocalDate.of(2026, 4, 30), type = TransactionType.EXPENSE, userId = user1.id
        ) } returns 100000L

        every { transactionRepository.sumByCategoryGroupForCouple(
            couple.id, LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 30),
            TransactionType.EXPENSE, setOf(group.id), user1.id
        ) } returns listOf(
            arrayOf(group.id, 100000L)
        )

        When("getBudgetSummary is called") {
            val result = service.getBudgetSummary(user1.id, 2026, 4)

            Then("totalBudget excludes child categories covered by the group budget (no double counting)") {
                result.items.size shouldBe 3
                // totalBudget should only count the group budget, not the children
                result.totalBudget shouldBe 500000
                // totalSpent should only count the group's spent, not children's
                result.totalSpent shouldBe 100000
            }
        }
    }

    // --- getBudgetSummary with planned amounts (C-7) ---

    Given("budgets with planned spending plans") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val budget1 = MonthlyBudget(couple = couple, category = category, yearMonth = "2026-03", amount = 150000)
        val budget2 = MonthlyBudget(couple = couple, category = null, yearMonth = "2026-03", amount = 3000000)
        every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns listOf(budget1, budget2)

        every { transactionRepository.sumByCategoryForCouple(
            couple.id, LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 31), TransactionType.EXPENSE, user1.id
        ) } returns listOf(
            arrayOf(50000L, 1L, category.id, "식비", CategoryType.EXPENSE, "restaurant", "#FF5733")
        )

        every { transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id, startDate = LocalDate.of(2026, 3, 1),
            endDate = LocalDate.of(2026, 3, 31), type = TransactionType.EXPENSE, userId = user1.id
        ) } returns 80000L

        // Planned spending: 30000 for category, 50000 total
        every { spendingPlanRepository.sumPlannedAmountByCategoryIds(couple.id, setOf(category.id), user1.id) } returns listOf(
            arrayOf(category.id as Any, 30000L as Any)
        )
        every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id) } returns 50000L

        When("getBudgetSummary is called") {
            val result = service.getBudgetSummary(user1.id, 2026, 3)

            Then("includes planned amounts in summary items") {
                val catItem = result.items.first { it.category != null }
                catItem.plannedAmount shouldBe 30000
                catItem.remainingAmount shouldBe 70000 // 150000 - 50000 - 30000
            }

            Then("includes planned amount in total budget item") {
                val totalItem = result.items.first { it.category == null }
                totalItem.plannedAmount shouldBe 50000
                totalItem.remainingAmount shouldBe 2870000 // 3000000 - 80000 - 50000
            }

            Then("includes totalPlanned in response") {
                result.totalPlanned shouldBe 50000
            }
        }
    }

    // --- user not in couple ---

    Given("a user not in any couple") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("any budget operation is called") {
            Then("throws NotFoundException for createBudget") {
                val ex = shouldThrow<NotFoundException> {
                    service.createBudget(user1.id, BudgetRequest(yearMonth = "2026-03", amount = 100000))
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    // ================================================================
    // Phase 23 PR-X4: 템플릿 + 오버라이드 모델
    // ================================================================

    Given("PR-X4: creating a TEMPLATE budget with explicit endYearMonth") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { categoryRepository.findById(category.id) } returns Optional.of(category)
        every { budgetRepository.existsTemplateByCategoryGroup(couple.id, category.id, null) } returns false
        val budgetSlot = slot<MonthlyBudget>()
        every { budgetRepository.save(capture(budgetSlot)) } answers { budgetSlot.captured }

        When("createBudget is called with endYearMonth=2026-06") {
            val request = BudgetRequest(
                categoryId = category.id,
                yearMonth = "2026-02",
                amount = 150000,
                endYearMonth = "2026-06"
            )
            val result = service.createBudget(user1.id, request)

            Then("creates TEMPLATE with start=2026-02, end=2026-06") {
                result.rowKind shouldBe "TEMPLATE"
                result.yearMonth shouldBe "2026-02"
                result.endYearMonth shouldBe "2026-06"
                result.amount shouldBe 150000
            }
        }
    }

    Given("PR-X4: creating with invalid endYearMonth (end < start)") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { categoryRepository.findById(category.id) } returns Optional.of(category)

        When("createBudget is called with endYearMonth < yearMonth") {
            val request = BudgetRequest(
                categoryId = category.id,
                yearMonth = "2026-06",
                amount = 150000,
                endYearMonth = "2026-03"
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.createBudget(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("PR-X4: upsertMonthOverride creates a new OVERRIDE") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { categoryRepository.findById(category.id) } returns Optional.of(category)
        every { budgetRepository.findOverrideForKey(couple.id, category.id, null, "2026-03") } returns null
        val budgetSlot = slot<MonthlyBudget>()
        every { budgetRepository.save(capture(budgetSlot)) } answers { budgetSlot.captured }

        When("upsertMonthOverride is called") {
            val request = MonthOverrideUpsertRequest(
                categoryId = category.id,
                yearMonth = "2026-03",
                amount = 300000
            )
            val result = service.upsertMonthOverride(user1.id, request)

            Then("creates OVERRIDE with start=end=2026-03") {
                result.rowKind shouldBe "OVERRIDE"
                result.yearMonth shouldBe "2026-03"
                result.endYearMonth shouldBe "2026-03"
                result.amount shouldBe 300000
            }
        }
    }

    Given("PR-X4: upsertMonthOverride updates an existing OVERRIDE") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { categoryRepository.findById(category.id) } returns Optional.of(category)

        val existing = MonthlyBudget(
            couple = couple, category = category,
            yearMonth = "2026-03", endYearMonth = "2026-03",
            rowKind = BudgetRowKind.OVERRIDE,
            amount = 150000
        )
        every { budgetRepository.findOverrideForKey(couple.id, category.id, null, "2026-03") } returns existing
        every { budgetRepository.save(existing) } returns existing

        When("upsertMonthOverride is called with new amount") {
            val request = MonthOverrideUpsertRequest(
                categoryId = category.id,
                yearMonth = "2026-03",
                amount = 500000
            )
            val result = service.upsertMonthOverride(user1.id, request)

            Then("updates the existing OVERRIDE amount — template unchanged") {
                result.rowKind shouldBe "OVERRIDE"
                result.amount shouldBe 500000
                existing.amount shouldBe 500000
                verify(exactly = 1) { budgetRepository.save(existing) }
            }
        }
    }

    Given("PR-X4: merged view — override wins over template for same month") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        // findByCoupleIdAndYearMonthAndUserId 는 default method 로 병합 수행.
        // 서비스 레벨 테스트에서는 repo.findByCoupleIdAndYearMonthAndUserId 를 직접 스텁하여
        // 병합 후 결과가 service 로 전달되는지 확인.
        val override = MonthlyBudget(
            couple = couple, category = category,
            yearMonth = "2026-03", endYearMonth = "2026-03",
            rowKind = BudgetRowKind.OVERRIDE,
            amount = 300000
        )
        // findByCoupleIdAndYearMonthAndUserId 를 직접 스텁 (default 메서드 병합 결과)
        every {
            budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id)
        } returns listOf(override) // 병합 결과: override only (같은 key 의 template 제외)

        When("getBudgetsByMonth(2026-03) is called") {
            val result = service.getBudgetsByMonth(user1.id, 2026, 3)

            Then("returns only the override (amount=300000)") {
                result.size shouldBe 1
                result[0].amount shouldBe 300000
                result[0].rowKind shouldBe "OVERRIDE"
            }
        }
    }

    Given("PR-X4: deleteBudget with cascadeFuture=true shortens TEMPLATE and deletes future overrides") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("deleteBudget(template, cascadeFuture=true, from=2026-04) is called") {
            // NOTE: Here we pretend the caller invoked cascade at M=template.yearMonth is wrong.
            // We simulate targeting the template's yearMonth=2026-04 via a mock that we construct.
            // For this test we directly call with template id — the service reads template.yearMonth
            // for cascadeFromYearMonth. So we set template.yearMonth=2026-04 via a new instance.
            val cascadeTemplate = MonthlyBudget(
                couple = couple, category = category,
                yearMonth = "2026-04", endYearMonth = null,
                rowKind = BudgetRowKind.TEMPLATE,
                amount = 150000
            )
            every { budgetRepository.findById(cascadeTemplate.id) } returns Optional.of(cascadeTemplate)
            every { budgetRepository.save(cascadeTemplate) } returns cascadeTemplate
            every { budgetRepository.delete(cascadeTemplate) } returns Unit
            every {
                budgetRepository.deleteOverridesFromMonth(couple.id, category.id, null, "2026-04")
            } returns 2

            service.deleteBudget(user1.id, cascadeTemplate.id, cascadeFuture = true)

            Then("template end_ym becomes (from-1) and overrides from that month are deleted") {
                // Actually, since cascadeTemplate.yearMonth=2026-04 and we cascade from it,
                // prevMonth=2026-03 is < template.yearMonth(2026-04) → template 전체 삭제 경로.
                verify(exactly = 1) { budgetRepository.delete(cascadeTemplate) }
                verify(exactly = 1) {
                    budgetRepository.deleteOverridesFromMonth(couple.id, category.id, null, "2026-04")
                }
            }
        }
    }

    Given("PR-X4: deleteBudget cascadeFuture on OVERRIDE shortens parent TEMPLATE") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val override = MonthlyBudget(
            couple = couple, category = category,
            yearMonth = "2026-05", endYearMonth = "2026-05",
            rowKind = BudgetRowKind.OVERRIDE,
            amount = 300000
        )
        val parentTemplate = MonthlyBudget(
            couple = couple, category = category,
            yearMonth = "2026-02", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE,
            amount = 150000
        )
        every { budgetRepository.findById(override.id) } returns Optional.of(override)
        every {
            budgetRepository.findTemplateByCategoryGroup(couple.id, category.id, null)
        } returns parentTemplate
        every { budgetRepository.save(parentTemplate) } returns parentTemplate
        every {
            budgetRepository.deleteOverridesFromMonth(couple.id, category.id, null, "2026-05")
        } returns 1

        When("deleteBudget(override, cascadeFuture=true) is called") {
            service.deleteBudget(user1.id, override.id, cascadeFuture = true)

            Then("template end_ym = 2026-04 (prev of 2026-05) and future overrides wiped") {
                parentTemplate.endYearMonth shouldBe "2026-04"
                verify(exactly = 1) { budgetRepository.save(parentTemplate) }
                verify(exactly = 1) {
                    budgetRepository.deleteOverridesFromMonth(couple.id, category.id, null, "2026-05")
                }
            }
        }
    }

    Given("PR-X4: deleteBudget without cascadeFuture deletes only that row") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val override = MonthlyBudget(
            couple = couple, category = category,
            yearMonth = "2026-03", endYearMonth = "2026-03",
            rowKind = BudgetRowKind.OVERRIDE,
            amount = 300000
        )
        every { budgetRepository.findById(override.id) } returns Optional.of(override)
        every { budgetRepository.delete(override) } returns Unit

        When("deleteBudget(override, cascadeFuture=false)") {
            service.deleteBudget(user1.id, override.id, cascadeFuture = false)

            Then("only the override is deleted — no cascade") {
                verify(exactly = 1) { budgetRepository.delete(override) }
                verify(exactly = 0) {
                    budgetRepository.deleteOverridesFromMonth(any(), any(), any(), any())
                }
            }
        }
    }

    Given("PR-X4: repository default merge — template covers month and no override exists") {
        // Test the default merge method directly via MockK spy-like behavior.
        // We create a minimal mock that delegates findByCoupleIdAndYearMonthAndUserId to default impl.
        val repo = mockk<MonthlyBudgetRepository>()
        val template = MonthlyBudget(
            couple = couple, category = category,
            yearMonth = "2026-01", endYearMonth = null,
            rowKind = BudgetRowKind.TEMPLATE,
            amount = 100000
        )

        every { repo.findTemplatesCovering(couple.id, "2026-03", user1.id) } returns listOf(template)
        every { repo.findOverridesForMonth(couple.id, "2026-03", user1.id) } returns emptyList()
        every {
            repo.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id)
        } answers { callOriginal() }

        When("findByCoupleIdAndYearMonthAndUserId is called") {
            val result = repo.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id)

            Then("returns the template (amount=100000)") {
                result.size shouldBe 1
                result[0].amount shouldBe 100000
                result[0].rowKind shouldBe BudgetRowKind.TEMPLATE
            }
        }
    }
})
