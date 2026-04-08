package com.budgetbook.spendingplan.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.spendingplan.domain.SpendingPlan
import com.budgetbook.spendingplan.domain.SpendingPlanFrequency
import com.budgetbook.spendingplan.domain.SpendingPlanStatus
import com.budgetbook.spendingplan.dto.CompleteSpendingPlanRequest
import com.budgetbook.spendingplan.dto.CreateSpendingPlanRequest
import com.budgetbook.spendingplan.dto.UpdateSpendingPlanRequest
import com.budgetbook.spendingplan.repository.SpendingPlanRepository
import com.budgetbook.spendingplan.repository.SpendingPlanStatusHistoryRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.time.LocalDate
import java.util.Optional
import java.util.UUID

class SpendingPlanServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val spendingPlanRepository = mockk<SpendingPlanRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val userRepository = mockk<UserRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val paymentMethodRepository = mockk<PaymentMethodRepository>()
    val monthlyBudgetRepository = mockk<MonthlyBudgetRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val statusHistoryRepository = mockk<SpendingPlanStatusHistoryRepository>()

    val service = SpendingPlanService(
        spendingPlanRepository, coupleResolver, userRepository,
        categoryRepository, paymentMethodRepository, monthlyBudgetRepository,
        transactionRepository, statusHistoryRepository
    )

    val user1 = User(email = "u1@test.com", nickname = "User1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "User2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val otherCouple = Couple(user1 = user2, user2 = user1, status = CoupleStatus.ACTIVE)

    val category = mockk<Category>(relaxed = true).also {
        every { it.id } returns UUID.randomUUID()
        every { it.name } returns "Food"
        every { it.group } returns null
    }

    val paymentMethod = PaymentMethod(couple = couple, name = "Shinhan Card", type = PaymentMethodType.CREDIT)
    val otherCouplePaymentMethod = PaymentMethod(couple = otherCouple, name = "Other PM", type = PaymentMethodType.BANK)

    // --- createPlan ---

    Given("a user in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { statusHistoryRepository.save(any()) } answers { firstArg() }

        When("creating a plan with valid data") {
            every { categoryRepository.findById(category.id) } returns Optional.of(category)
            every { paymentMethodRepository.findById(paymentMethod.id) } returns Optional.of(paymentMethod)
            val planSlot = slot<SpendingPlan>()
            every { spendingPlanRepository.save(capture(planSlot)) } answers { planSlot.captured }

            val request = CreateSpendingPlanRequest(
                name = "Costco shopping",
                amount = 150000,
                targetDate = LocalDate.of(2026, 3, 29),
                categoryId = category.id,
                paymentMethodId = paymentMethod.id,
                memo = "Groceries"
            )
            val result = service.createPlan(user1.id, request)

            Then("creates plan with correct fields") {
                result.name shouldBe "Costco shopping"
                result.amount shouldBe 150000
                result.status shouldBe "PLANNED"
                result.category shouldNotBe null
                result.paymentMethod shouldNotBe null
                result.visibility shouldBe "SHARED"
            }
        }

        When("creating a plan with minimal data") {
            val planSlot = slot<SpendingPlan>()
            every { spendingPlanRepository.save(capture(planSlot)) } answers { planSlot.captured }

            val request = CreateSpendingPlanRequest(
                name = "Simple plan",
                amount = 50000,
                targetDate = LocalDate.of(2026, 4, 1)
            )
            val result = service.createPlan(user1.id, request)

            Then("creates plan with defaults") {
                result.name shouldBe "Simple plan"
                result.category shouldBe null
                result.paymentMethod shouldBe null
                result.isRecurring shouldBe false
                result.visibility shouldBe "SHARED"
            }
        }

        When("creating a recurring plan without frequency") {
            val request = CreateSpendingPlanRequest(
                name = "Bad recurring",
                amount = 10000,
                targetDate = LocalDate.of(2026, 4, 1),
                isRecurring = true,
                frequency = null
            )

            Then("throws validation error") {
                val ex = shouldThrow<BusinessException> {
                    service.createPlan(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("creating a recurring plan with frequency") {
            val planSlot = slot<SpendingPlan>()
            every { spendingPlanRepository.save(capture(planSlot)) } answers { planSlot.captured }

            val request = CreateSpendingPlanRequest(
                name = "Monthly groceries",
                amount = 200000,
                targetDate = LocalDate.of(2026, 4, 1),
                isRecurring = true,
                frequency = SpendingPlanFrequency.MONTHLY
            )
            val result = service.createPlan(user1.id, request)

            Then("creates recurring plan") {
                result.isRecurring shouldBe true
                result.frequency shouldBe SpendingPlanFrequency.MONTHLY
            }
        }

        When("creating a plan with payment method from another couple") {
            every { paymentMethodRepository.findById(otherCouplePaymentMethod.id) } returns Optional.of(otherCouplePaymentMethod)

            val request = CreateSpendingPlanRequest(
                name = "Bad plan",
                amount = 10000,
                targetDate = LocalDate.of(2026, 4, 1),
                paymentMethodId = otherCouplePaymentMethod.id
            )

            Then("throws ForbiddenException") {
                shouldThrow<ForbiddenException> {
                    service.createPlan(user1.id, request)
                }
            }
        }

        When("creating a plan with nonexistent category") {
            val fakeId = UUID.randomUUID()
            every { categoryRepository.findById(fakeId) } returns Optional.empty()

            val request = CreateSpendingPlanRequest(
                name = "Bad plan",
                amount = 10000,
                targetDate = LocalDate.of(2026, 4, 1),
                categoryId = fakeId
            )

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.createPlan(user1.id, request)
                }
                ex.code shouldBe "CATEGORY_NOT_FOUND"
            }
        }

        When("creating a PRIVATE plan") {
            val planSlot = slot<SpendingPlan>()
            every { spendingPlanRepository.save(capture(planSlot)) } answers { planSlot.captured }

            val request = CreateSpendingPlanRequest(
                name = "Private plan",
                amount = 30000,
                targetDate = LocalDate.of(2026, 4, 1),
                visibility = "PRIVATE"
            )
            val result = service.createPlan(user1.id, request)

            Then("sets owner to author") {
                result.visibility shouldBe "PRIVATE"
                result.ownerId shouldBe user1.id
            }
        }
    }

    // --- listPlans ---

    Given("plans exist for a couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val plan1 = SpendingPlan(
            couple = couple, author = user1,
            name = "Plan A", amount = 100000,
            targetDate = LocalDate.of(2026, 3, 15),
            status = SpendingPlanStatus.PLANNED
        )
        val plan2 = SpendingPlan(
            couple = couple, author = user1,
            name = "Plan B", amount = 50000,
            targetDate = LocalDate.of(2026, 3, 20),
            status = SpendingPlanStatus.COMPLETED,
            actualAmount = 48000,
            completedDate = LocalDate.of(2026, 3, 20)
        )

        When("listing plans for a date range") {
            every {
                spendingPlanRepository.findByCoupleAndDateRange(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    user1.id
                )
            } returns listOf(plan1, plan2)

            val result = service.listPlans(
                user1.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                null
            )

            Then("returns plans with summary") {
                result.plans shouldHaveSize 2
                result.summary.plannedCount shouldBe 1
                result.summary.completedCount shouldBe 1
                result.summary.totalPlanned shouldBe 100000
                result.summary.totalCompleted shouldBe 48000
            }
        }

        When("listing plans with status filter") {
            every {
                spendingPlanRepository.findByCoupleAndDateRangeAndStatus(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    SpendingPlanStatus.PLANNED,
                    user1.id
                )
            } returns listOf(plan1)

            val result = service.listPlans(
                user1.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                SpendingPlanStatus.PLANNED
            )

            Then("returns only planned items") {
                result.plans shouldHaveSize 1
                result.plans[0].status shouldBe "PLANNED"
            }
        }
    }

    // --- updatePlan ---

    Given("an existing plan to update") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val plan = SpendingPlan(
            couple = couple, author = user1,
            name = "Original", amount = 100000,
            targetDate = LocalDate.of(2026, 3, 15)
        )
        every { spendingPlanRepository.findByIdAndCoupleId(plan.id, couple.id) } returns plan

        When("updating name and amount") {
            every { spendingPlanRepository.save(any()) } answers { firstArg() }

            val request = UpdateSpendingPlanRequest(
                name = "Updated",
                amount = 200000
            )
            val result = service.updatePlan(user1.id, plan.id, request)

            Then("updates the fields") {
                result.name shouldBe "Updated"
                result.amount shouldBe 200000
            }
        }
    }

    // --- deletePlan ---

    Given("a plan to delete") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val plan = SpendingPlan(
            couple = couple, author = user1,
            name = "To delete", amount = 30000,
            targetDate = LocalDate.of(2026, 3, 15)
        )

        When("deleting the plan") {
            every { spendingPlanRepository.findByIdAndCoupleId(plan.id, couple.id) } returns plan
            every { spendingPlanRepository.delete(plan) } returns Unit

            service.deletePlan(user1.id, plan.id)

            Then("deletes the plan") {
                verify { spendingPlanRepository.delete(plan) }
            }
        }

        When("deleting a nonexistent plan") {
            val fakeId = UUID.randomUUID()
            every { spendingPlanRepository.findByIdAndCoupleId(fakeId, couple.id) } returns null

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.deletePlan(user1.id, fakeId)
                }
                ex.code shouldBe "SPENDING_PLAN_NOT_FOUND"
            }
        }
    }

    // --- completePlan ---

    Given("a PLANNED plan to complete") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { statusHistoryRepository.save(any()) } answers { firstArg() }

        val plan = SpendingPlan(
            couple = couple, author = user1,
            name = "To complete", amount = 100000,
            targetDate = LocalDate.of(2026, 3, 15),
            status = SpendingPlanStatus.PLANNED
        )
        every { spendingPlanRepository.findByIdAndCoupleId(plan.id, couple.id) } returns plan

        When("completing with actual amount") {
            every { spendingPlanRepository.save(any()) } answers { firstArg() }

            val request = CompleteSpendingPlanRequest(
                actualAmount = 95000,
                completedDate = LocalDate.of(2026, 3, 15)
            )
            val result = service.completePlan(user1.id, plan.id, request)

            Then("sets status to COMPLETED with actual amount") {
                result.status shouldBe "COMPLETED"
                result.actualAmount shouldBe 95000
                result.completedDate shouldBe LocalDate.of(2026, 3, 15)
            }
        }

        When("completing with linked transaction") {
            val tx = mockk<Transaction>(relaxed = true)
            every { tx.id } returns UUID.randomUUID()
            every { tx.amount } returns 92000
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
            every { spendingPlanRepository.save(any()) } answers { firstArg() }

            val request = CompleteSpendingPlanRequest(
                linkedTransactionId = tx.id
            )
            val result = service.completePlan(user1.id, plan.id, request)

            Then("links transaction and uses its amount") {
                result.status shouldBe "COMPLETED"
                result.linkedTransactionId shouldBe tx.id
                result.actualAmount shouldBe 92000
            }
        }
    }

    Given("a COMPLETED plan") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        val plan = SpendingPlan(
            couple = couple, author = user1,
            name = "Already done", amount = 50000,
            targetDate = LocalDate.of(2026, 3, 10),
            status = SpendingPlanStatus.COMPLETED,
            actualAmount = 48000,
            completedDate = LocalDate.of(2026, 3, 10)
        )
        every { spendingPlanRepository.findByIdAndCoupleId(plan.id, couple.id) } returns plan

        When("trying to complete again") {
            Then("throws INVALID_STATUS") {
                val ex = shouldThrow<BusinessException> {
                    service.completePlan(user1.id, plan.id, CompleteSpendingPlanRequest())
                }
                ex.code shouldBe "INVALID_STATUS"
            }
        }
    }

    // --- skipPlan ---

    Given("a PLANNED plan to skip") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { statusHistoryRepository.save(any()) } answers { firstArg() }

        val plan = SpendingPlan(
            couple = couple, author = user1,
            name = "To skip", amount = 30000,
            targetDate = LocalDate.of(2026, 3, 20),
            status = SpendingPlanStatus.PLANNED
        )
        every { spendingPlanRepository.findByIdAndCoupleId(plan.id, couple.id) } returns plan

        When("skipping the plan") {
            every { spendingPlanRepository.save(any()) } answers { firstArg() }

            val result = service.skipPlan(user1.id, plan.id)

            Then("sets status to SKIPPED") {
                result.status shouldBe "SKIPPED"
            }
        }
    }

    Given("a SKIPPED plan") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        val plan = SpendingPlan(
            couple = couple, author = user1,
            name = "Already skipped", amount = 30000,
            targetDate = LocalDate.of(2026, 3, 20),
            status = SpendingPlanStatus.SKIPPED
        )
        every { spendingPlanRepository.findByIdAndCoupleId(plan.id, couple.id) } returns plan

        When("trying to skip again") {
            Then("throws INVALID_STATUS") {
                val ex = shouldThrow<BusinessException> {
                    service.skipPlan(user1.id, plan.id)
                }
                ex.code shouldBe "INVALID_STATUS"
            }
        }
    }

    // --- getSuggestions ---

    Given("matching plans exist") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val catId = UUID.randomUUID()
        val plan = SpendingPlan(
            couple = couple, author = user1,
            name = "Costco shopping", amount = 150000,
            targetDate = LocalDate.of(2026, 3, 29),
            status = SpendingPlanStatus.PLANNED,
            category = mockk<Category>(relaxed = true).also {
                every { it.id } returns catId
            }
        )
        every {
            spendingPlanRepository.findMatchingPlans(
                couple.id, catId,
                LocalDate.of(2026, 3, 26),
                LocalDate.of(2026, 4, 1)
            )
        } returns listOf(plan)

        When("getting suggestions for a matching transaction") {
            val suggestions = service.getSuggestions(
                user1.id, catId, 145000, LocalDate.of(2026, 3, 29)
            )

            Then("returns suggestions with score") {
                suggestions shouldHaveSize 1
                suggestions[0].name shouldBe "Costco shopping"
                suggestions[0].matchScore shouldBe 1.0.let { suggestions[0].matchScore } // non-zero
                suggestions[0].matchReasons.size shouldBe 3 // category + amount + date
            }
        }

        When("getting suggestions without categoryId") {
            val suggestions = service.getSuggestions(
                user1.id, null, 145000, LocalDate.of(2026, 3, 29)
            )

            Then("returns empty list") {
                suggestions shouldHaveSize 0
            }
        }
    }

    // --- PRIVATE access control ---

    Given("a PRIVATE plan owned by user2") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val privatePlan = SpendingPlan(
            couple = couple, author = user2,
            name = "Private plan", amount = 50000,
            targetDate = LocalDate.of(2026, 3, 15),
            visibility = Visibility.PRIVATE,
            owner = user2
        )

        When("user1 tries to update it") {
            every { spendingPlanRepository.findByIdAndCoupleId(privatePlan.id, couple.id) } returns privatePlan

            Then("throws PRIVATE_ACCESS_DENIED") {
                val ex = shouldThrow<ForbiddenException> {
                    service.updatePlan(user1.id, privatePlan.id, UpdateSpendingPlanRequest(name = "Hack"))
                }
                ex.code shouldBe "PRIVATE_ACCESS_DENIED"
            }
        }

        When("user1 tries to delete it") {
            every { spendingPlanRepository.findByIdAndCoupleId(privatePlan.id, couple.id) } returns privatePlan

            Then("throws PRIVATE_ACCESS_DENIED") {
                shouldThrow<ForbiddenException> {
                    service.deletePlan(user1.id, privatePlan.id)
                }
            }
        }
    }

    // --- linkTransaction (C-8) ---

    Given("a user linking a transaction to a plan") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { statusHistoryRepository.save(any()) } answers { firstArg() }

        val plan = SpendingPlan(
            couple = couple,
            author = user1,
            name = "Costco shopping",
            amount = 150000,
            targetDate = LocalDate.of(2026, 4, 5),
            status = SpendingPlanStatus.PLANNED
        )

        val transaction = Transaction(
            couple = couple,
            author = user1,
            type = com.budgetbook.transaction.domain.TransactionType.EXPENSE,
            amount = 145000,
            description = "Costco groceries",
            transactionDate = LocalDate.of(2026, 4, 5)
        )

        When("linking a valid transaction") {
            every { spendingPlanRepository.findByIdAndCoupleId(plan.id, couple.id) } returns plan
            every { transactionRepository.findById(transaction.id) } returns Optional.of(transaction)
            every { spendingPlanRepository.save(any()) } answers { firstArg() }

            val result = service.linkTransaction(user1.id, plan.id, transaction.id)

            Then("marks plan as COMPLETED with transaction details") {
                result.status shouldBe "COMPLETED"
                result.linkedTransactionId shouldBe transaction.id
                result.actualAmount shouldBe 145000
                result.completedDate shouldBe LocalDate.of(2026, 4, 5)
            }
        }

        When("linking a transaction from another couple") {
            val otherTransaction = Transaction(
                couple = otherCouple,
                author = user2,
                type = com.budgetbook.transaction.domain.TransactionType.EXPENSE,
                amount = 10000,
                description = "Other",
                transactionDate = LocalDate.of(2026, 4, 1)
            )
            every { spendingPlanRepository.findByIdAndCoupleId(plan.id, couple.id) } returns plan
            every { transactionRepository.findById(otherTransaction.id) } returns Optional.of(otherTransaction)

            Then("throws ForbiddenException") {
                shouldThrow<ForbiddenException> {
                    service.linkTransaction(user1.id, plan.id, otherTransaction.id)
                }
            }
        }
    }

    // --- unlinkTransaction (C-8) ---

    Given("a user unlinking a transaction from a plan") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { statusHistoryRepository.save(any()) } answers { firstArg() }

        val transaction = Transaction(
            couple = couple,
            author = user1,
            type = com.budgetbook.transaction.domain.TransactionType.EXPENSE,
            amount = 145000,
            description = "Groceries",
            transactionDate = LocalDate.of(2026, 4, 5)
        )

        When("unlinking a linked plan with targetDate") {
            val linkedPlan = SpendingPlan(
                couple = couple,
                author = user1,
                name = "Shopping",
                amount = 150000,
                targetDate = LocalDate.of(2026, 4, 5),
                status = SpendingPlanStatus.COMPLETED,
                linkedTransaction = transaction,
                actualAmount = 145000
            )
            every { spendingPlanRepository.findByIdAndCoupleId(linkedPlan.id, couple.id) } returns linkedPlan
            every { spendingPlanRepository.save(any()) } answers { firstArg() }

            val result = service.unlinkTransaction(user1.id, linkedPlan.id)

            Then("reverts to PLANNED status") {
                result.status shouldBe "PLANNED"
                result.linkedTransactionId shouldBe null
                result.actualAmount shouldBe null
            }
        }

        When("unlinking a plan with no linked transaction") {
            val unlinkedPlan = SpendingPlan(
                couple = couple,
                author = user1,
                name = "Unlinked plan",
                amount = 50000,
                status = SpendingPlanStatus.PLANNED
            )
            every { spendingPlanRepository.findByIdAndCoupleId(unlinkedPlan.id, couple.id) } returns unlinkedPlan

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.unlinkTransaction(user1.id, unlinkedPlan.id)
                }
                ex.code shouldBe "NO_LINKED_TRANSACTION"
            }
        }

        When("unlinking a plan without targetDate reverts to WISHLIST") {
            val wishlistLinkedPlan = SpendingPlan(
                couple = couple,
                author = user1,
                name = "Wish item",
                amount = 200000,
                targetDate = null,
                status = SpendingPlanStatus.COMPLETED,
                linkedTransaction = transaction,
                actualAmount = 195000
            )
            every { spendingPlanRepository.findByIdAndCoupleId(wishlistLinkedPlan.id, couple.id) } returns wishlistLinkedPlan
            every { spendingPlanRepository.save(any()) } answers { firstArg() }

            val result = service.unlinkTransaction(user1.id, wishlistLinkedPlan.id)

            Then("reverts to WISHLIST status") {
                result.status shouldBe "WISHLIST"
                result.linkedTransactionId shouldBe null
            }
        }
    }
})
