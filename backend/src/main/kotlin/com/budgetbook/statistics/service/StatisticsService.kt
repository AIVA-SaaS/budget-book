package com.budgetbook.statistics.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.MonthlyTrendResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CategorySummary
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class StatisticsService(
    private val transactionRepository: TransactionRepository,
    override val coupleResolver: CoupleResolver
) : CoupleAwareService {

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
    fun getMonthlySummary(userId: UUID, year: Int, month: Int, visibility: String = "ALL"): StatisticsSummaryResponse {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(visibility)
        val yearMonth = YearMonth.of(year, month)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        val results = transactionRepository.sumByTypeForCouple(couple.id, startDate, endDate, userId, visFilter)

        var totalIncome = 0L
        var totalExpense = 0L
        var transactionCount = 0

        for (row in results) {
            val type = row[0] as TransactionType
            val sum = row[1] as Long
            val count = (row[2] as Long).toInt()
            when (type) {
                TransactionType.INCOME -> {
                    totalIncome = sum
                    transactionCount += count
                }
                TransactionType.EXPENSE -> {
                    totalExpense = sum
                    transactionCount += count
                }
            }
        }

        return StatisticsSummaryResponse(
            yearMonth = yearMonth.toString(),
            totalIncome = totalIncome,
            totalExpense = totalExpense,
            balance = totalIncome - totalExpense,
            transactionCount = transactionCount
        )
    }

    @Transactional(readOnly = true)
    fun getCategoryBreakdown(userId: UUID, year: Int, month: Int, type: String?, visibility: String = "ALL"): List<CategoryStatisticsResponse> {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(visibility)
        val yearMonth = YearMonth.of(year, month)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        val transactionType = try {
            TransactionType.valueOf(type ?: "EXPENSE")
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: $type")
        }

        val results = transactionRepository.sumByCategoryForCouple(couple.id, startDate, endDate, transactionType, userId, visFilter)

        val totalAmount = results.sumOf { it[0] as Long }

        return results.map { row ->
            val amount = row[0] as Long
            val count = (row[1] as Long).toInt()
            val catId = row[2] as UUID
            val catName = row[3] as String
            val catType = (row[4] as Enum<*>).name
            val catIcon = row[5] as? String
            val catColor = row[6] as? String

            CategoryStatisticsResponse(
                category = CategorySummary(
                    id = catId,
                    name = catName,
                    type = catType,
                    icon = catIcon,
                    color = catColor
                ),
                amount = amount,
                percentage = if (totalAmount > 0) {
                    Math.round(amount.toDouble() / totalAmount * 1000) / 10.0
                } else 0.0,
                transactionCount = count
            )
        }
    }

    @Transactional(readOnly = true)
    fun getMonthlyTrend(userId: UUID, months: Int, visibility: String = "ALL"): List<MonthlyTrendResponse> {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(visibility)
        val validMonths = months.coerceIn(1, 24)
        val now = YearMonth.now()
        val startMonth = now.minusMonths((validMonths - 1).toLong())
        val startDate = startMonth.atDay(1)
        val endDate = now.atEndOfMonth()

        val results = transactionRepository.monthlyTrendForCouple(couple.id, startDate, endDate, userId, visFilter)

        val trendMap = mutableMapOf<String, Pair<Long, Long>>()

        for (row in results) {
            val ym = row[0] as String
            val typeName = row[1] as String
            val sum = (row[2] as Number).toLong()
            val current = trendMap.getOrDefault(ym, 0L to 0L)
            trendMap[ym] = when (typeName) {
                "INCOME" -> sum to current.second
                "EXPENSE" -> current.first to sum
                else -> current
            }
        }

        return (0 until validMonths).map { offset ->
            val ym = startMonth.plusMonths(offset.toLong())
            val ymStr = ym.toString()
            val (income, expense) = trendMap.getOrDefault(ymStr, 0L to 0L)
            MonthlyTrendResponse(
                yearMonth = ymStr,
                totalIncome = income,
                totalExpense = expense,
                balance = income - expense
            )
        }
    }

}
