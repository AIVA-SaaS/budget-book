package com.budgetbook.paymentmethod.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.dto.CreatePaymentMethodRequest
import com.budgetbook.paymentmethod.dto.UpdatePaymentMethodRequest
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.repository.TransferRepository
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
import java.util.UUID

class PaymentMethodServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val paymentMethodRepository = mockk<PaymentMethodRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val transactionRepository = mockk<TransactionRepository>()
    val transferRepository = mockk<TransferRepository>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val service = PaymentMethodService(paymentMethodRepository, coupleResolver, transactionRepository, transferRepository, syncEventPublisher)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    // --- listPaymentMethods ---

    Given("a user in an active couple with payment methods") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val cash = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH, isDefault = true, displayOrder = 0)
        val debit = PaymentMethod(couple = couple, name = "체크카드", type = PaymentMethodType.DEBIT, isDefault = true, displayOrder = 1)
        every { paymentMethodRepository.findByCoupleIdOrderByDisplayOrder(couple.id) } returns listOf(cash, debit)
        every { transactionRepository.netAmountByPaymentMethodForCouple(couple.id) } returns emptyList()
        every { transferRepository.sumAmountByDestinationForCouple(couple.id) } returns emptyList()
        every { transferRepository.sumAmountBySourceForCouple(couple.id) } returns emptyList()

        When("listPaymentMethods is called") {
            val result = service.listPaymentMethods(user1.id)

            Then("returns all payment methods ordered by displayOrder with balance") {
                result shouldHaveSize 2
                result[0].name shouldBe "현금"
                result[0].balance shouldBe 0L
                result[1].name shouldBe "체크카드"
                result[1].balance shouldBe 0L
            }
        }
    }

    // --- createPaymentMethod ---

    Given("a user in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("creating a CASH payment method") {
            val request = CreatePaymentMethodRequest(name = "현금", type = "CASH")
            val pmSlot = slot<PaymentMethod>()
            every { paymentMethodRepository.save(capture(pmSlot)) } answers { pmSlot.captured }

            val result = service.createPaymentMethod(user1.id, request)

            Then("creates with correct fields") {
                result.name shouldBe "현금"
                result.type shouldBe "CASH"
                result.settlementDay shouldBe null
                result.closingDay shouldBe null
            }
        }

        When("creating a CREDIT payment method with settlement and closing days") {
            val request = CreatePaymentMethodRequest(
                name = "신한카드", type = "CREDIT", settlementDay = 15, closingDay = 25
            )
            val pmSlot = slot<PaymentMethod>()
            every { paymentMethodRepository.save(capture(pmSlot)) } answers { pmSlot.captured }

            val result = service.createPaymentMethod(user1.id, request)

            Then("creates with settlement info") {
                result.name shouldBe "신한카드"
                result.type shouldBe "CREDIT"
                result.settlementDay shouldBe 15
                result.closingDay shouldBe 25
            }
        }

        When("creating a CREDIT payment method without settlement day") {
            val request = CreatePaymentMethodRequest(name = "카드", type = "CREDIT", closingDay = 25)

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.createPaymentMethod(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("creating with an invalid type") {
            val request = CreatePaymentMethodRequest(name = "Test", type = "INVALID")

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.createPaymentMethod(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- updatePaymentMethod ---

    Given("an existing payment method to update") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val method = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH, displayOrder = 0)
        every { paymentMethodRepository.findByIdAndCoupleId(method.id, couple.id) } returns method
        every { paymentMethodRepository.save(method) } returns method

        When("updatePaymentMethod is called with new name") {
            val request = UpdatePaymentMethodRequest(name = "생활비 현금")
            val result = service.updatePaymentMethod(user1.id, method.id, request)

            Then("updates the name") {
                result.name shouldBe "생활비 현금"
            }
        }

        When("updatePaymentMethod is called with displayOrder") {
            val request = UpdatePaymentMethodRequest(displayOrder = 5)
            val result = service.updatePaymentMethod(user1.id, method.id, request)

            Then("updates the displayOrder") {
                result.displayOrder shouldBe 5
            }
        }

        When("updatePaymentMethod is called with isActive = false") {
            val request = UpdatePaymentMethodRequest(isActive = false)
            val result = service.updatePaymentMethod(user1.id, method.id, request)

            Then("deactivates the method") {
                result.isActive shouldBe false
            }
        }
    }

    Given("a non-existent payment method") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val fakeId = UUID.randomUUID()
        every { paymentMethodRepository.findByIdAndCoupleId(fakeId, couple.id) } returns null

        When("updatePaymentMethod is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.updatePaymentMethod(user1.id, fakeId, UpdatePaymentMethodRequest(name = "X"))
                }
                ex.code shouldBe "PAYMENT_METHOD_NOT_FOUND"
            }
        }
    }

    // --- deletePaymentMethod ---

    Given("a non-default payment method to delete") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val method = PaymentMethod(couple = couple, name = "삭제할 카드", type = PaymentMethodType.CREDIT)
        every { paymentMethodRepository.findByIdAndCoupleId(method.id, couple.id) } returns method
        every { paymentMethodRepository.delete(method) } returns Unit

        When("deletePaymentMethod is called") {
            service.deletePaymentMethod(user1.id, method.id)

            Then("deletes the method") {
                verify(exactly = 1) { paymentMethodRepository.delete(method) }
            }
        }
    }

    Given("a default payment method") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val method = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH, isDefault = true)
        every { paymentMethodRepository.findByIdAndCoupleId(method.id, couple.id) } returns method

        When("deletePaymentMethod is called") {
            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.deletePaymentMethod(user1.id, method.id)
                }
                ex.code shouldBe "DEFAULT_METHOD_DELETE"
            }
        }
    }

    // --- seedDefaultPaymentMethods ---

    Given("a couple without payment methods") {
        val savedMethods = slot<List<PaymentMethod>>()
        every { paymentMethodRepository.saveAll(capture(savedMethods)) } answers { savedMethods.captured }

        When("seedDefaultPaymentMethods is called") {
            service.seedDefaultPaymentMethods(couple)

            Then("creates two default methods") {
                val methods = savedMethods.captured
                methods shouldHaveSize 2
                methods[0].name shouldBe "현금"
                methods[0].type shouldBe PaymentMethodType.CASH
                methods[0].isDefault shouldBe true
                methods[1].name shouldBe "체크카드"
                methods[1].type shouldBe PaymentMethodType.DEBIT
                methods[1].isDefault shouldBe true
            }
        }
    }

    // --- getCardPendingSummary ---

    Given("a couple with credit cards and transactions") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val creditCard = PaymentMethod(
            couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
            settlementDay = 15, closingDay = 25
        )
        every { paymentMethodRepository.findByCoupleIdAndTypeAndIsActiveTrue(couple.id, PaymentMethodType.CREDIT) } returns listOf(creditCard)

        When("getCardPendingSummary is called and there are transactions") {
            every { transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                creditCard.id,
                java.time.LocalDate.of(2024, 4, 1),
                java.time.LocalDate.of(2024, 4, 30),
                user1.id
            ) } returns listOf(arrayOf<Any?>(250000L, 5L))

            val result = service.getCardPendingSummary(user1.id, 2024, 4)

            Then("returns card pending summary") {
                result shouldHaveSize 1
                result[0].paymentMethod.name shouldBe "신한카드"
                result[0].pendingAmount shouldBe 250000
                result[0].transactionCount shouldBe 5
                result[0].settlementDate shouldBe java.time.LocalDate.of(2024, 4, 15)
            }
        }

        When("getCardPendingSummary is called with no transactions") {
            every { transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                creditCard.id,
                java.time.LocalDate.of(2024, 4, 1),
                java.time.LocalDate.of(2024, 4, 30),
                user1.id
            ) } returns listOf(arrayOf<Any?>(null, 0L))

            val result = service.getCardPendingSummary(user1.id, 2024, 4)

            Then("returns zero amounts") {
                result shouldHaveSize 1
                result[0].pendingAmount shouldBe 0
                result[0].transactionCount shouldBe 0
            }
        }
    }

    // --- balance calculation ---

    Given("payment methods with transactions and transfers") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val bank = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK, displayOrder = 0)
        val cash = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH, displayOrder = 1)
        val credit = PaymentMethod(couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT, settlementDay = 15, closingDay = 10, displayOrder = 2)

        every { paymentMethodRepository.findByCoupleIdOrderByDisplayOrder(couple.id) } returns listOf(bank, cash, credit)

        // net from transactions: bank +500000, cash -30000
        every { transactionRepository.netAmountByPaymentMethodForCouple(couple.id) } returns listOf(
            arrayOf<Any>(bank.id, 500000L),
            arrayOf<Any>(cash.id, -30000L)
        )
        // transfer inflows: bank +100000
        every { transferRepository.sumAmountByDestinationForCouple(couple.id) } returns listOf(
            arrayOf<Any>(bank.id, 100000L)
        )
        // transfer outflows: bank -200000
        every { transferRepository.sumAmountBySourceForCouple(couple.id) } returns listOf(
            arrayOf<Any>(bank.id, 200000L)
        )

        When("listPaymentMethods is called") {
            val result = service.listPaymentMethods(user1.id)

            Then("calculates correct balances for non-CREDIT types") {
                result shouldHaveSize 3
                // bank: 500000 + 100000 - 200000 = 400000
                result[0].name shouldBe "신한은행"
                result[0].balance shouldBe 400000L
                // cash: -30000 + 0 - 0 = -30000
                result[1].name shouldBe "현금"
                result[1].balance shouldBe -30000L
                // credit: balance is null
                result[2].name shouldBe "신한카드"
                result[2].balance shouldBe null
            }
        }
    }

    // --- linkedBank validation ---

    Given("a user creating a CREDIT card with linkedBank") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val bankPm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
        val cashPm = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH)

        When("creating CREDIT with valid BANK linkedBankId") {
            every { paymentMethodRepository.findByIdAndCoupleId(bankPm.id, couple.id) } returns bankPm
            val pmSlot = slot<PaymentMethod>()
            every { paymentMethodRepository.save(capture(pmSlot)) } answers { pmSlot.captured }

            val request = CreatePaymentMethodRequest(
                name = "신한카드", type = "CREDIT", settlementDay = 15, closingDay = 10, linkedBankId = bankPm.id
            )
            val result = service.createPaymentMethod(user1.id, request)

            Then("creates with linkedBank") {
                result.linkedBankId shouldBe bankPm.id
                result.linkedBankName shouldBe "신한은행"
            }
        }

        When("creating CREDIT with CASH as linkedBankId") {
            every { paymentMethodRepository.findByIdAndCoupleId(cashPm.id, couple.id) } returns cashPm

            val request = CreatePaymentMethodRequest(
                name = "카드", type = "CREDIT", settlementDay = 15, closingDay = 10, linkedBankId = cashPm.id
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.createPaymentMethod(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("creating CASH with linkedBankId") {
            val request = CreatePaymentMethodRequest(
                name = "현금2", type = "CASH", linkedBankId = bankPm.id
            )

            Then("throws BusinessException (linkedBank only for CREDIT)") {
                val ex = shouldThrow<BusinessException> {
                    service.createPaymentMethod(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- getCardSettlementSummary ---

    Given("a couple with credit cards for settlement summary") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val creditCard = PaymentMethod(
            couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
            settlementDay = 25, closingDay = 15
        )
        every { paymentMethodRepository.findByCoupleIdAndTypeAndIsActiveTrue(couple.id, PaymentMethodType.CREDIT) } returns listOf(creditCard)

        When("getCardSettlementSummary is called") {
            val now = java.time.YearMonth.now()
            val prev = now.minusMonths(1)

            // Previous month: query by transactionDate range
            every { transactionRepository.sumByPaymentMethodAndTransactionDateRange(
                creditCard.id,
                prev.atDay(1),
                prev.atEndOfMonth(),
                user1.id
            ) } returns listOf(arrayOf<Any?>(150000L, 3L))

            // Previous month: transfer out
            every { transferRepository.sumAmountBySourceForCoupleAndPeriod(
                couple.id,
                prev.atDay(1),
                prev.atEndOfMonth()
            ) } returns listOf(arrayOf<Any>(creditCard.id, 10000L))

            // Current month: query by transactionDate range
            every { transactionRepository.sumByPaymentMethodAndTransactionDateRange(
                creditCard.id,
                now.atDay(1),
                now.atEndOfMonth(),
                user1.id
            ) } returns listOf(arrayOf<Any?>(200000L, 5L))

            // Current month: transfer out
            every { transferRepository.sumAmountBySourceForCoupleAndPeriod(
                couple.id,
                now.atDay(1),
                now.atEndOfMonth()
            ) } returns listOf(arrayOf<Any>(creditCard.id, 20000L))

            // Unpaid month: query by settlementDate range (current month)
            every { transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                creditCard.id,
                now.atDay(1),
                now.atEndOfMonth(),
                user1.id
            ) } returns listOf(arrayOf<Any?>(80000L, 2L))

            val result = service.getCardSettlementSummary(user1.id)

            Then("uses transactionDate for prev/current (including transfers) and settlementDate for unpaid") {
                result.previousMonth.totalAmount shouldBe 160000  // 150000 txn + 10000 transfer
                result.previousMonth.cards shouldHaveSize 1
                result.previousMonth.cards[0].pendingAmount shouldBe 160000
                result.previousMonth.cards[0].transactionCount shouldBe 3

                result.currentMonth.totalAmount shouldBe 220000  // 200000 txn + 20000 transfer
                result.currentMonth.cards shouldHaveSize 1
                result.currentMonth.cards[0].pendingAmount shouldBe 220000
                result.currentMonth.cards[0].transactionCount shouldBe 5

                result.unpaidMonth.totalAmount shouldBe 100000  // 80000 txn + 20000 transfer
                result.unpaidMonth.year shouldBe now.year
                result.unpaidMonth.month shouldBe now.monthValue
                result.unpaidMonth.cards shouldHaveSize 1
                result.unpaidMonth.cards[0].pendingAmount shouldBe 100000  // 80000 txn + 20000 transfer
                result.unpaidMonth.cards[0].transactionCount shouldBe 2
            }
        }
    }

    Given("a couple with credit cards without closingDay/settlementDay") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val creditCardNoSetting = PaymentMethod(
            couple = couple, name = "미설정카드", type = PaymentMethodType.CREDIT,
            settlementDay = null, closingDay = null
        )
        every { paymentMethodRepository.findByCoupleIdAndTypeAndIsActiveTrue(couple.id, PaymentMethodType.CREDIT) } returns listOf(creditCardNoSetting)

        When("getCardSettlementSummary is called for card without settlement settings") {
            val now = java.time.YearMonth.now()
            val prev = now.minusMonths(1)

            // transactionDate queries still work — they don't depend on settlement settings
            every { transactionRepository.sumByPaymentMethodAndTransactionDateRange(
                creditCardNoSetting.id,
                prev.atDay(1),
                prev.atEndOfMonth(),
                user1.id
            ) } returns listOf(arrayOf<Any?>(100000L, 2L))

            // Transfer out (no transfers for this card)
            every { transferRepository.sumAmountBySourceForCoupleAndPeriod(
                couple.id,
                prev.atDay(1),
                prev.atEndOfMonth()
            ) } returns emptyList()

            every { transactionRepository.sumByPaymentMethodAndTransactionDateRange(
                creditCardNoSetting.id,
                now.atDay(1),
                now.atEndOfMonth(),
                user1.id
            ) } returns listOf(arrayOf<Any?>(50000L, 1L))

            // Transfer out (no transfers for this card)
            every { transferRepository.sumAmountBySourceForCoupleAndPeriod(
                couple.id,
                now.atDay(1),
                now.atEndOfMonth()
            ) } returns emptyList()

            // settlementDate query returns 0 since no settlementDate set on transactions
            every { transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                creditCardNoSetting.id,
                now.atDay(1),
                now.atEndOfMonth(),
                user1.id
            ) } returns listOf(arrayOf<Any?>(0L, 0L))

            val result = service.getCardSettlementSummary(user1.id)

            Then("previous/current months have data, unpaid is zero") {
                result.previousMonth.totalAmount shouldBe 100000
                result.previousMonth.cards[0].pendingAmount shouldBe 100000
                result.previousMonth.cards[0].settlementDate shouldBe null

                result.currentMonth.totalAmount shouldBe 50000
                result.currentMonth.cards[0].pendingAmount shouldBe 50000

                result.unpaidMonth.totalAmount shouldBe 0
                result.unpaidMonth.cards[0].pendingAmount shouldBe 0
                result.unpaidMonth.cards[0].transactionCount shouldBe 0
            }
        }
    }

    // --- user not in couple ---

    Given("a user not in any couple") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("listPaymentMethods is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.listPaymentMethods(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }
})
