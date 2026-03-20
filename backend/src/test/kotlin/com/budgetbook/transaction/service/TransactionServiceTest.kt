package com.budgetbook.transaction.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.dto.PatchValue
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.sync.SyncEventPublisher
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
    val coupleResolver = mockk<CoupleResolver>()
    val userRepository = mockk<UserRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val paymentMethodRepository = mockk<PaymentMethodRepository>()
    val moneyPocketRepository = mockk<MoneyPocketRepository>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val service = TransactionService(transactionRepository, coupleResolver, userRepository, categoryRepository, paymentMethodRepository, moneyPocketRepository, syncEventPublisher)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val category = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF5733", isDefault = true)

    // --- createTransaction ---

    Given("a user in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
                    id = category.id, name = "식비", type = "EXPENSE", icon = "restaurant", color = "#FF5733",
                    groupId = null, groupName = null
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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

    Given("an existing transaction with a category to clear") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심", category = category,
            transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.save(tx) } returns tx

        When("updateTransaction is called with categoryId = PatchValue(null)") {
            val request = UpdateTransactionRequest(categoryId = PatchValue(null))
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("clears the category") {
                result.category shouldBe null
            }
        }

        When("updateTransaction is called with categoryId absent") {
            val request = UpdateTransactionRequest(amount = 20000)
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("keeps the existing category") {
                result.category shouldBe com.budgetbook.transaction.dto.CategorySummary(
                    id = category.id, name = "식비", type = "EXPENSE", icon = "restaurant", color = "#FF5733",
                    groupId = null, groupName = null
                )
            }
        }
    }

    Given("an existing transaction with a payment method to clear") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val pm = PaymentMethod(couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT, settlementDay = 15, closingDay = 25)
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심", paymentMethod = pm,
            settlementDate = LocalDate.of(2024, 2, 15),
            transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.save(tx) } returns tx

        When("updateTransaction is called with paymentMethodId = PatchValue(null)") {
            val request = UpdateTransactionRequest(paymentMethodId = PatchValue(null))
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("clears the payment method and settlement date") {
                result.paymentMethodId shouldBe null
                result.settlementDate shouldBe null
            }
        }
    }

    Given("a transaction with a credit card where transactionDate changes") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val pm = PaymentMethod(couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT, settlementDay = 15, closingDay = 25)
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심", paymentMethod = pm,
            settlementDate = LocalDate.of(2024, 2, 15),
            transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.save(tx) } returns tx

        When("updateTransaction changes transactionDate without changing paymentMethod") {
            // Moving transaction date to after closing day (25th) should push settlement to month+2
            val request = UpdateTransactionRequest(transactionDate = LocalDate.of(2024, 1, 26))
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("recalculates the settlement date") {
                // transactionDate = Jan 26, closingDay = 25, dayOfMonth(26) > 25 -> settlement month+2 = March 15
                result.settlementDate shouldBe "2024-03-15"
            }
        }
    }

    Given("a transaction with a DEBIT card where transactionDate changes") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val pm = PaymentMethod(couple = couple, name = "체크카드", type = PaymentMethodType.DEBIT)
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 20000, description = "마트", paymentMethod = pm,
            settlementDate = null,
            transactionDate = LocalDate.of(2024, 1, 10)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.save(tx) } returns tx

        When("updateTransaction changes transactionDate without changing paymentMethod") {
            val request = UpdateTransactionRequest(transactionDate = LocalDate.of(2024, 1, 20))
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("settlementDate remains null for non-CREDIT payment method") {
                result.settlementDate shouldBe null
            }
        }
    }

    Given("a transaction with CASH (no payment method) where transactionDate changes") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 5000, description = "편의점", paymentMethod = null,
            settlementDate = null,
            transactionDate = LocalDate.of(2024, 1, 10)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.save(tx) } returns tx

        When("updateTransaction changes transactionDate") {
            val request = UpdateTransactionRequest(transactionDate = LocalDate.of(2024, 1, 20))
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("settlementDate remains null") {
                result.settlementDate shouldBe null
            }
        }
    }

    // --- deleteTransaction ---

    Given("a transaction to delete") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
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
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

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
            couple.id, LocalDate.of(2024, 1, 1), LocalDate.of(2024, 1, 31), null, null, user1.id, any()
        ) } returns page

        When("listTransactions is called for January 2024 without extended filters") {
            val result = service.listTransactions(user1.id, 2024, 1, null, null, null, null, null, null, null, 0, 20)

            Then("returns paginated results using legacy query") {
                result.content.size shouldBe 2
                result.totalElements shouldBe 2
                result.page shouldBe 0
                result.first shouldBe true
                result.last shouldBe true
            }
        }
    }

    Given("transactions exist and keyword filter is used") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val tx1 = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심 식사", transactionDate = LocalDate.of(2024, 1, 15)
        )
        val page = PageImpl(listOf(tx1), PageRequest.of(0, 20), 1)
        every { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) } returns page

        When("listTransactions is called with keyword filter") {
            val result = service.listTransactions(user1.id, 2024, 1, null, null, "점심", null, null, null, null, 0, 20)

            Then("returns filtered results via specification") {
                result.content.size shouldBe 1
                result.totalElements shouldBe 1
            }
        }
    }

    Given("transactions exist and amount range filter is used") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val tx1 = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 20000, description = "저녁", transactionDate = LocalDate.of(2024, 1, 15)
        )
        val page = PageImpl(listOf(tx1), PageRequest.of(0, 20), 1)
        every { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) } returns page

        When("listTransactions is called with amountMin and amountMax") {
            val result = service.listTransactions(user1.id, 2024, 1, null, null, null, null, null, 10000, 50000, 0, 20)

            Then("returns filtered results via specification") {
                result.content.size shouldBe 1
            }
        }
    }

    // --- getSuggestions ---

    Given("a user requesting description suggestions") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("matching descriptions exist") {
            every { transactionRepository.findDistinctDescriptionsByQuery(couple.id, "점", user1.id, 10) } returns listOf("점심 식사", "점심 도시락")

            val result = service.getSuggestions(user1.id, "점", 10)

            Then("returns matching descriptions") {
                result.size shouldBe 2
                result shouldBe listOf("점심 식사", "점심 도시락")
            }
        }

        When("no matching descriptions exist") {
            every { transactionRepository.findDistinctDescriptionsByQuery(couple.id, "없는", user1.id, 10) } returns emptyList()

            val result = service.getSuggestions(user1.id, "없는", 10)

            Then("returns empty list") {
                result shouldBe emptyList()
            }
        }

        When("limit exceeds max") {
            every { transactionRepository.findDistinctDescriptionsByQuery(couple.id, "점", user1.id, 50) } returns listOf("점심")

            val result = service.getSuggestions(user1.id, "점", 100)

            Then("clamps limit to 50") {
                verify(exactly = 1) { transactionRepository.findDistinctDescriptionsByQuery(couple.id, "점", user1.id, 50) }
                result shouldBe listOf("점심")
            }
        }

        When("limit is zero or negative") {
            every { transactionRepository.findDistinctDescriptionsByQuery(couple.id, "점", user1.id, 1) } returns listOf("점심")

            val result = service.getSuggestions(user1.id, "점", 0)

            Then("clamps limit to 1") {
                verify(exactly = 1) { transactionRepository.findDistinctDescriptionsByQuery(couple.id, "점", user1.id, 1) }
                result shouldBe listOf("점심")
            }
        }
    }

    // --- PRIVATE category forces PRIVATE transaction ---

    Given("a user creating a transaction with a PRIVATE category") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        val privateCategory = Category(
            couple = couple, name = "용돈", type = CategoryType.EXPENSE,
            icon = "money", color = "#FF9800", isDefault = false,
            visibility = Visibility.PRIVATE, owner = user1
        )
        every { categoryRepository.findById(privateCategory.id) } returns Optional.of(privateCategory)

        When("creating a transaction with visibility SHARED but PRIVATE category") {
            val request = CreateTransactionRequest(
                type = "EXPENSE", amount = 5000, description = "개인 지출",
                categoryId = privateCategory.id, transactionDate = LocalDate.of(2024, 1, 15),
                visibility = "SHARED"
            )
            val txSlot = slot<Transaction>()
            every { transactionRepository.save(capture(txSlot)) } answers { txSlot.captured }

            val result = service.createTransaction(user1.id, request)

            Then("forces the transaction to PRIVATE") {
                result.visibility shouldBe "PRIVATE"
                result.ownerId shouldBe user1.id
            }
        }
    }

    Given("an existing SHARED transaction being updated to a PRIVATE category") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심", transactionDate = LocalDate.of(2024, 1, 15),
            visibility = Visibility.SHARED, owner = null
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.save(tx) } returns tx

        val privateCategory = Category(
            couple = couple, name = "용돈", type = CategoryType.EXPENSE,
            icon = "money", color = "#FF9800", isDefault = false,
            visibility = Visibility.PRIVATE, owner = user1
        )
        every { categoryRepository.findById(privateCategory.id) } returns Optional.of(privateCategory)

        When("updateTransaction changes category to a PRIVATE one") {
            val request = UpdateTransactionRequest(categoryId = PatchValue(privateCategory.id))
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("forces the transaction to PRIVATE") {
                result.visibility shouldBe "PRIVATE"
                result.ownerId shouldBe user1.id
            }
        }
    }

    Given("transactions exist and paymentMethodId filter is used") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val pmId = UUID.randomUUID()

        val tx1 = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "카드 결제", transactionDate = LocalDate.of(2024, 1, 15)
        )
        val page = PageImpl(listOf(tx1), PageRequest.of(0, 20), 1)
        every { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) } returns page

        When("listTransactions is called with paymentMethodId") {
            val result = service.listTransactions(user1.id, 2024, 1, null, null, null, pmId, null, null, null, 0, 20)

            Then("returns filtered results via specification") {
                result.content.size shouldBe 1
            }
        }
    }
})
