package com.budgetbook.paymentmethod.scheduler

import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.service.TransferService
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

/**
 * 배치 2 D-3 (2026-04-26): 카드별 처리 트랜잭션 분리.
 * 기존: 단일 큰 트랜잭션에서 N 카드 순차 처리 → 한 카드 실패 시 다른 카드들도 롤백 위험.
 * 신: 카드별 REQUIRES_NEW 로 별도 트랜잭션 → 격리 보장. 한 카드 실패가 다른 카드에 영향 없음.
 *
 * Spring AOP 가 self-invocation private method 를 가로채지 못하므로 별도 Component 로 추출.
 */
@Component
class CardSettlementProcessor(
    private val transactionRepository: TransactionRepository,
    private val transferService: TransferService
) {
    private val log = LoggerFactory.getLogger(javaClass)

    companion object {
        val SYSTEM_USER_ID: UUID = UUID.fromString("00000000-0000-0000-0000-000000000001")
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun processCard(card: PaymentMethod, today: LocalDate) {
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
