package com.budgetbook.transaction.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.dto.PatchValue
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CreateTransactionRequest
import com.budgetbook.transaction.dto.UpdateTransactionRequest
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
import org.springframework.data.domain.PageRequest
import java.time.LocalDate
import java.util.Optional
import java.util.UUID

class TransactionServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val userRepository = mockk<UserRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val paymentMethodRepository = mockk<PaymentMethodRepository>()
    val service = TransactionService(transactionRepository, coupleRepository, userRepository, categoryRepository, paymentMethodRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val category = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF5733", isDefault = true)

    // --- createTransaction ---

    Given("a user in an active couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        When("creating a transaction without category") {
            val request = CreateTransactionRequest(
                type = "EXPENSE", amount = 15000, description = "점심 식사",
                transactionDate = LocalDate.of(2024, 1, 15)
            )
            val txSlot = slot<Transaction>()
            every { transactionRepository.save(capture(txSlot)) } answers { txSlot.captured }

            val result = service.createTransaction(user1.id, request)

            Then("creates transaction with correct fields") {
                result.type shouldBe "EXPENSE"
                result.amount shouldBe 15000
                result.description shouldBe "점심 식사"
                result.category shouldBe null
                result.author.id shouldBe user1.id
            }
        }

        When("creating a transaction with a valid category") {
            every { categoryRepository.findById(category.id) } returns Optional.of(category)
            val request = CreateTransactionRequest(
                type = "EXPENSE", amount = 10000, description = "저녁",
                categoryId = category.id, transactionDate = LocalDate.of(2024, 1, 15)
            )
            val txSlot = slot<Transaction>()
            every { transactionRepository.save(capture(txSlot)) } answers { txSlot.captured }

            val result = service.createTransaction(user1.id, request)

            Then("includes category in response") {
                result.category shouldBe com.budgetbook.transaction.dto.CategorySummary(
                    id = category.id, name = "식비", type = "EXPENSE", icon = "restaurant", color = "#FF5733"
                )
            }
        }

        When("creating with a category from a different couple") {
            val otherCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)
            val otherCat = Category(couple = otherCouple, name = "Other", type = CategoryType.EXPENSE)
            every { categoryRepository.findById(otherCat.id) } returns Optional.of(otherCat)

            val request = CreateTransactionRequest(
                type = "EXPENSE", amount = 5000, description = "Test",
                categoryId = otherCat.id, transactionDate = LocalDate.of(2024, 1, 15)
            )

            Then("throws ForbiddenException") {
                val ex = shouldThrow<ForbiddenException> {
                    service.createTransaction(user1.id, request)
                }
                ex.code shouldBe "FORBIDDEN"
            }
        }
    }

    // --- getTransaction ---

    Given("an existing transaction in the user's couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심", transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)

        When("getTransaction is called") {
            val result = service.getTransaction(user1.id, tx.id)

            Then("returns the transaction") {
                result.id shouldBe tx.id
                result.amount shouldBe 15000
            }
        }
    }

    Given("a transaction from a different couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val otherCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)
        val tx = Transaction(
            couple = otherCouple, author = user2, type = TransactionType.INCOME,
            amount = 5000, description = "Test", transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)

        When("getTransaction is called") {
            Then("throws ForbiddenException") {
                shouldThrow<ForbiddenException> { service.getTransaction(user1.id, tx.id) }
            }
        }
    }

    Given("a non-existent transaction") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val fakeId = UUID.randomUUID()
        every { transactionRepository.findById(fakeId) } returns Optional.empty()

        When("getTransaction is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> { service.getTransaction(user1.id, fakeId) }
                ex.code shouldBe "TRANSACTION_NOT_FOUND"
            }
        }
    }

    // --- updateTransaction ---

    Given("an existing transaction to update") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심", transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.save(tx) } returns tx

        When("updateTransaction is called with new values") {
            val request = UpdateTransactionRequest(amount = 18000, description = "점심 + 커피")
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("updates the fields") {
                result.amount shouldBe 18000
                result.description shouldBe "점심 + 커피"
            }
        }
    }

    Given("an existing transaction with memo to clear") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심", memo = "기존 메모",
            transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.save(tx) } returns tx

        When("updateTransaction is called with memo = PatchValue(null)") {
            val request = UpdateTransactionRequest(memo = PatchValue(null))
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("clears the memo") {
                result.memo shouldBe null
            }
        }

        When("updateTransaction is called with memo absent (null)") {
            val request = UpdateTransactionRequest(amount = 20000)
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("keeps the existing memo") {
                result.memo shouldBe "기존 메모"
            }
        }
    }

    // --- deleteTransaction ---

    Given("a transaction to delete") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "삭제", transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.delete(tx) } returns Unit

        When("deleteTransaction is called") {
            service.deleteTransaction(user1.id, tx.id)

            Then("deletes the transaction") {
                verify(exactly = 1) { transactionRepository.delete(tx) }
            }
        }
    }

    // --- listTransactions ---

    Given("transactions exist for the user's couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val tx1 = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심", transactionDate = LocalDate.of(2024, 1, 15)
        )
        val tx2 = Transaction(
            couple = couple, author = user2, type = TransactionType.INCOME,
            amount = 3000000, description = "급여", transactionDate = LocalDate.of(2024, 1, 25)
        )
        val page = PageImpl(listOf(tx2, tx1), PageRequest.of(0, 20), 2)
        every { transactionRepository.findByCoupleIdAndFilters(
            couple.id, LocalDate.of(2024, 1, 1), LocalDate.of(2024, 1, 31), null, null, any()
        ) } returns page

        When("listTransactions is called for January 2024") {
            val result = service.listTransactions(user1.id, 2024, 1, null, null, 0, 20)

            Then("returns paginated results") {
                result.content.size shouldBe 2
                result.totalElements shouldBe 2
                result.page shouldBe 0
                result.first shouldBe true
                result.last shouldBe true
            }
        }
    }
})
