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
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val service = PaymentMethodService(paymentMethodRepository, coupleResolver, transactionRepository, syncEventPublisher)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    // --- listPaymentMethods ---

    Given("a user in an active couple with payment methods") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val cash = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH, isDefault = true, displayOrder = 0)
        val debit = PaymentMethod(couple = couple, name = "체크카드", type = PaymentMethodType.DEBIT, isDefault = true, displayOrder = 1)
        every { paymentMethodRepository.findByCoupleIdOrderByDisplayOrder(couple.id) } returns listOf(cash, debit)

        When("listPaymentMethods is called") {
            val result = service.listPaymentMethods(user1.id)

            Then("returns all payment methods ordered by displayOrder") {
                result shouldHaveSize 2
                result[0].name shouldBe "현금"
                result[1].name shouldBe "체크카드"
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
                java.time.LocalDate.of(2024, 4, 30)
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
                java.time.LocalDate.of(2024, 4, 30)
            ) } returns listOf(arrayOf<Any?>(null, 0L))

            val result = service.getCardPendingSummary(user1.id, 2024, 4)

            Then("returns zero amounts") {
                result shouldHaveSize 1
                result[0].pendingAmount shouldBe 0
                result[0].transactionCount shouldBe 0
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
