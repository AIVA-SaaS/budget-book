package com.budgetbook.statistics.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.statistics.dto.PaymentMethodStatResponse
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.YearMonth
import java.util.UUID

@Service
class PaymentMethodStatisticsService(
    private val transactionRepository: TransactionRepository,
    private val coupleResolver: CoupleResolver,
    private val paymentMethodRepository: PaymentMethodRepository
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

        val totalAmount = results.sumOf { (it[2] as Long) }

        // Build map of payment methods with transaction data
        val statsMap = results.associate { row ->
            val pmId = row[0] as UUID
            pmId to PaymentMethodStatResponse(
                paymentMethodId = pmId.toString(),
                paymentMethodName = row[1] as String,
                totalAmount = row[2] as Long,
                transactionCount = (row[3] as Long).toInt(),
                percentage = if (totalAmount > 0) {
                    Math.round((row[2] as Long).toDouble() / totalAmount * 1000) / 10.0
                } else {
                    0.0
                }
            )
        }

        // Include ALL active payment methods (even those with 0 transactions)
        val allPaymentMethods = paymentMethodRepository.findByCoupleIdAndIsActiveTrue(couple.id)
        return allPaymentMethods.map { pm ->
            val existing = statsMap[pm.id]
            if (existing != null) {
                existing.copy(paymentMethodType = pm.type.name)
            } else {
                PaymentMethodStatResponse(
                    paymentMethodId = pm.id.toString(),
                    paymentMethodName = pm.name,
                    paymentMethodType = pm.type.name,
                    totalAmount = 0,
                    transactionCount = 0,
                    percentage = 0.0
                )
            }
        }.sortedByDescending { it.totalAmount }
    }
}
