package com.budgetbook.statistics.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.statistics.dto.PaymentMethodStatResponse
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.domain.TransferKinds
import com.budgetbook.transfer.repository.TransferRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.YearMonth
import java.util.UUID

@Service
class PaymentMethodStatisticsService(
    private val transactionRepository: TransactionRepository,
    private val coupleResolver: CoupleResolver,
    private val paymentMethodRepository: PaymentMethodRepository,
    private val transferRepository: TransferRepository
) {

    companion object {
        private val VALID_VISIBILITY_FILTERS = setOf("ALL", "SHARED", "PRIVATE")
    }

    private fun validateVisibility(visibility: String): String {
        val upper = visibility.uppercase()
        if (upper !in VALID_VISIBILITY_FILTERS) {
            throw BusinessException("VALIDATION_ERROR", "Invalid visibility filter: $visibility. Must be one of: ALL, SHARED, PRIVATE")
        }
        return upper
    }

    @Transactional(readOnly = true)
    fun getPaymentMethodStats(userId: UUID, year: Int, month: Int, visibility: String = "ALL"): List<PaymentMethodStatResponse> {
        val couple = coupleResolver.getActiveCouple(userId)
        val visFilter = validateVisibility(visibility)
        val yearMonth = YearMonth.of(year, month)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        // 1. Transaction-based expense stats (existing)
        val txResults = transactionRepository.sumByPaymentMethodForCouple(
            couple.id, startDate, endDate, userId, visFilter
        )
        val txExpenseMap = txResults.associate { row ->
            (row[0] as UUID) to Pair(row[2] as Long, (row[3] as Long).toInt())
        }

        // 2. Transfer-based stats: Phase 22 — CARD_SETTLEMENT 은 통계 제외, 나머지 모두 포함.
        //    과거 `sumAmount...ExcludingSettlement` 는 kind 기반 쿼리로 대체.
        val transferOutResults = transferRepository.sumAmountBySourceByKind(
            couple.id, startDate, endDate, TransferKinds.NON_CARD_SETTLEMENT
        )
        val transferOutMap = transferOutResults.associate { row ->
            (row[0] as UUID) to (row[1] as Long)
        }

        val transferInResults = transferRepository.sumAmountByDestinationByKind(
            couple.id, startDate, endDate, TransferKinds.NON_CARD_SETTLEMENT
        )
        val transferInMap = transferInResults.associate { row ->
            (row[0] as UUID) to (row[1] as Long)
        }

        // 3. Merge: total spending per PM = transaction expense + transfer outgoing
        val allPaymentMethods = paymentMethodRepository.findByCoupleIdAndIsActiveTrue(couple.id)

        data class PmStats(val txAmount: Long, val txCount: Int, val transferOut: Long, val transferIn: Long) {
            val totalSpending get() = txAmount + transferOut
        }

        val statsList = allPaymentMethods.map { pm ->
            val tx = txExpenseMap[pm.id]
            PmStats(
                txAmount = tx?.first ?: 0,
                txCount = tx?.second ?: 0,
                transferOut = transferOutMap[pm.id] ?: 0,
                transferIn = transferInMap[pm.id] ?: 0
            ) to pm
        }

        val grandTotal = statsList.sumOf { it.first.totalSpending }

        return statsList.map { (stats, pm) ->
            PaymentMethodStatResponse(
                paymentMethodId = pm.id.toString(),
                paymentMethodName = pm.name,
                paymentMethodType = pm.type.name,
                totalAmount = stats.totalSpending,
                transactionCount = stats.txCount,
                percentage = if (grandTotal > 0) {
                    Math.round(stats.totalSpending.toDouble() / grandTotal * 1000) / 10.0
                } else {
                    0.0
                },
                transferOut = if (stats.transferOut > 0) stats.transferOut else null,
                transferIn = if (stats.transferIn > 0) stats.transferIn else null
            )
        }.sortedByDescending { it.totalAmount }
    }
}
