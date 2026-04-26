package com.budgetbook.paymentmethod.scheduler

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.springframework.dao.DataIntegrityViolationException
import java.time.LocalDate

/**
 * 배치 2 D-3 (2026-04-26) — Scheduler 의 dispatch + exception isolation 만 검증.
 * 실제 settlement 로직은 CardSettlementProcessorTest 에서 별도 검증.
 */
class CardAutoSettlementSchedulerTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val paymentMethodRepository = mockk<PaymentMethodRepository>()
    val processor = mockk<CardSettlementProcessor>()
    val scheduler = CardAutoSettlementScheduler(paymentMethodRepository, processor)

    val u1 = User(email = "u1@t.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val u2 = User(email = "u2@t.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k1")
    val couple = Couple(user1 = u1, user2 = u2, status = CoupleStatus.ACTIVE)
    val bank = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)

    Given("settlementDay 가 오늘과 일치하는 카드 1장") {
        val today = LocalDate.now()
        val todayDay = today.dayOfMonth
        val card = PaymentMethod(
            couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
            settlementDay = todayDay, closingDay = 15, linkedBank = bank
        )
        every { paymentMethodRepository.findBySettlementDayAndLinkedBankIsNotNullAndIsActiveTrue(todayDay) } returns listOf(card)

        When("processor 가 정상 처리") {
            every { processor.processCard(card, today) } returns Unit
            scheduler.settleCards()
            Then("processor 1회 호출") {
                verify(exactly = 1) { processor.processCard(card, today) }
            }
        }

        When("processor 가 DataIntegrityViolationException — duplicate key") {
            every { processor.processCard(card, today) } throws DataIntegrityViolationException("dup")
            scheduler.settleCards()
            Then("예외 미전파, 다음 카드 처리 가능") {
                // 예외 처리되어 정상 종료
                verify(exactly = 1) { processor.processCard(card, today) }
            }
        }

        When("processor 가 일반 Exception") {
            every { processor.processCard(card, today) } throws RuntimeException("boom")
            scheduler.settleCards()
            Then("예외 미전파") {
                verify(exactly = 1) { processor.processCard(card, today) }
            }
        }
    }

    Given("settlementDay 일치 카드 다수 (격리 검증)") {
        val today = LocalDate.now()
        val todayDay = today.dayOfMonth
        val card1 = PaymentMethod(couple = couple, name = "C1", type = PaymentMethodType.CREDIT, settlementDay = todayDay, closingDay = 15, linkedBank = bank)
        val card2 = PaymentMethod(couple = couple, name = "C2", type = PaymentMethodType.CREDIT, settlementDay = todayDay, closingDay = 15, linkedBank = bank)
        val card3 = PaymentMethod(couple = couple, name = "C3", type = PaymentMethodType.CREDIT, settlementDay = todayDay, closingDay = 15, linkedBank = bank)
        every { paymentMethodRepository.findBySettlementDayAndLinkedBankIsNotNullAndIsActiveTrue(todayDay) } returns listOf(card1, card2, card3)

        When("card2 가 실패해도 card3 까지 처리") {
            every { processor.processCard(card1, today) } returns Unit
            every { processor.processCard(card2, today) } throws RuntimeException("boom2")
            every { processor.processCard(card3, today) } returns Unit

            scheduler.settleCards()

            Then("3 카드 모두 dispatch 됨 (REQUIRES_NEW 격리 검증)") {
                verify(exactly = 1) { processor.processCard(card1, today) }
                verify(exactly = 1) { processor.processCard(card2, today) }
                verify(exactly = 1) { processor.processCard(card3, today) }
            }
        }
    }

    Given("매칭 카드 없음") {
        val todayDay = LocalDate.now().dayOfMonth
        every { paymentMethodRepository.findBySettlementDayAndLinkedBankIsNotNullAndIsActiveTrue(todayDay) } returns emptyList()
        When("settleCards") {
            scheduler.settleCards()
            Then("processor 호출 안 됨") {
                verify(exactly = 0) { processor.processCard(any(), any()) }
            }
        }
    }
})
