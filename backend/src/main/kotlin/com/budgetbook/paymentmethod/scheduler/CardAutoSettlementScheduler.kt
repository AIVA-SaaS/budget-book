package com.budgetbook.paymentmethod.scheduler

import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.service.TransferService
import org.slf4j.LoggerFactory
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Component
class CardAutoSettlementScheduler(
    private val paymentMethodRepository: PaymentMethodRepository,
    private val transactionRepository: TransactionRepository,
    private val transferService: TransferService
) {
    private val log = LoggerFactory.getLogger(javaClass)

    companion object {
        val SYSTEM_USER_ID: UUID = UUID.fromString("00000000-0000-0000-0000-000000000001")
    }

    @Scheduled(cron = "0 0 7 * * *")
    fun settleCards() {
        val today = LocalDate.now()
        val dayOfMonth = today.dayOfMonth

        val cards = paymentMethodRepository.findBySettlementDayAndLinkedBankIsNotNullAndIsActiveTrue(dayOfMonth)
        log.info("Auto-settlement: found {} cards for settlement day {}", cards.size, dayOfMonth)

        for (card in cards) {
            try {
                processCard(card, today)
            } catch (e: DataIntegrityViolationException) {
                log.info("Auto-settlement: skipping duplicate for card {} ({})", card.id, card.name)
            } catch (e: Exception) {
                log.error("Auto-settlement: failed for card {} ({})", card.id, card.name, e)
            }
        }
    }

    private fun processCard(card: PaymentMethod, today: LocalDate) {
        val linkedBank = card.linkedBank ?: return

        val yearMonth = YearMonth.from(today)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        val results = transactionRepository.sumByPaymentMethodAndSettlementDateRange(
            paymentMethodId = card.id,
            startDate = startDate,
            endDate = endDate,
            userId = SYSTEM_USER_ID
        )
        val pendingAmount = results.firstOrNull()?.let { (it[0] as? Number)?.toLong() } ?: 0L

        if (pendingAmount <= 0L) {
            log.info("Auto-settlement: skipping card {} ({}) - zero or negative amount", card.id, card.name)
            return
        }

        val autoSettlementKey = "${card.id}_${yearMonth.year}_${yearMonth.monthValue}"

        transferService.createTransferInternal(
            authorId = SYSTEM_USER_ID,
            couple = card.couple,
            source = linkedBank,
            destination = card,
            amount = pendingAmount,
            description = "${card.name} ${yearMonth.monthValue}월 자동결제",
            transferDate = today,
            autoSettlementKey = autoSettlementKey
        )

        log.info("Auto-settlement: created transfer for card {} ({}) amount={}", card.id, card.name, pendingAmount)
    }
}
