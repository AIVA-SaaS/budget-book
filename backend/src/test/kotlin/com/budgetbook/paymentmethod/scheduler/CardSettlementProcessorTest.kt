package com.budgetbook.paymentmethod.scheduler

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.service.TransferService
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.LocalDate

/**
 * 배치 2 D-3 (2026-04-26) — CardSettlementProcessor.processCard 의 settlement 로직 단위.
 * 기존 CardAutoSettlementSchedulerTest 에 있던 sum 쿼리 → transfer 생성 흐름이 본 클래스로 이동.
 */
class CardSettlementProcessorTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val transferService = mockk<TransferService>()
    val processor = CardSettlementProcessor(transactionRepository, transferService)

    val u1 = User(email = "u1@t.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val u2 = User(email = "u2@t.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k1")
    val couple = Couple(user1 = u1, user2 = u2, status = CoupleStatus.ACTIVE)
    val bank = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
    val card = PaymentMethod(
        couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
        settlementDay = LocalDate.now().dayOfMonth, closingDay = 15, linkedBank = bank
    )

    Given("pendingAmount > 0") {
        val today = LocalDate.now()
        every {
            transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                eq(card.id), any(), any(), eq(CardSettlementProcessor.SYSTEM_USER_ID)
            )
        } returns listOf(arrayOf<Any?>(300_000L, 10L))
        every {
            transferService.createTransferInternal(
                authorId = CardSettlementProcessor.SYSTEM_USER_ID,
                couple = couple, source = bank, destination = card,
                amount = 300_000L,
                description = any(), transferDate = any(), autoSettlementKey = any()
            )
        } returns mockk()

        When("processCard 실행") {
            processor.processCard(card, today)
            Then("transferService.createTransferInternal 1회 호출") {
                verify(exactly = 1) {
                    transferService.createTransferInternal(
                        authorId = CardSettlementProcessor.SYSTEM_USER_ID,
                        couple = couple, source = bank, destination = card,
                        amount = 300_000L,
                        description = any(), transferDate = any(), autoSettlementKey = any()
                    )
                }
            }
        }
    }

    Given("pendingAmount == 0") {
        val today = LocalDate.now()
        every {
            transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                eq(card.id), any(), any(), eq(CardSettlementProcessor.SYSTEM_USER_ID)
            )
        } returns listOf(arrayOf<Any?>(0L, 0L))

        When("processCard 실행") {
            processor.processCard(card, today)
            Then("transfer 생성 안 함") {
                verify(exactly = 0) {
                    transferService.createTransferInternal(any(), any(), any(), any(), any(), any(), any(), any())
                }
            }
        }
    }

    Given("linkedBank == null (비정상 카드)") {
        val cardNoBank = PaymentMethod(
            couple = couple, name = "X", type = PaymentMethodType.CREDIT,
            settlementDay = LocalDate.now().dayOfMonth, closingDay = 15, linkedBank = null
        )

        When("processCard 실행") {
            processor.processCard(cardNoBank, LocalDate.now())
            Then("아무 작업 없이 return") {
                verify(exactly = 0) {
                    transactionRepository.sumByPaymentMethodAndSettlementDateRange(any(), any(), any(), any())
                }
                verify(exactly = 0) {
                    transferService.createTransferInternal(any(), any(), any(), any(), any(), any(), any(), any())
                }
            }
        }
    }
})
