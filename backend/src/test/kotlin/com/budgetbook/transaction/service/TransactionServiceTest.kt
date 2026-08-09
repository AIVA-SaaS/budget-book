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
import com.budgetbook.smart.service.PatternLearningService
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CreateTransactionRequest
import com.budgetbook.transaction.dto.UpdateTransactionRequest
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.repository.TransferRepository
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
    val patternLearningService = mockk<PatternLearningService>(relaxed = true)
    val transferRepository = mockk<TransferRepository>()
    // V65 — 목록 응답의 정산 배지 벌크 조회. 기본은 "정산 기록 없음".
    val reconciliationLookup =
        mockk<com.budgetbook.reconciliation.service.ReconciliationLookup>(relaxed = true)
    val transferService = mockk<com.budgetbook.transfer.service.TransferService>()
    val spendingPlanRepository =
        mockk<com.budgetbook.spendingplan.repository.SpendingPlanRepository>(relaxed = true)
    val service = TransactionService(transactionRepository, coupleResolver, userRepository, categoryRepository, paymentMethodRepository, moneyPocketRepository, syncEventPublisher, patternLearningService, transferRepository, reconciliationLookup, transferService, spendingPlanRepository)

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
            val result = service.listTransactions(user1.id, 2024, 1, null, null, null, null, null, null, null, null, null, null, 0, 20)

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
            val result = service.listTransactions(user1.id, 2024, 1, null, null, "점심", null, null, null, null, null, null, null, 0, 20)

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
            val result = service.listTransactions(user1.id, 2024, 1, null, null, null, null, null, 10000, 50000, null, null, null, 0, 20)

            Then("returns filtered results via specification") {
                result.content.size shouldBe 1
            }
        }
    }

    // --- getSuggestions ---

    Given("a user requesting description suggestions") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("matching descriptions exist") {
            every { transactionRepository.findSuggestionPatterns(couple.id, "점심", any(), any()) } returns listOf(
                arrayOf<Any?>("점심 식사", null, null, null, null, null, null, null, 3L),
                arrayOf<Any?>("점심 도시락", null, null, null, null, null, null, null, 1L)
            )

            val result = service.getSuggestions(user1.id, "점심", 10)

            Then("returns matching descriptions as SuggestionResponse") {
                result.size shouldBe 2
                result[0].description shouldBe "점심 식사"
                result[1].description shouldBe "점심 도시락"
            }
        }

        When("no matching descriptions exist") {
            every { transactionRepository.findSuggestionPatterns(couple.id, "없는것", any(), any()) } returns emptyList()

            val result = service.getSuggestions(user1.id, "없는것", 10)

            Then("returns empty list") {
                result shouldBe emptyList()
            }
        }

        When("limit exceeds max") {
            every { transactionRepository.findSuggestionPatterns(couple.id, "점심", any(), any()) } returns listOf(
                arrayOf<Any?>("점심", null, null, null, null, null, null, null, 1L)
            )

            val result = service.getSuggestions(user1.id, "점심", 100)

            Then("clamps limit to 20") {
                result.size shouldBe 1
                result[0].description shouldBe "점심"
            }
        }

        When("limit is zero or negative") {
            every { transactionRepository.findSuggestionPatterns(couple.id, "점심", any(), any()) } returns listOf(
                arrayOf<Any?>("점심 식사", null, null, null, null, null, null, null, 5L),
                arrayOf<Any?>("점심 도시락", null, null, null, null, null, null, null, 2L)
            )

            val result = service.getSuggestions(user1.id, "점심", 0)

            Then("clamps limit to 1 and returns only one result") {
                result.size shouldBe 1
                result[0].description shouldBe "점심 식사"
            }
        }

        When("query is shorter than 2 characters") {
            val result = service.getSuggestions(user1.id, "점", 10)

            Then("returns empty list without querying") {
                result shouldBe emptyList()
            }
        }

        When("one description has more than 3 patterns") {
            every { transactionRepository.findSuggestionPatterns(couple.id, "점심", any(), any()) } returns listOf(
                arrayOf<Any?>("점심", null, null, null, null, null, null, null, 5L),
                arrayOf<Any?>("점심", null, null, null, null, null, null, null, 4L),
                arrayOf<Any?>("점심", null, null, null, null, null, null, null, 3L),
                arrayOf<Any?>("점심", null, null, null, null, null, null, null, 2L),
                arrayOf<Any?>("점심", null, null, null, null, null, null, null, 1L)
            )

            val result = service.getSuggestions(user1.id, "점심", 10)

            Then("caps patterns at 3 per description") {
                result.size shouldBe 1
                result[0].patterns.size shouldBe 3
            }
        }

        When("a transaction type is given") {
            every { transactionRepository.findSuggestionPatterns(couple.id, "점심", any(), TransactionType.INCOME) } returns listOf(
                arrayOf<Any?>("점심 정산", null, null, null, null, null, null, null, 2L)
            )

            val result = service.getSuggestions(user1.id, "점심", 10, TransactionType.INCOME)

            Then("forwards the type filter to the repository") {
                result.size shouldBe 1
                result[0].description shouldBe "점심 정산"
                verify { transactionRepository.findSuggestionPatterns(couple.id, "점심", any(), TransactionType.INCOME) }
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
                categoryId = privateCategory.id, transactionDate = LocalDate.of(2024, 1, 15)
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

    Given("transactions exist and dateFrom/dateTo filter is used") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val tx1 = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "1월 지출", transactionDate = LocalDate.of(2024, 1, 15)
        )
        val tx2 = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 20000, description = "3월 지출", transactionDate = LocalDate.of(2024, 3, 10)
        )
        val page = PageImpl(listOf(tx2, tx1), PageRequest.of(0, 20), 2)
        every { transactionRepository.findByCoupleIdAndFilters(
            couple.id, LocalDate.of(2024, 1, 1), LocalDate.of(2024, 3, 31), null, null, user1.id, any()
        ) } returns page

        When("listTransactions is called with dateFrom and dateTo spanning multiple months") {
            val result = service.listTransactions(
                user1.id, null, null, null, null, null, null, null, null, null,
                LocalDate.of(2024, 1, 1), LocalDate.of(2024, 3, 31), null, 0, 20
            )

            Then("returns transactions in the date range, ignoring year/month") {
                result.content.size shouldBe 2
                result.totalElements shouldBe 2
            }
        }
    }

    Given("dateFrom only is provided") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val tx1 = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "지출", transactionDate = LocalDate.of(2024, 6, 15)
        )
        val page = PageImpl(listOf(tx1), PageRequest.of(0, 20), 1)
        every { transactionRepository.findByCoupleIdAndFilters(
            couple.id, LocalDate.of(2024, 6, 1), LocalDate.of(2099, 12, 31), null, null, user1.id, any()
        ) } returns page

        When("listTransactions is called with dateFrom only") {
            val result = service.listTransactions(
                user1.id, null, null, null, null, null, null, null, null, null,
                LocalDate.of(2024, 6, 1), null, null, 0, 20
            )

            Then("returns transactions from dateFrom onwards") {
                result.content.size shouldBe 1
            }
        }
    }

    Given("dateTo only is provided") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val tx1 = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "지출", transactionDate = LocalDate.of(2024, 1, 15)
        )
        val page = PageImpl(listOf(tx1), PageRequest.of(0, 20), 1)
        every { transactionRepository.findByCoupleIdAndFilters(
            couple.id, LocalDate.of(2000, 1, 1), LocalDate.of(2024, 3, 31), null, null, user1.id, any()
        ) } returns page

        When("listTransactions is called with dateTo only") {
            val result = service.listTransactions(
                user1.id, null, null, null, null, null, null, null, null, null,
                null, LocalDate.of(2024, 3, 31), null, 0, 20
            )

            Then("returns transactions up to dateTo") {
                result.content.size shouldBe 1
            }
        }
    }

    // --- getSettlementTransactions ---

    Given("a user requesting settlement transactions for a payment method") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val pm = PaymentMethod(couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT, settlementDay = 15, closingDay = 25)
        every { paymentMethodRepository.findById(pm.id) } returns Optional.of(pm)

        When("transactions exist for the settlement period") {
            val tx1 = Transaction(
                couple = couple, author = user1, type = TransactionType.EXPENSE,
                amount = 10000, description = "점심", transactionDate = LocalDate.of(2024, 1, 5),
                paymentMethod = pm, settlementDate = LocalDate.of(2024, 2, 15), category = category
            )
            val tx2 = Transaction(
                couple = couple, author = user1, type = TransactionType.EXPENSE,
                amount = 20000, description = "저녁", transactionDate = LocalDate.of(2024, 1, 10),
                paymentMethod = pm, settlementDate = LocalDate.of(2024, 2, 15)
            )
            every { transactionRepository.findByPaymentMethodAndSettlementDateRangeForEdit(
                pm.id, LocalDate.of(2024, 2, 1), LocalDate.of(2024, 2, 29), user1.id, null
            ) } returns listOf(tx1, tx2)
            // Transfer from previous month (source = this card)
            every { transferRepository.findBySourcePaymentMethodAndDateRange(
                pm.id, LocalDate.of(2024, 1, 1), LocalDate.of(2024, 1, 31)
            ) } returns emptyList()

            val result = service.getSettlementTransactions(user1.id, pm.id, 2024, 2)

            Then("returns settlement transactions with total and count") {
                result.totalAmount shouldBe 30000
                result.transactionCount shouldBe 2
                result.transactions.size shouldBe 2
                result.transactions[0].description shouldBe "점심"
                result.transactions[0].categoryName shouldBe "식비"
                result.transactions[0].categoryIcon shouldBe "restaurant"
                result.transactions[1].description shouldBe "저녁"
                result.transactions[1].categoryName shouldBe null
            }
        }

        When("no transactions exist for the settlement period") {
            every { transactionRepository.findByPaymentMethodAndSettlementDateRangeForEdit(
                pm.id, LocalDate.of(2024, 3, 1), LocalDate.of(2024, 3, 31), user1.id, null
            ) } returns emptyList()
            // Fallback query for null-settlementDate transactions from previous month
            every { transactionRepository.findByPaymentMethodAndTransactionDateRangeWithNullSettlementForEdit(
                pm.id, LocalDate.of(2024, 2, 1), LocalDate.of(2024, 2, 29), user1.id, null
            ) } returns emptyList()
            // Transfer from previous month (source = this card)
            every { transferRepository.findBySourcePaymentMethodAndDateRange(
                pm.id, LocalDate.of(2024, 2, 1), LocalDate.of(2024, 2, 29)
            ) } returns emptyList()

            val result = service.getSettlementTransactions(user1.id, pm.id, 2024, 3)

            Then("returns empty response with zero totals") {
                result.totalAmount shouldBe 0
                result.transactionCount shouldBe 0
                result.transactions shouldBe emptyList()
            }
        }
    }

    Given("a user requesting settlement transactions for another couple's payment method") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val otherCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)
        val otherPm = PaymentMethod(couple = otherCouple, name = "다른카드", type = PaymentMethodType.CREDIT)
        every { paymentMethodRepository.findById(otherPm.id) } returns Optional.of(otherPm)

        When("getSettlementTransactions is called") {
            Then("throws ForbiddenException") {
                val ex = shouldThrow<com.budgetbook.common.exception.ForbiddenException> {
                    service.getSettlementTransactions(user1.id, otherPm.id, 2024, 2)
                }
                ex.code shouldBe "FORBIDDEN"
            }
        }
    }

    Given("a user requesting settlement transactions for a non-existent payment method") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val fakeId = UUID.randomUUID()
        every { paymentMethodRepository.findById(fakeId) } returns Optional.empty()

        When("getSettlementTransactions is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.getSettlementTransactions(user1.id, fakeId, 2024, 2)
                }
                ex.code shouldBe "PAYMENT_METHOD_NOT_FOUND"
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
            val result = service.listTransactions(user1.id, 2024, 1, null, null, null, pmId, null, null, null, null, null, null, 0, 20)

            Then("returns filtered results via specification") {
                result.content.size shouldBe 1
            }
        }
    }

    // --- visibility 필터 (P6) ---

    Given("transactions exist and visibility filter SHARED is used") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val sharedTx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "공유 지출", transactionDate = LocalDate.of(2024, 1, 15),
            visibility = Visibility.SHARED, owner = null
        )
        val page = PageImpl(listOf(sharedTx), PageRequest.of(0, 20), 1)
        every { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) } returns page

        When("listTransactions is called with visibility='SHARED'") {
            val result = service.listTransactions(
                user1.id, 2024, 1, null, null, null, null, null, null, null, null, null, "SHARED", 0, 20
            )

            Then("routes through Specification and returns shared-only transactions") {
                result.content.size shouldBe 1
                result.totalElements shouldBe 1
                verify { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) }
            }
        }
    }

    Given("transactions exist and visibility filter PRIVATE is used") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val privateTx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 5000, description = "개인 지출", transactionDate = LocalDate.of(2024, 1, 10),
            visibility = Visibility.PRIVATE, owner = user1
        )
        val page = PageImpl(listOf(privateTx), PageRequest.of(0, 20), 1)
        every { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) } returns page

        When("listTransactions is called with visibility='PRIVATE'") {
            val result = service.listTransactions(
                user1.id, 2024, 1, null, null, null, null, null, null, null, null, null, "PRIVATE", 0, 20
            )

            Then("routes through Specification and returns owner's private transactions") {
                result.content.size shouldBe 1
                result.totalElements shouldBe 1
                verify { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) }
            }
        }
    }

    Given("transactions exist and visibility filter ALL is used") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "거래", transactionDate = LocalDate.of(2024, 1, 15),
            visibility = Visibility.SHARED, owner = null
        )
        val page = PageImpl(listOf(tx), PageRequest.of(0, 20), 1)
        every { transactionRepository.findByCoupleIdAndFilters(
            couple.id, LocalDate.of(2024, 1, 1), LocalDate.of(2024, 1, 31), null, null, user1.id, any()
        ) } returns page

        When("listTransactions is called with visibility='ALL'") {
            val result = service.listTransactions(
                user1.id, 2024, 1, null, null, null, null, null, null, null, null, null, "ALL", 0, 20
            )

            Then("falls back to legacy JPQL path (ALL == default behavior)") {
                result.content.size shouldBe 1
                verify { transactionRepository.findByCoupleIdAndFilters(
                    couple.id, LocalDate.of(2024, 1, 1), LocalDate.of(2024, 1, 31), null, null, user1.id, any()
                ) }
            }
        }
    }

    Given("an invalid visibility value is provided") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("listTransactions is called with visibility='INVALID'") {
            Then("throws BusinessException with VALIDATION_ERROR") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.listTransactions(
                        user1.id, 2024, 1, null, null, null, null, null, null, null, null, null, "INVALID", 0, 20
                    )
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- transactionTypes 다중 필터 (Phase 22 T10) ---

    Given("transactions exist and transactionTypes=[EXPENSE, INCOME] multi filter is used") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val expenseTx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "지출", transactionDate = LocalDate.of(2024, 1, 15)
        )
        val incomeTx = Transaction(
            couple = couple, author = user2, type = TransactionType.INCOME,
            amount = 3000000, description = "급여", transactionDate = LocalDate.of(2024, 1, 25)
        )
        val specSlot = slot<org.springframework.data.jpa.domain.Specification<Transaction>>()
        val page = PageImpl(listOf(incomeTx, expenseTx), PageRequest.of(0, 20), 2)
        every { transactionRepository.findAll(capture(specSlot), any<org.springframework.data.domain.Pageable>()) } returns page

        When("listTransactions is called with transactionTypes=[EXPENSE, INCOME]") {
            val result = service.listTransactions(
                userId = user1.id, year = 2024, month = 1, type = null, categoryId = null,
                keyword = null, paymentMethodId = null, pocketId = null,
                amountMin = null, amountMax = null, dateFrom = null, dateTo = null,
                visibility = null, page = 0, size = 20,
                transactionTypes = listOf("EXPENSE", "INCOME")
            )

            Then("routes through Specification (IN-clause) and returns filtered results") {
                result.content.size shouldBe 2
                result.totalElements shouldBe 2
                // Spec 경로가 실제로 호출되었는지 확인 (legacy JPQL 은 단일 type 만 지원하므로 호출되면 안됨)
                verify(exactly = 1) { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) }
                verify(exactly = 0) { transactionRepository.findByCoupleIdAndFilters(any(), any(), any(), any(), any(), any(), any()) }
                specSlot.isCaptured shouldBe true
            }
        }
    }

    Given("transactionTypes contains FE-only TRANSFER value") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("listTransactions is called with transactionTypes=[TRANSFER]") {
            Then("throws BusinessException with VALIDATION_ERROR (TRANSFER 는 FE 의사-타입)") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.listTransactions(
                        userId = user1.id, year = 2024, month = 1, type = null, categoryId = null,
                        keyword = null, paymentMethodId = null, pocketId = null,
                        amountMin = null, amountMax = null, dateFrom = null, dateTo = null,
                        visibility = null, page = 0, size = 20,
                        transactionTypes = listOf("TRANSFER")
                    )
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("listTransactions is called with transactionTypes=[EXPENSE, BOGUS]") {
            Then("throws BusinessException with VALIDATION_ERROR (하나라도 잘못되면 400)") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.listTransactions(
                        userId = user1.id, year = 2024, month = 1, type = null, categoryId = null,
                        keyword = null, paymentMethodId = null, pocketId = null,
                        amountMin = null, amountMax = null, dateFrom = null, dateTo = null,
                        visibility = null, page = 0, size = 20,
                        transactionTypes = listOf("EXPENSE", "BOGUS")
                    )
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("both singular `type` and multi `transactionTypes` are set") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.INCOME,
            amount = 3000000, description = "급여", transactionDate = LocalDate.of(2024, 1, 25)
        )
        val page = PageImpl(listOf(tx), PageRequest.of(0, 20), 1)
        every { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) } returns page

        When("listTransactions receives type=EXPENSE AND transactionTypes=[EXPENSE, INCOME]") {
            val result = service.listTransactions(
                userId = user1.id, year = 2024, month = 1, type = "EXPENSE", categoryId = null,
                keyword = null, paymentMethodId = null, pocketId = null,
                amountMin = null, amountMax = null, dateFrom = null, dateTo = null,
                visibility = null, page = 0, size = 20,
                transactionTypes = listOf("EXPENSE", "INCOME")
            )

            Then("multi `transactionTypes` takes precedence (matches FE toQueryParams)") {
                // 단수 type=EXPENSE 는 무시되고 IN-clause(EXPENSE, INCOME) 로 조회.
                // 결과로 INCOME 거래(급여) 가 포함됨 — 단수가 우선이었다면 걸러졌을 것.
                result.content.size shouldBe 1
                result.content[0].type shouldBe "INCOME"
                verify(exactly = 1) { transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<Transaction>>(), any<org.springframework.data.domain.Pageable>()) }
            }
        }
    }

    Given("transactionTypes is empty list") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "점심", transactionDate = LocalDate.of(2024, 1, 15)
        )
        val page = PageImpl(listOf(tx), PageRequest.of(0, 20), 1)
        every { transactionRepository.findByCoupleIdAndFilters(
            couple.id, LocalDate.of(2024, 1, 1), LocalDate.of(2024, 1, 31), null, null, user1.id, any()
        ) } returns page

        When("listTransactions is called with transactionTypes=emptyList()") {
            val result = service.listTransactions(
                userId = user1.id, year = 2024, month = 1, type = null, categoryId = null,
                keyword = null, paymentMethodId = null, pocketId = null,
                amountMin = null, amountMax = null, dateFrom = null, dateTo = null,
                visibility = null, page = 0, size = 20,
                transactionTypes = emptyList()
            )

            Then("falls back to legacy JPQL path (빈 리스트 = 필터 없음)") {
                result.content.size shouldBe 1
                verify { transactionRepository.findByCoupleIdAndFilters(
                    couple.id, LocalDate.of(2024, 1, 1), LocalDate.of(2024, 1, 31), null, null, user1.id, any()
                ) }
            }
        }
    }

    // --- Phase 22 T11: type 별 amount 부호 검증 ---

    Given("a user in an active couple creating transactions with signed amounts") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        When("creating an EXPENSE with negative amount") {
            val request = CreateTransactionRequest(
                type = "EXPENSE", amount = -100, description = "잘못된 지출",
                transactionDate = LocalDate.of(2024, 1, 15)
            )

            Then("throws BusinessException with VALIDATION_ERROR and does not persist") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.createTransaction(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.save(any()) }
            }
        }

        When("creating an INCOME with zero amount") {
            // 회차 1 follow-up (2026-05-06) — V46 정책 일치: 0원 거래 허용.
            // 이전 동작(거부)에서 변경된 정책. 사용자 요청: "0원 입력 가능해야 한다".
            val request = CreateTransactionRequest(
                type = "INCOME", amount = 0, description = "0원 수입",
                transactionDate = LocalDate.of(2024, 1, 15)
            )
            val txSlot = slot<Transaction>()
            every { transactionRepository.save(capture(txSlot)) } answers { txSlot.captured }

            val result = service.createTransaction(user1.id, request)

            Then("creates the transaction with amount = 0") {
                result.type shouldBe "INCOME"
                result.amount shouldBe 0
                txSlot.captured.amount shouldBe 0
            }
        }

        When("creating an EXPENSE with zero amount") {
            // 회차 1 follow-up (2026-05-06) — 0원 지출도 허용 (예: 무료 이벤트 기록).
            val request = CreateTransactionRequest(
                type = "EXPENSE", amount = 0, description = "0원 지출",
                transactionDate = LocalDate.of(2024, 1, 15)
            )
            val txSlot = slot<Transaction>()
            every { transactionRepository.save(capture(txSlot)) } answers { txSlot.captured }

            val result = service.createTransaction(user1.id, request)

            Then("creates the transaction with amount = 0") {
                result.type shouldBe "EXPENSE"
                result.amount shouldBe 0
                txSlot.captured.amount shouldBe 0
            }
        }

        When("creating an ADJUSTMENT with negative amount (잔액 하향 조정)") {
            val request = CreateTransactionRequest(
                type = "ADJUSTMENT", amount = -100, description = "실잔액 보정 (하향)",
                transactionDate = LocalDate.of(2024, 1, 15)
            )
            val txSlot = slot<Transaction>()
            every { transactionRepository.save(capture(txSlot)) } answers { txSlot.captured }

            val result = service.createTransaction(user1.id, request)

            Then("creates the transaction with negative amount — PaymentMethod 잔액 계산에서 -100 만큼 차감") {
                result.type shouldBe "ADJUSTMENT"
                result.amount shouldBe -100
                // TransactionRepository.netAmountByPaymentMethodForCouple 은 ADJUSTMENT.amount 를
                // 그대로 SUM 하므로 (V54 + plan §2.5), 음수 ADJUSTMENT 는 잔액을 그만큼 감소시킨다.
                txSlot.captured.amount shouldBe -100
                txSlot.captured.type shouldBe TransactionType.ADJUSTMENT
                verify(exactly = 1) { transactionRepository.save(any()) }
            }
        }

        When("creating an ADJUSTMENT with positive amount (잔액 상향 조정)") {
            val request = CreateTransactionRequest(
                type = "ADJUSTMENT", amount = 500, description = "실잔액 보정 (상향)",
                transactionDate = LocalDate.of(2024, 1, 15)
            )
            val txSlot = slot<Transaction>()
            every { transactionRepository.save(capture(txSlot)) } answers { txSlot.captured }

            val result = service.createTransaction(user1.id, request)

            Then("creates the transaction with positive signed amount") {
                result.type shouldBe "ADJUSTMENT"
                result.amount shouldBe 500
                txSlot.captured.amount shouldBe 500
            }
        }

        When("creating an ADJUSTMENT with zero amount") {
            val request = CreateTransactionRequest(
                type = "ADJUSTMENT", amount = 0, description = "의미 없는 조정",
                transactionDate = LocalDate.of(2024, 1, 15)
            )

            Then("throws BusinessException with VALIDATION_ERROR and does not persist") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.createTransaction(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.save(any()) }
            }
        }
    }

    Given("an existing ADJUSTMENT transaction being updated") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.ADJUSTMENT,
            amount = 100, description = "잔액 보정", transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
        every { transactionRepository.save(tx) } returns tx

        When("updateTransaction is called with amount = -200 (상→하향 전환)") {
            val request = UpdateTransactionRequest(amount = -200)
            val result = service.updateTransaction(user1.id, tx.id, request)

            Then("accepts the negative amount") {
                result.amount shouldBe -200
            }
        }

        When("updateTransaction is called with amount = 0") {
            val request = UpdateTransactionRequest(amount = 0)

            Then("throws BusinessException with VALIDATION_ERROR") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.updateTransaction(user1.id, tx.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("an existing EXPENSE transaction being updated with negative amount") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val tx = Transaction(
            couple = couple, author = user1, type = TransactionType.EXPENSE,
            amount = 15000, description = "지출", transactionDate = LocalDate.of(2024, 1, 15)
        )
        every { transactionRepository.findById(tx.id) } returns Optional.of(tx)

        When("updateTransaction is called with amount = -100") {
            val request = UpdateTransactionRequest(amount = -100)

            Then("throws BusinessException with VALIDATION_ERROR and does not save") {
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.updateTransaction(user1.id, tx.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.save(any()) }
            }
        }
    }

    // --- 유형 변경 / 이체 변환 (2026-07-27) ---

    Given("수입↔지출 유형 변경") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { reconciliationLookup.refsForTransactions(any()) } returns emptyMap()

        When("지출 거래를 수입으로 바꾸면 (카테고리 없음)") {
            val tx = Transaction(
                couple = couple, author = user1, type = TransactionType.EXPENSE,
                amount = 15000, description = "환불", transactionDate = LocalDate.of(2026, 7, 15)
            )
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
            every { transactionRepository.save(tx) } returns tx

            val result = service.updateTransaction(
                user1.id, tx.id, UpdateTransactionRequest(type = "INCOME")
            )

            Then("유형이 바뀐다") {
                result.type shouldBe "INCOME"
            }
        }

        When("지출 카테고리를 그대로 두고 수입으로 바꾸면") {
            val tx = Transaction(
                couple = couple, author = user1, type = TransactionType.EXPENSE,
                amount = 15000, description = "점심", category = category,
                transactionDate = LocalDate.of(2026, 7, 15)
            )
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
            every { transactionRepository.save(tx) } returns tx

            Then("VALIDATION_ERROR — 카테고리를 함께 바꿔야 한다") {
                // 유형만 바꾸고 지출 카테고리를 남기면 분류가 어긋난 채 저장된다.
                val ex = shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.updateTransaction(user1.id, tx.id, UpdateTransactionRequest(type = "INCOME"))
                }
                ex.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.save(any()) }
            }
        }

        When("잔액 수정(ADJUSTMENT) 을 지출로 바꾸려 하면") {
            val tx = Transaction(
                couple = couple, author = user1, type = TransactionType.ADJUSTMENT,
                amount = -3000, description = "잔액 조정", transactionDate = LocalDate.of(2026, 7, 15)
            )
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)

            Then("VALIDATION_ERROR") {
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.updateTransaction(user1.id, tx.id, UpdateTransactionRequest(type = "EXPENSE"))
                }.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("정산에 기록된 거래의 유형을 바꾸려 하면") {
            val tx = Transaction(
                couple = couple, author = user1, type = TransactionType.EXPENSE,
                amount = 15000, description = "점심", transactionDate = LocalDate.of(2026, 7, 15)
            )
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
            every { reconciliationLookup.refsForTransactions(listOf(tx.id)) } returns mapOf(
                tx.id to com.budgetbook.reconciliation.dto.ReconciliationRef(
                    reconciliationId = UUID.randomUUID(),
                    reconciliationSeq = 1,
                    reconciledAt = java.time.Instant.now()
                )
            )

            Then("VALIDATION_ERROR — 스냅샷 분류 이력이 흔들린다") {
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.updateTransaction(user1.id, tx.id, UpdateTransactionRequest(type = "INCOME"))
                }.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.save(any()) }
            }
        }
    }

    Given("거래 → 이체 변환") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { reconciliationLookup.refsForTransactions(any()) } returns emptyMap()
        every { spendingPlanRepository.existsByLinkedTransactionId(any()) } returns false

        val srcId = UUID.randomUUID()
        val dstId = UUID.randomUUID()

        fun convertRequest() = com.budgetbook.transaction.dto.ConvertToTransferRequest(
            sourcePaymentMethodId = srcId,
            destinationPaymentMethodId = dstId
        )

        When("일반 지출 거래를 이체로 바꾸면") {
            val tx = Transaction(
                couple = couple, author = user1, type = TransactionType.EXPENSE,
                amount = 50000, description = "계좌 이동", memo = "메모",
                transactionDate = LocalDate.of(2026, 7, 15)
            )
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
            every { transactionRepository.delete(tx) } returns Unit
            val created = slot<com.budgetbook.transfer.dto.CreateTransferRequest>()
            every { transferService.createTransfer(user1.id, capture(created)) } returns
                mockk(relaxed = true)

            service.convertToTransfer(user1.id, tx.id, convertRequest())

            Then("원본 값을 승계한 이체가 만들어지고 거래는 삭제된다") {
                created.captured.amount shouldBe 50000
                created.captured.description shouldBe "계좌 이동"
                created.captured.memo shouldBe "메모"
                created.captured.transferDate shouldBe LocalDate.of(2026, 7, 15)
                verify { transactionRepository.delete(tx) }
            }

            Then("거래 삭제 이벤트도 발행된다 (장부는 두 스트림 병합)") {
                val events = mutableListOf<SyncEvent>()
                verify { syncEventPublisher.publish(capture(events)) }
                events.any { it.type == "TRANSACTION_DELETED" } shouldBe true
            }
        }

        When("잔액 수정을 이체로 바꾸려 하면") {
            val tx = Transaction(
                couple = couple, author = user1, type = TransactionType.ADJUSTMENT,
                amount = -3000, description = "잔액 조정", transactionDate = LocalDate.of(2026, 7, 15)
            )
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)

            Then("VALIDATION_ERROR") {
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertToTransfer(user1.id, tx.id, convertRequest())
                }.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.delete(any<Transaction>()) }
            }
        }

        When("카드 결제에 연결된 거래를 이체로 바꾸려 하면") {
            val tx = Transaction(
                couple = couple, author = user1, type = TransactionType.EXPENSE,
                amount = 50000, description = "카드 지출", transactionDate = LocalDate.of(2026, 7, 15),
                settlementTransferId = UUID.randomUUID()
            )
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)

            Then("VALIDATION_ERROR") {
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertToTransfer(user1.id, tx.id, convertRequest())
                }.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("지출 계획에 연결된 거래를 이체로 바꾸려 하면") {
            val tx = Transaction(
                couple = couple, author = user1, type = TransactionType.EXPENSE,
                amount = 50000, description = "계획 지출", transactionDate = LocalDate.of(2026, 7, 15)
            )
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
            every { spendingPlanRepository.existsByLinkedTransactionId(tx.id) } returns true

            Then("VALIDATION_ERROR — FK 위반으로 터지기 전에 막는다") {
                // spending_plans.linked_transaction_id 에 ON DELETE 가 없어서
                // 가드가 없으면 500(무결성 오류)이 난다.
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertToTransfer(user1.id, tx.id, convertRequest())
                }.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.delete(any<Transaction>()) }
            }
        }

        When("이체 생성이 실패하면 (예: 카드 간 이체, 같은 결제수단)") {
            val tx = Transaction(
                couple = couple, author = user1, type = TransactionType.EXPENSE,
                amount = 50000, description = "지출", transactionDate = LocalDate.of(2026, 7, 15)
            )
            every { transactionRepository.findById(tx.id) } returns Optional.of(tx)
            // 결제수단 조합 검증은 이체 생성 경로가 단일 소스다 (여기서 또 검사하지 않는다).
            every { transferService.createTransfer(user1.id, any()) } throws
                com.budgetbook.common.exception.BusinessException(
                    "VALIDATION_ERROR", "Source and destination payment methods must be different."
                )

            Then("원본 거래는 지워지지 않는다 (원자성)") {
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertToTransfer(user1.id, tx.id, convertRequest())
                }.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.delete(any<Transaction>()) }
            }
        }
    }

    // --- 이체 → 거래 역변환 (2026-08-09). 위 블록의 거울상. ---

    Given("이체 → 거래 역변환") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { reconciliationLookup.refsForTransfers(any()) } returns emptyMap()
        every { transactionRepository.existsBySettlementTransferId(any()) } returns false

        val bank = PaymentMethod(couple = couple, name = "국민은행", type = PaymentMethodType.BANK)
        val cash = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH)
        every { paymentMethodRepository.findById(bank.id) } returns Optional.of(bank)
        every { paymentMethodRepository.findById(cash.id) } returns Optional.of(cash)

        fun transfer(
            description: String? = "계좌 이동",
            kind: com.budgetbook.transfer.domain.TransferKind =
                com.budgetbook.transfer.domain.TransferKind.GENERIC
        ) = com.budgetbook.transfer.domain.Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = bank, destinationPaymentMethod = cash,
            amount = 50000, description = description, memo = "메모",
            transferDate = LocalDate.of(2026, 7, 15), kind = kind
        )

        When("일반 이체를 지출로 바꾸면") {
            val tr = transfer()
            every { transferRepository.findByIdAndCoupleId(tr.id, couple.id) } returns tr
            every { transferRepository.delete(tr) } returns Unit
            val txSlot = slot<Transaction>()
            every { transactionRepository.saveAndFlush(capture(txSlot)) } answers { txSlot.captured }

            service.convertFromTransfer(
                user1.id, tr.id,
                com.budgetbook.transaction.dto.ConvertToTransactionRequest(type = "EXPENSE")
            )

            Then("원본 값을 승계한 거래가 만들어지고 이체는 삭제된다") {
                txSlot.captured.type shouldBe TransactionType.EXPENSE
                txSlot.captured.amount shouldBe 50000
                txSlot.captured.description shouldBe "계좌 이동"
                txSlot.captured.memo shouldBe "메모"
                txSlot.captured.transactionDate shouldBe LocalDate.of(2026, 7, 15)
                verify { transferRepository.delete(tr) }
            }

            Then("지출은 돈이 나간 쪽(출금) 결제수단을 승계한다") {
                txSlot.captured.paymentMethod?.id shouldBe bank.id
            }

            Then("이체 삭제 + 거래 생성 이벤트가 모두 발행된다 (장부는 두 스트림 병합)") {
                val events = mutableListOf<SyncEvent>()
                verify { syncEventPublisher.publish(capture(events)) }
                events.any { it.type == "TRANSFER_DELETED" } shouldBe true
                events.any { it.type == "TRANSACTION_CREATED" } shouldBe true
            }
        }

        When("일반 이체를 수입으로 바꾸면") {
            val tr = transfer()
            every { transferRepository.findByIdAndCoupleId(tr.id, couple.id) } returns tr
            every { transferRepository.delete(tr) } returns Unit
            val txSlot = slot<Transaction>()
            every { transactionRepository.saveAndFlush(capture(txSlot)) } answers { txSlot.captured }

            service.convertFromTransfer(
                user1.id, tr.id,
                com.budgetbook.transaction.dto.ConvertToTransactionRequest(type = "INCOME")
            )

            Then("수입은 돈이 들어온 쪽(입금) 결제수단을 승계한다") {
                txSlot.captured.type shouldBe TransactionType.INCOME
                txSlot.captured.paymentMethod?.id shouldBe cash.id
            }
        }

        When("정산에 기록된 이체를 거래로 바꾸려 하면") {
            val tr = transfer()
            every { transferRepository.findByIdAndCoupleId(tr.id, couple.id) } returns tr
            every { reconciliationLookup.refsForTransfers(listOf(tr.id)) } returns mapOf(
                tr.id to com.budgetbook.reconciliation.dto.ReconciliationRef(
                    reconciliationId = UUID.randomUUID(),
                    reconciliationSeq = 1,
                    reconciledAt = java.time.Instant.now()
                )
            )

            Then("VALIDATION_ERROR — 이체는 지워지지 않는다") {
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertFromTransfer(
                        user1.id, tr.id,
                        com.budgetbook.transaction.dto.ConvertToTransactionRequest(type = "EXPENSE")
                    )
                }.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transferRepository.delete(any<com.budgetbook.transfer.domain.Transfer>()) }
            }
        }

        When("카드 결제 이체를 거래로 바꾸려 하면") {
            val tr = transfer(kind = com.budgetbook.transfer.domain.TransferKind.CARD_SETTLEMENT)
            every { transferRepository.findByIdAndCoupleId(tr.id, couple.id) } returns tr

            Then("VALIDATION_ERROR — 전용 화면에서만 처리한다") {
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertFromTransfer(
                        user1.id, tr.id,
                        com.budgetbook.transaction.dto.ConvertToTransactionRequest(type = "EXPENSE")
                    )
                }.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transferRepository.delete(any<com.budgetbook.transfer.domain.Transfer>()) }
            }
        }

        When("결제 링크가 남은 이체를 거래로 바꾸려 하면") {
            val tr = transfer()
            every { transferRepository.findByIdAndCoupleId(tr.id, couple.id) } returns tr
            every { transactionRepository.existsBySettlementTransferId(tr.id) } returns true

            Then("VALIDATION_ERROR — 링크가 조용히 끊기기 전에 막는다") {
                // transactions.settlement_transfer_id 는 ON DELETE SET NULL 이라
                // 가드가 없으면 미결제 합계가 조용히 어긋난다.
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertFromTransfer(
                        user1.id, tr.id,
                        com.budgetbook.transaction.dto.ConvertToTransactionRequest(type = "EXPENSE")
                    )
                }.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transferRepository.delete(any<com.budgetbook.transfer.domain.Transfer>()) }
            }
        }

        When("설명이 없는 이체를 거래로 바꾸려 하면") {
            val tr = transfer(description = null)
            every { transferRepository.findByIdAndCoupleId(tr.id, couple.id) } returns tr

            Then("VALIDATION_ERROR — DB NOT NULL 제약(500) 전에 막는다") {
                // transfers.description 은 nullable, transactions.description 은 NOT NULL.
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertFromTransfer(
                        user1.id, tr.id,
                        com.budgetbook.transaction.dto.ConvertToTransactionRequest(type = "EXPENSE")
                    )
                }.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.saveAndFlush(any<Transaction>()) }
            }
        }

        When("유형과 맞지 않는 카테고리를 지정하면") {
            val tr = transfer()
            every { transferRepository.findByIdAndCoupleId(tr.id, couple.id) } returns tr
            // category 는 EXPENSE 형인데 INCOME 거래로 만들려는 경우.
            every { categoryRepository.findById(category.id) } returns Optional.of(category)

            Then("VALIDATION_ERROR — 저장 전에 막는다") {
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertFromTransfer(
                        user1.id, tr.id,
                        com.budgetbook.transaction.dto.ConvertToTransactionRequest(
                            type = "INCOME", categoryId = category.id
                        )
                    )
                }.code shouldBe "VALIDATION_ERROR"
                verify(exactly = 0) { transactionRepository.saveAndFlush(any<Transaction>()) }
            }
        }

        When("잔액 수정으로 바꾸려 하면") {
            val tr = transfer()
            every { transferRepository.findByIdAndCoupleId(tr.id, couple.id) } returns tr

            Then("VALIDATION_ERROR — ADJUSTMENT 는 잔액 보정 전용이다") {
                shouldThrow<com.budgetbook.common.exception.BusinessException> {
                    service.convertFromTransfer(
                        user1.id, tr.id,
                        com.budgetbook.transaction.dto.ConvertToTransactionRequest(type = "ADJUSTMENT")
                    )
                }.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("다른 커플의 이체를 거래로 바꾸려 하면") {
            val otherTransferId = UUID.randomUUID()
            // findByIdAndCoupleId 가 couple 범위로 조회하므로 남의 이체는 애초에 안 잡힌다.
            every { transferRepository.findByIdAndCoupleId(otherTransferId, couple.id) } returns null

            Then("TRANSFER_NOT_FOUND") {
                shouldThrow<NotFoundException> {
                    service.convertFromTransfer(
                        user1.id, otherTransferId,
                        com.budgetbook.transaction.dto.ConvertToTransactionRequest(type = "EXPENSE")
                    )
                }.code shouldBe "TRANSFER_NOT_FOUND"
            }
        }
    }
})
