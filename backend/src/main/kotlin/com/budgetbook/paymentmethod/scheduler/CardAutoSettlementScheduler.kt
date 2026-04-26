package com.budgetbook.paymentmethod.scheduler

import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import org.slf4j.LoggerFactory
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import java.time.LocalDate

@Component
class CardAutoSettlementScheduler(
    private val paymentMethodRepository: PaymentMethodRepository,
    private val processor: CardSettlementProcessor
) {
    private val log = LoggerFactory.getLogger(javaClass)

    @Scheduled(cron = "0 0 7 * * *")
    fun settleCards() {
        val today = LocalDate.now()
        val dayOfMonth = today.dayOfMonth

        val cards = paymentMethodRepository.findBySettlementDayAndLinkedBankIsNotNullAndIsActiveTrue(dayOfMonth)
        log.info("Auto-settlement: found {} cards for settlement day {}", cards.size, dayOfMonth)

        // 배치 2 D-3: 카드별 REQUIRES_NEW 트랜잭션 격리. 한 카드 실패가 다른 카드 영향 없음.
        for (card in cards) {
            try {
                processor.processCard(card, today)
            } catch (e: DataIntegrityViolationException) {
                log.info("Auto-settlement: skipping duplicate for card {} ({})", card.id, card.name)
            } catch (e: Exception) {
                log.error("Auto-settlement: failed for card {} ({})", card.id, card.name, e)
            }
        }
    }
}
