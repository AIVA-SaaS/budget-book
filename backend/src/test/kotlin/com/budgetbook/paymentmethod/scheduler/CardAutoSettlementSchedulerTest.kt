package com.budgetbook.paymentmethod.scheduler

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.domain.Transfer
import com.budgetbook.transfer.service.TransferService
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.springframework.dao.DataIntegrityViolationException
import java.time.LocalDate

class CardAutoSettlementSchedulerTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val paymentMethodRepository = mockk<PaymentMethodRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val transferService = mockk<TransferService>()
    val scheduler = CardAutoSettlementScheduler(paymentMethodRepository, transactionRepository, transferService)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    val bank = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
    val creditCard = PaymentMethod(
        couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
        settlementDay = 25, closingDay = 15, linkedBank = bank
    )

    Given("cards with settlement day matching today") {
        every { paymentMethodRepository.findBySettlementDayAndLinkedBankIsNotNullAndIsActiveTrue(25) } returns listOf(creditCard)

        When("there is a pending amount > 0") {
            every {
                transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                    eq(creditCard.id), any(), any(), eq(CardAutoSettlementScheduler.SYSTEM_USER_ID)
                )
            } returns listOf(arrayOf<Any?>(300000L, 10L))

            every {
                transferService.createTransferInternal(
                    authorId = CardAutoSettlementScheduler.SYSTEM_USER_ID,
                    couple = couple,
                    source = bank,
                    destination = creditCard,
                    amount = 300000L,
                    description = any(),
                    transferDate = any(),
                    autoSettlementKey = any()
                )
            } returns mockk()

            scheduler.settleCards()

            Then("creates a transfer") {
                verify(exactly = 1) {
                    transferService.createTransferInternal(
                        authorId = CardAutoSettlementScheduler.SYSTEM_USER_ID,
                        couple = couple,
                        source = bank,
                        destination = creditCard,
                        amount = 300000L,
                        description = any(),
                        transferDate = any(),
                        autoSettlementKey = any()
                    )
                }
            }
        }

        When("pending amount is zero") {
            every {
                transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                    eq(creditCard.id), any(), any(), eq(CardAutoSettlementScheduler.SYSTEM_USER_ID)
                )
            } returns listOf(arrayOf<Any?>(0L, 0L))

            scheduler.settleCards()

            Then("does not create a transfer") {
                verify(exactly = 0) {
                    transferService.createTransferInternal(any(), any(), any(), any(), any(), any(), any(), any())
                }
            }
        }

        When("duplicate settlement key (DataIntegrityViolationException)") {
            every {
                transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                    eq(creditCard.id), any(), any(), eq(CardAutoSettlementScheduler.SYSTEM_USER_ID)
                )
            } returns listOf(arrayOf<Any?>(300000L, 10L))

            every {
                transferService.createTransferInternal(any(), any(), any(), any(), any(), any(), any(), any())
            } throws DataIntegrityViolationException("duplicate key")

            scheduler.settleCards()

            Then("does not throw - skips duplicate") {
                // No exception propagated
                verify(exactly = 1) {
                    transferService.createTransferInternal(any(), any(), any(), any(), any(), any(), any(), any())
                }
            }
        }
    }

    Given("no cards with matching settlement day") {
        every { paymentMethodRepository.findBySettlementDayAndLinkedBankIsNotNullAndIsActiveTrue(25) } returns emptyList()

        When("settleCards is called") {
            scheduler.settleCards()

            Then("does nothing") {
                verify(exactly = 0) {
                    transferService.createTransferInternal(any(), any(), any(), any(), any(), any(), any(), any())
                }
            }
        }
    }
})
