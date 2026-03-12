package com.budgetbook.budget.service

import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetResponse
import com.budgetbook.budget.dto.BudgetSummaryItemResponse
import com.budgetbook.budget.dto.BudgetSummaryResponse
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.dto.toResponse
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CategorySummary
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class BudgetService(
    private val budgetRepository: MonthlyBudgetRepository,
    private val coupleRepository: CoupleRepository,
    private val categoryRepository: CategoryRepository,
    private val transactionRepository: TransactionRepository
) {

    @Transactional
    fun createBudget(userId: UUID, request: BudgetRequest): BudgetResponse {
        val couple = getActiveCouple(userId)

        val category = request.categoryId?.let { catId ->
            val cat = categoryRepository.findById(catId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified category does not exist.") }
            if (cat.couple.id != couple.id) {
                throw ForbiddenException("FORBIDDEN", "Category belongs to a different couple.")
            }
            cat
        }

        if (budgetRepository.existsByCoupleIdAndCategoryIdAndYearMonth(couple.id, request.categoryId, request.yearMonth)) {
            throw ConflictException("DUPLICATE_BUDGET", "Budget for this category and month already exists.")
        }

        val budgetPeriod = try {
            BudgetPeriod.valueOf(request.budgetPeriod ?: "MONTHLY")
        } catch (e: IllegalArgumentException) {
            throw com.budgetbook.common.exception.BusinessException(
                "VALIDATION_ERROR", "Invalid budget period: ${request.budgetPeriod}"
            )
        }

        val numberOfWeeks = calculateNumberOfWeeks(request.yearMonth)
        val weeklyAmount = if (budgetPeriod == BudgetPeriod.WEEKLY) {
            request.amount / numberOfWeeks
        } else {
            null
        }

        val budget = MonthlyBudget(
            couple = couple,
            category = category,
            yearMonth = request.yearMonth,
            amount = request.amount,
            budgetPeriod = budgetPeriod,
            weeklyAmount = weeklyAmount
        )

        return budgetRepository.save(budget).toResponse()
    }

    @Transactional(readOnly = true)
    fun getBudgetsByMonth(userId: UUID, year: Int, month: Int): List<BudgetResponse> {
        val couple = getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        return budgetRepository.findByCoupleIdAndYearMonth(couple.id, yearMonth)
            .map { it.toResponse() }
    }

    @Transactional
    fun updateBudget(userId: UUID, budgetId: UUID, request: BudgetUpdateRequest): BudgetResponse {
        val couple = getActiveCouple(userId)
        val budget = budgetRepository.findById(budgetId)
            .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Budget does not exist.") }

        if (budget.couple.id != couple.id) {
            throw ForbiddenException("FORBIDDEN", "Budget belongs to a different couple.")
        }

        budget.amount = request.amount

        request.budgetPeriod?.let { periodStr ->
            val newPeriod = try {
                BudgetPeriod.valueOf(periodStr)
            } catch (e: IllegalArgumentException) {
                throw com.budgetbook.common.exception.BusinessException(
                    "VALIDATION_ERROR", "Invalid budget period: $periodStr"
                )
            }
            budget.budgetPeriod = newPeriod

            // Recalculate weeklyAmount based on new period
            budget.weeklyAmount = if (newPeriod == BudgetPeriod.WEEKLY) {
                request.weeklyAmount ?: (request.amount / calculateNumberOfWeeks(budget.yearMonth))
            } else {
                null
            }
        } ?: run {
            // budgetPeriod not changing, but if it's WEEKLY, update weeklyAmount if provided
            if (budget.budgetPeriod == BudgetPeriod.WEEKLY) {
                budget.weeklyAmount = request.weeklyAmount
                    ?: (request.amount / calculateNumberOfWeeks(budget.yearMonth))
            }
        }

        return budgetRepository.save(budget).toResponse()
    }

    @Transactional
    fun deleteBudget(userId: UUID, budgetId: UUID) {
        val couple = getActiveCouple(userId)
        val budget = budgetRepository.findById(budgetId)
            .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Budget does not exist.") }

        if (budget.couple.id != couple.id) {
            throw ForbiddenException("FORBIDDEN", "Budget belongs to a different couple.")
        }

        budgetRepository.delete(budget)
    }

    @Transactional(readOnly = true)
    fun getBudgetSummary(userId: UUID, year: Int, month: Int): BudgetSummaryResponse {
        val couple = getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        val ym = YearMonth.of(year, month)
        val startDate = ym.atDay(1)
        val endDate = ym.atEndOfMonth()

        val budgets = budgetRepository.findByCoupleIdAndYearMonth(couple.id, yearMonth)

        // Get expense spending aggregated by category using an optimized query
        val categoryExpenseResults = transactionRepository.sumByCategoryForCouple(
            couple.id, startDate, endDate, TransactionType.EXPENSE
        )
        val spendingByCategory = categoryExpenseResults.associate { row ->
            (row[2] as UUID) to (row[0] as Long)
        }

        // Get total expense amount using SUM query
        val totalSpent = transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id,
            startDate = startDate,
            endDate = endDate,
            type = TransactionType.EXPENSE
        )

        val items = budgets.map { budget ->
            val categoryId = budget.category?.id
            val spentAmount = if (categoryId != null) {
                spendingByCategory[categoryId] ?: 0L
            } else {
                // Total budget: sum all expenses
                totalSpent
            }
            val remainingAmount = budget.amount - spentAmount
            val usageRate = if (budget.amount > 0) {
                Math.round(spentAmount.toDouble() / budget.amount * 1000.0) / 10.0
            } else {
                0.0
            }

            BudgetSummaryItemResponse(
                category = budget.category?.let {
                    CategorySummary(
                        id = it.id,
                        name = it.name,
                        type = it.type.name,
                        icon = it.icon,
                        color = it.color
                    )
                },
                budgetAmount = budget.amount,
                spentAmount = spentAmount,
                remainingAmount = remainingAmount,
                usageRate = usageRate
            )
        }

        // When a "total" budget exists (categoryId=null), use that as totalBudget.
        // Otherwise, sum only category-specific budgets to avoid double-counting.
        val totalBudgetEntry = budgets.find { it.category == null }
        val totalBudget = totalBudgetEntry?.amount
            ?: budgets.sumOf { it.amount }

        return BudgetSummaryResponse(
            yearMonth = yearMonth,
            totalBudget = totalBudget,
            totalSpent = totalSpent,
            items = items
        )
    }

    private fun getActiveCouple(userId: UUID): Couple {
        return coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
            ?: throw NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")
    }

    private fun formatYearMonth(year: Int, month: Int): String =
        "%04d-%02d".format(year, month)

    private fun calculateNumberOfWeeks(yearMonth: String): Int {
        val parts = yearMonth.split("-")
        val ym = YearMonth.of(parts[0].toInt(), parts[1].toInt())
        val lastDay = ym.lengthOfMonth()
        return if (lastDay > 28) 5 else 4
    }
}
