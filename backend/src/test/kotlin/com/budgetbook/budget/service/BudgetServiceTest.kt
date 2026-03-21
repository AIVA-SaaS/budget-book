package com.budgetbook.budget.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.dto.CopyBudgetRequest
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
    val service = BudgetService(budgetRepository, coupleResolver, categoryRepository, categoryGroupRepository, transactionRepository, syncEventPublisher, moneyPocketRepository, userRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val category = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF5733", isDefault = true)

    // --- createBudget ---

    Given("a user in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("creating a budget with a category") {
            every { categoryRepository.findById(category.id) } returns Optional.of(category)
            every { budgetRepository.existsByCoupleIdAndCategoryGroupAndYearMonth(couple.id, category.id, null, "2026-03") } returns false
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
            every { budgetRepository.existsByCoupleIdAndCategoryGroupAndYearMonth(couple.id, null, null, "2026-03") } returns false
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
            every { budgetRepository.existsByCoupleIdAndCategoryGroupAndYearMonth(couple.id, category.id, null, "2026-03") } returns true

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
            every { budgetRepository.existsByCoupleIdAndCategoryGroupAndYearMonth(couple.id, null, group.id, "2026-03") } returns false
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

        // Category expenses: groupCat1=150000, groupCat2=100000 => group total=250000
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

        // Batch category lookup for group spending computation
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(groupCat1, groupCat2)

        When("getBudgetSummary is called") {
            val result = service.getBudgetSummary(user1.id, 2026, 3)

            Then("calculates group budget spent amount from category aggregation") {
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

        val monthlyBudget = MonthlyBudget(
            couple = couple, category = category, yearMonth = "2026-03", amount = 300000,
            budgetPeriod = BudgetPeriod.MONTHLY
        )
        val weeklyBudget = MonthlyBudget(
            couple = couple, yearMonth = "2026-03", amount = 200000,
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

        When("getBudgetSummary is called") {
            val result = service.getBudgetSummary(user1.id, 2026, 3)

            Then("excludes WEEKLY budgets from summary items and totalBudget") {
                result.items.size shouldBe 1
                result.items[0].category!!.name shouldBe "식비"
                result.items[0].budgetAmount shouldBe 300000
                result.totalBudget shouldBe 300000
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
})
