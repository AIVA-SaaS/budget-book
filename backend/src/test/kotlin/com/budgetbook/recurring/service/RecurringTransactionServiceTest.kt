package com.budgetbook.recurring.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.recurring.domain.Frequency
import com.budgetbook.recurring.domain.RecurringTransaction
import com.budgetbook.recurring.dto.CreateRecurringTransactionRequest
import com.budgetbook.recurring.dto.UpdateRecurringTransactionRequest
import com.budgetbook.recurring.repository.RecurringTransactionRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.time.LocalDate
import java.time.YearMonth
import java.util.Optional
import java.util.UUID

class RecurringTransactionServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val recurringRepository = mockk<RecurringTransactionRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val userRepository = mockk<UserRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val paymentMethodRepository = mockk<PaymentMethodRepository>()
    val service = RecurringTransactionService(
        recurringRepository, transactionRepository, coupleRepository,
        userRepository, categoryRepository, paymentMethodRepository
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val category = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF5733", isDefault = true)

    // --- createRecurringTransaction ---

    Given("a user in an active couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        When("creating a MONTHLY recurring transaction") {
            val request = CreateRecurringTransactionRequest(
                type = "EXPENSE",
                amount = 50000,
                description = "월세",
                frequency = "MONTHLY",
                dayOfMonth = 25
            )
            val slot = slot<RecurringTransaction>()
            every { recurringRepository.save(capture(slot)) } answers { slot.captured }

            val result = service.createRecurringTransaction(user1.id, request)

            Then("creates recurring transaction with correct fields") {
                result.type shouldBe "EXPENSE"
                result.amount shouldBe 50000
                result.description shouldBe "월세"
                result.frequency shouldBe "MONTHLY"
                result.dayOfMonth shouldBe 25
                result.isActive shouldBe true
            }
        }

        When("creating a WEEKLY recurring transaction") {
            val request = CreateRecurringTransactionRequest(
                type = "EXPENSE",
                amount = 10000,
                description = "주간 장보기",
                frequency = "WEEKLY",
                dayOfWeek = 6 // Saturday
            )
            val slot = slot<RecurringTransaction>()
            every { recurringRepository.save(capture(slot)) } answers { slot.captured }

            val result = service.createRecurringTransaction(user1.id, request)

            Then("creates recurring transaction with correct fields") {
                result.type shouldBe "EXPENSE"
                result.amount shouldBe 10000
                result.frequency shouldBe "WEEKLY"
                result.dayOfWeek shouldBe 6
            }
        }

        When("creating a DAILY recurring transaction") {
            val request = CreateRecurringTransactionRequest(
                type = "EXPENSE",
                amount = 5000,
                description = "일일 간식",
                frequency = "DAILY"
            )
            val slot = slot<RecurringTransaction>()
            every { recurringRepository.save(capture(slot)) } answers { slot.captured }

            val result = service.createRecurringTransaction(user1.id, request)

            Then("creates recurring transaction with correct fields") {
                result.frequency shouldBe "DAILY"
                result.amount shouldBe 5000
            }
        }

        When("creating a MONTHLY recurring without dayOfMonth") {
            val request = CreateRecurringTransactionRequest(
                type = "EXPENSE",
                amount = 50000,
                description = "월세",
                frequency = "MONTHLY"
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.createRecurringTransaction(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("creating a WEEKLY recurring without dayOfWeek") {
            val request = CreateRecurringTransactionRequest(
                type = "EXPENSE",
                amount = 10000,
                description = "주간 장보기",
                frequency = "WEEKLY"
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.createRecurringTransaction(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("creating with invalid frequency") {
            val request = CreateRecurringTransactionRequest(
                type = "EXPENSE",
                amount = 10000,
                description = "Test",
                frequency = "BIWEEKLY"
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.createRecurringTransaction(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("creating with a category") {
            every { categoryRepository.findById(category.id) } returns Optional.of(category)
            val request = CreateRecurringTransactionRequest(
                type = "EXPENSE",
                amount = 50000,
                description = "월세",
                frequency = "MONTHLY",
                dayOfMonth = 25,
                categoryId = category.id
            )
            val slot = slot<RecurringTransaction>()
            every { recurringRepository.save(capture(slot)) } answers { slot.captured }

            val result = service.createRecurringTransaction(user1.id, request)

            Then("creates with category attached") {
                result.category shouldNotBe null
                result.category!!.id shouldBe category.id
            }
        }
    }

    // --- listRecurringTransactions ---

    Given("recurring transactions exist for couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val recurring1 = RecurringTransaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 50000, description = "월세", frequency = Frequency.MONTHLY,
            dayOfMonth = 25, nextRunDate = LocalDate.of(2026, 4, 25)
        )
        val recurring2 = RecurringTransaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 10000, description = "주간 장보기", frequency = Frequency.WEEKLY,
            dayOfWeek = 6, nextRunDate = LocalDate.of(2026, 3, 14)
        )
        every { recurringRepository.findByCoupleId(couple.id) } returns listOf(recurring1, recurring2)

        When("listRecurringTransactions is called") {
            val result = service.listRecurringTransactions(user1.id)

            Then("returns all recurring transactions") {
                result.size shouldBe 2
                result[0].description shouldBe "월세"
                result[1].description shouldBe "주간 장보기"
            }
        }
    }

    // --- updateRecurringTransaction ---

    Given("an existing recurring transaction to update") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val recurring = RecurringTransaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 50000, description = "월세", frequency = Frequency.MONTHLY,
            dayOfMonth = 25, nextRunDate = LocalDate.of(2026, 4, 25)
        )
        every { recurringRepository.findById(recurring.id) } returns Optional.of(recurring)
        every { recurringRepository.save(recurring) } returns recurring

        When("updating amount and description") {
            val request = UpdateRecurringTransactionRequest(amount = 55000, description = "월세 인상")
            val result = service.updateRecurringTransaction(user1.id, recurring.id, request)

            Then("updates the fields") {
                result.amount shouldBe 55000
                result.description shouldBe "월세 인상"
            }
        }

        When("deactivating the recurring transaction") {
            val request = UpdateRecurringTransactionRequest(isActive = false)
            val result = service.updateRecurringTransaction(user1.id, recurring.id, request)

            Then("sets isActive to false") {
                result.isActive shouldBe false
            }
        }
    }

    Given("a recurring transaction from a different couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val otherCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)
        val recurring = RecurringTransaction(
            couple = otherCouple, author = user2, type = TransactionType.EXPENSE,
            amount = 50000, description = "월세", frequency = Frequency.MONTHLY,
            dayOfMonth = 25, nextRunDate = LocalDate.of(2026, 4, 25)
        )
        every { recurringRepository.findById(recurring.id) } returns Optional.of(recurring)

        When("updating the recurring transaction") {
            Then("throws ForbiddenException") {
                shouldThrow<ForbiddenException> {
                    service.updateRecurringTransaction(user1.id, recurring.id, UpdateRecurringTransactionRequest(amount = 55000))
                }
            }
        }
    }

    // --- deleteRecurringTransaction ---

    Given("a recurring transaction to delete") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val recurring = RecurringTransaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 50000, description = "월세", frequency = Frequency.MONTHLY,
            dayOfMonth = 25, nextRunDate = LocalDate.of(2026, 4, 25)
        )
        every { recurringRepository.findById(recurring.id) } returns Optional.of(recurring)
        every { recurringRepository.delete(recurring) } returns Unit

        When("deleteRecurringTransaction is called") {
            service.deleteRecurringTransaction(user1.id, recurring.id)

            Then("deletes the recurring transaction") {
                verify(exactly = 1) { recurringRepository.delete(recurring) }
            }
        }
    }

    // --- executeRecurringTransactions ---

    Given("due recurring transactions to execute") {
        val today = LocalDate.now()
        val recurring1 = RecurringTransaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 50000, description = "월세", frequency = Frequency.MONTHLY,
            dayOfMonth = today.dayOfMonth, nextRunDate = today
        )
        val recurring2 = RecurringTransaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 10000, description = "주간 장보기", frequency = Frequency.WEEKLY,
            dayOfWeek = today.dayOfWeek.value, nextRunDate = today
        )
        val recurring3 = RecurringTransaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 5000, description = "일일 간식", frequency = Frequency.DAILY,
            nextRunDate = today
        )

        every { recurringRepository.findByNextRunDateLessThanEqualAndIsActiveTrue(today) } returns
            listOf(recurring1, recurring2, recurring3)

        val txSlot = mutableListOf<Transaction>()
        every { transactionRepository.save(capture(txSlot)) } answers { txSlot.last() }
        every { recurringRepository.save(any()) } answers { firstArg() }

        When("executeRecurringTransactions is called") {
            service.executeRecurringTransactions()

            Then("creates transactions for each due recurring") {
                txSlot.size shouldBe 3
                txSlot[0].amount shouldBe 50000
                txSlot[0].description shouldBe "월세"
                txSlot[1].amount shouldBe 10000
                txSlot[2].amount shouldBe 5000
            }

            Then("advances nextRunDate for MONTHLY") {
                val expectedNextMonth = YearMonth.of(today.year, today.monthValue).plusMonths(1)
                val expectedDay = recurring1.dayOfMonth!!.coerceAtMost(expectedNextMonth.lengthOfMonth())
                recurring1.nextRunDate shouldBe expectedNextMonth.atDay(expectedDay)
                recurring1.lastRunDate shouldBe today
            }

            Then("advances nextRunDate for WEEKLY by 7 days") {
                recurring2.nextRunDate shouldBe today.plusDays(7)
                recurring2.lastRunDate shouldBe today
            }

            Then("advances nextRunDate for DAILY by 1 day") {
                recurring3.nextRunDate shouldBe today.plusDays(1)
                recurring3.lastRunDate shouldBe today
            }
        }
    }

    // --- calculateNextRunDate ---

    Given("a MONTHLY recurring transaction at end of month") {
        val recurring = RecurringTransaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 50000, description = "Test", frequency = Frequency.MONTHLY,
            dayOfMonth = 31, nextRunDate = LocalDate.of(2026, 1, 31)
        )

        When("calculateNextRunDate is called") {
            val next = service.calculateNextRunDate(recurring)

            Then("handles month overflow correctly (Feb has 28 days)") {
                next shouldBe LocalDate.of(2026, 2, 28)
            }
        }
    }

    Given("a YEARLY recurring transaction") {
        val recurring = RecurringTransaction(
            couple = couple, author = user1, type = TransactionType.INCOME,
            amount = 1000000, description = "연간 보너스", frequency = Frequency.YEARLY,
            dayOfMonth = 15, nextRunDate = LocalDate.of(2026, 3, 15)
        )

        When("calculateNextRunDate is called") {
            val next = service.calculateNextRunDate(recurring)

            Then("advances to same date next year") {
                next shouldBe LocalDate.of(2027, 3, 15)
            }
        }
    }

    // --- user not in couple ---

    Given("a user not in any couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("listRecurringTransactions is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.listRecurringTransactions(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }
})
