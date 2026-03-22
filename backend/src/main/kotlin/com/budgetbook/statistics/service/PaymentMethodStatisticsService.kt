package com.budgetbook.statistics.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.statistics.dto.PaymentMethodStatResponse
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.YearMonth
import java.util.UUID

@Service
class PaymentMethodStatisticsService(
    private val transactionRepository: TransactionRepository,
    private val coupleResolver: CoupleResolver
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

        // Single aggregation query with GROUP BY payment_method_id
        val results = transactionRepository.sumByPaymentMethodForCouple(
            couple.id, startDate, endDate, userId, visFilter
        )

        if (results.isEmpty()) return emptyList()

        val totalAmount = results.sumOf { (it[2] as Long) }

        return results.map { row ->
            val pmId = row[0] as UUID
            val pmName = row[1] as String
            val amount = row[2] as Long
            val count = (row[3] as Long).toInt()

            PaymentMethodStatResponse(
                paymentMethodId = pmId.toString(),
                paymentMethodName = pmName,
                totalAmount = amount,
                transactionCount = count,
                percentage = if (totalAmount > 0) {
                    Math.round(amount.toDouble() / totalAmount * 1000) / 10.0
                } else {
                    0.0
                }
            )
        }
    }
}
