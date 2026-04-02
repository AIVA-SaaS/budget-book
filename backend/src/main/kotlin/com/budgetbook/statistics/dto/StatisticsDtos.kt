package com.budgetbook.statistics.dto

import com.budgetbook.transaction.dto.CategorySummary

data class StatisticsSummaryResponse(
    val yearMonth: String,
    val totalIncome: Long,
    val totalExpense: Long,
    val balance: Long,
    val transactionCount: Int
)

data class CategoryStatisticsResponse(
    val category: CategorySummary,
    val amount: Long,
    val percentage: Double,
    val transactionCount: Int
)

data class MonthlyTrendResponse(
    val yearMonth: String,
    val totalIncome: Long,
    val totalExpense: Long,
    val balance: Long
)

data class PaymentMethodStatResponse(
    val paymentMethodId: String,
    val paymentMethodName: String,
    val paymentMethodType: String? = null,
    val totalAmount: Long,
    val transactionCount: Int,
    val percentage: Double
)
