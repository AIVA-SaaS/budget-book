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

        // Get expense transactions for the month
        val transactions = transactionRepository.findByCoupleIdAndFilters(
            coupleId = couple.id,
            startDate = startDate,
            endDate = endDate,
            type = TransactionType.EXPENSE,
            categoryId = null,
            pageable = org.springframework.data.domain.Pageable.unpaged()
        )

        // Aggregate spending by category
        val spendingByCategory = transactions.content
            .groupBy { it.category?.id }
            .mapValues { (_, txs) -> txs.sumOf { it.amount } }

        val items = budgets.map { budget ->
            val categoryId = budget.category?.id
            val spentAmount = if (categoryId != null) {
                spendingByCategory[categoryId] ?: 0L
            } else {
                // Total budget: sum all expenses
                transactions.content.sumOf { it.amount }
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

        // Calculate totalSpent independently as the direct sum of ALL expenses for the month,
        // to avoid double-counting when both a "total" budget and category-specific budgets exist
        val totalSpent = transactions.content.sumOf { it.amount }

        return BudgetSummaryResponse(
            yearMonth = yearMonth,
            totalBudget = budgets.sumOf { it.amount },
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
