package com.budgetbook.budget.service

import com.budgetbook.budget.dto.BudgetAlertResponse
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.YearMonth
import java.util.UUID

@Service
class BudgetAlertService(
    private val budgetRepository: MonthlyBudgetRepository,
    private val transactionRepository: TransactionRepository,
    private val coupleResolver: CoupleResolver
) {

    @Transactional(readOnly = true)
    fun getBudgetAlerts(userId: UUID, yearMonth: String): List<BudgetAlertResponse> {
        val couple = coupleResolver.getActiveCouple(userId)

        val parts = yearMonth.split("-")
        val ym = YearMonth.of(parts[0].toInt(), parts[1].toInt())
        val startDate = ym.atDay(1)
        val endDate = ym.atEndOfMonth()

        val budgets = budgetRepository.findByCoupleIdAndYearMonth(couple.id, yearMonth)
        if (budgets.isEmpty()) return emptyList()

        // Single aggregation query: GROUP BY category
        val categoryExpenseResults = transactionRepository.sumByCategoryForCouple(
            couple.id, startDate, endDate, TransactionType.EXPENSE
        )
        val spendingByCategory = categoryExpenseResults.associate { row ->
            (row[2] as UUID) to (row[0] as Long)
        }

        // For total budget (no category), get total expenses
        val totalExpense = transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id,
            startDate = startDate,
            endDate = endDate,
            type = TransactionType.EXPENSE
        )

        return budgets.mapNotNull { budget ->
            val categoryId = budget.category?.id
            val categoryName = budget.category?.name ?: "Total"
            val budgetAmount = budget.amount

            val spentAmount = if (categoryId != null) {
                spendingByCategory[categoryId] ?: 0L
            } else {
                totalExpense
            }

            val percentage = if (budgetAmount > 0) {
                ((spentAmount.toDouble() / budgetAmount) * 100).toInt()
            } else {
                0
            }

            val alertLevel = when {
                percentage >= 100 -> "EXCEEDED"
                percentage >= 80 -> "WARNING"
                else -> "SAFE"
            }

            // Only return WARNING or EXCEEDED
            if (alertLevel == "SAFE") {
                null
            } else {
                BudgetAlertResponse(
                    categoryId = categoryId?.toString() ?: "",
                    categoryName = categoryName,
                    budgetAmount = budgetAmount,
                    spentAmount = spentAmount,
                    percentage = percentage,
                    alertLevel = alertLevel
                )
            }
        }
    }
}
