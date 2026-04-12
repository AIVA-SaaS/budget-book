package com.budgetbook.smart.service

import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.smart.dto.BudgetSuggestion
import com.budgetbook.smart.dto.Insight
import com.budgetbook.smart.dto.InsightsResponse
import com.budgetbook.statistics.service.StatisticsService
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import com.fasterxml.jackson.databind.ObjectMapper
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Duration
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class SmartAnalysisService(
    private val transactionRepository: TransactionRepository,
    private val budgetRepository: MonthlyBudgetRepository,
    private val statisticsService: StatisticsService,
    private val redisCacheService: RedisCacheService,
    private val objectMapper: ObjectMapper,
    override val coupleResolver: CoupleResolver
) : CoupleAwareService {

    private val log = LoggerFactory.getLogger(javaClass)

    companion object {
        private val CACHE_TTL = Duration.ofDays(1)
        private const val CACHE_PREFIX = "smart:insights"
    }

    @Transactional(readOnly = true)
    fun generateInsights(userId: UUID, year: Int, month: Int): InsightsResponse {
        val couple = getActiveCouple(userId)
        val cacheKey = "$CACHE_PREFIX:${couple.id}:$year:$month"

        // Check Redis cache
        redisCacheService.get(cacheKey)?.let { cached ->
            return try {
                objectMapper.readValue(cached, InsightsResponse::class.java)
            } catch (e: Exception) {
                log.warn("Failed to deserialize cached insights: {}", e.message)
                redisCacheService.evict(cacheKey)
                computeInsights(userId, couple.id, year, month, cacheKey)
            }
        }

        return computeInsights(userId, couple.id, year, month, cacheKey)
    }

    private fun computeInsights(
        userId: UUID,
        coupleId: UUID,
        year: Int,
        month: Int,
        cacheKey: String
    ): InsightsResponse {
        val insights = mutableListOf<Insight>()
        val currentYm = YearMonth.of(year, month)
        val prevYm = currentYm.minusMonths(1)

        // Gather data for current and previous month
        val currentBreakdown = statisticsService.getCategoryBreakdown(userId, year, month, "EXPENSE")
        val prevBreakdown = statisticsService.getCategoryBreakdown(userId, prevYm.year, prevYm.monthValue, "EXPENSE")

        val currentSummary = statisticsService.getMonthlySummary(userId, year, month)
        val prevSummary = statisticsService.getMonthlySummary(userId, prevYm.year, prevYm.monthValue)

        // Rule 1: SPENDING_CHANGE - category spending >20% increase vs previous month
        val prevCategoryMap = prevBreakdown.associate { it.category.name to it.amount }
        for (entry in currentBreakdown) {
            val prevAmount = prevCategoryMap[entry.category.name] ?: continue
            if (prevAmount <= 0) continue
            val changeRate = ((entry.amount - prevAmount).toDouble() / prevAmount * 100).toLong()
            if (changeRate > 20) {
                insights.add(
                    Insight(
                        type = "SPENDING_CHANGE",
                        title = "${entry.category.name} 지출 증가",
                        message = "${entry.category.name} 지출이 전월 대비 ${changeRate}% 증가했습니다. " +
                            "(${formatAmount(prevAmount)} -> ${formatAmount(entry.amount)})",
                        severity = "WARNING",
                        data = mapOf(
                            "categoryName" to entry.category.name,
                            "currentAmount" to entry.amount,
                            "previousAmount" to prevAmount,
                            "changeRate" to changeRate
                        )
                    )
                )
            }
        }

        // Rule 2: BUDGET_WARNING - budget >80% used by mid-month
        val dayOfMonth = LocalDate.now().dayOfMonth
        if (dayOfMonth < 20) {
            val budgets = budgetRepository.findByCoupleIdAndYearMonthAndUserId(
                coupleId, currentYm.toString(), userId
            )
            val currentStart = currentYm.atDay(1)
            val currentEnd = currentYm.atEndOfMonth()

            for (budget in budgets) {
                val effectiveAmount = if (budget.budgetPeriod == BudgetPeriod.WEEKLY) {
                    val weeklyAmt = budget.weeklyAmount ?: (budget.amount * 7 / currentYm.lengthOfMonth())
                    weeklyAmt * currentYm.lengthOfMonth().toLong() / 7
                } else {
                    budget.amount
                }
                if (effectiveAmount <= 0) continue

                val spent = when {
                    budget.category != null -> transactionRepository.sumAmountByCoupleIdAndDateRangeAndCategories(
                        coupleId, currentStart, currentEnd, TransactionType.EXPENSE,
                        setOf(budget.category!!.id), userId
                    )
                    budget.group != null -> transactionRepository.sumAmountByGroupAndDateRange(
                        coupleId, budget.group!!.id, currentStart, currentEnd, TransactionType.EXPENSE, userId
                    )
                    else -> transactionRepository.sumAmountByCoupleIdAndDateRange(
                        coupleId, currentStart, currentEnd, TransactionType.EXPENSE, userId
                    )
                }

                val usageRate = (spent.toDouble() / effectiveAmount * 100).toLong()
                if (usageRate >= 80) {
                    val budgetName = budget.category?.name ?: budget.group?.name ?: "전체"
                    insights.add(
                        Insight(
                            type = "BUDGET_WARNING",
                            title = "$budgetName 예산 주의",
                            message = "$budgetName 예산의 ${usageRate}%를 이미 사용했습니다. " +
                                "남은 금액: ${formatAmount(effectiveAmount - spent)}",
                            severity = "WARNING",
                            data = mapOf(
                                "budgetName" to budgetName,
                                "budgetAmount" to effectiveAmount,
                                "spent" to spent,
                                "usageRate" to usageRate
                            )
                        )
                    )
                }
            }
        }

        // Rule 3: PATTERN - weekend spending > weekday * 1.5
        val currentStart = currentYm.atDay(1)
        val currentEnd = currentYm.atEndOfMonth()
        val dailyData = transactionRepository.dailySummaryForCouple(coupleId, currentStart, currentEnd, userId, "ALL")

        var weekdayTotal = 0L
        var weekdayDays = 0
        var weekendTotal = 0L
        var weekendDays = 0

        val dailyExpenseMap = mutableMapOf<LocalDate, Long>()
        for (row in dailyData) {
            val date = (row[0] as java.sql.Date).toLocalDate()
            val typeName = row[1] as String
            val sum = (row[2] as Number).toLong()
            if (typeName == "EXPENSE") {
                dailyExpenseMap[date] = (dailyExpenseMap[date] ?: 0L) + sum
            }
        }

        for ((date, expense) in dailyExpenseMap) {
            val dayOfWeek = date.dayOfWeek.value
            if (dayOfWeek >= 6) { // Saturday=6, Sunday=7
                weekendTotal += expense
                weekendDays++
            } else {
                weekdayTotal += expense
                weekdayDays++
            }
        }

        if (weekdayDays > 0 && weekendDays > 0) {
            val weekdayAvg = weekdayTotal / weekdayDays
            val weekendAvg = weekendTotal / weekendDays
            if (weekdayAvg > 0 && weekendAvg > weekdayAvg * 1.5) {
                insights.add(
                    Insight(
                        type = "PATTERN",
                        title = "주말 지출 패턴",
                        message = "주말 평균 지출(${formatAmount(weekendAvg)})이 " +
                            "평일 평균(${formatAmount(weekdayAvg)})보다 ${(weekendAvg.toDouble() / weekdayAvg * 100 - 100).toLong()}% 높습니다.",
                        severity = "INFO",
                        data = mapOf(
                            "weekdayAvg" to weekdayAvg,
                            "weekendAvg" to weekendAvg
                        )
                    )
                )
            }
        }

        // Rule 4: TIP - category with consistent monthly spending > 30000
        for (entry in currentBreakdown) {
            if (entry.amount >= 30000) {
                val prevAmount = prevCategoryMap[entry.category.name]
                if (prevAmount != null && prevAmount >= 30000) {
                    val avgAmount = (entry.amount + prevAmount) / 2
                    insights.add(
                        Insight(
                            type = "TIP",
                            title = "${entry.category.name} 절약 팁",
                            message = "${entry.category.name}에 매달 평균 ${formatAmount(avgAmount)}을 지출하고 있습니다. " +
                                "줄일 수 있는 방법을 찾아보세요.",
                            severity = "INFO",
                            data = mapOf(
                                "categoryName" to entry.category.name,
                                "avgAmount" to avgAmount
                            )
                        )
                    )
                }
            }
        }

        // Rule 5: POSITIVE - 3 consecutive months of decreasing total spending
        val twoMonthsAgoYm = currentYm.minusMonths(2)
        val twoMonthsAgoSummary = statisticsService.getMonthlySummary(
            userId, twoMonthsAgoYm.year, twoMonthsAgoYm.monthValue
        )

        if (twoMonthsAgoSummary.totalExpense > prevSummary.totalExpense &&
            prevSummary.totalExpense > currentSummary.totalExpense &&
            currentSummary.totalExpense > 0
        ) {
            insights.add(
                Insight(
                    type = "POSITIVE",
                    title = "3개월 연속 지출 감소",
                    message = "지출이 3개월 연속 줄어들고 있습니다! " +
                        "${formatAmount(twoMonthsAgoSummary.totalExpense)} -> " +
                        "${formatAmount(prevSummary.totalExpense)} -> " +
                        "${formatAmount(currentSummary.totalExpense)}",
                    severity = "POSITIVE",
                    data = mapOf(
                        "months" to listOf(
                            mapOf("yearMonth" to twoMonthsAgoYm.toString(), "expense" to twoMonthsAgoSummary.totalExpense),
                            mapOf("yearMonth" to prevYm.toString(), "expense" to prevSummary.totalExpense),
                            mapOf("yearMonth" to currentYm.toString(), "expense" to currentSummary.totalExpense)
                        )
                    )
                )
            )
        }

        // Rule 6: BUDGET_ADJUST - actual spending vs budget >30% difference (3-month avg)
        insights.addAll(computeBudgetAdjustInsights(userId, coupleId, currentYm))

        val response = InsightsResponse(insights = insights)

        // Cache the result
        try {
            redisCacheService.set(cacheKey, objectMapper.writeValueAsString(response), CACHE_TTL)
        } catch (e: Exception) {
            log.warn("Failed to cache insights: {}", e.message)
        }

        return response
    }

    @Transactional(readOnly = true)
    fun getBudgetSuggestions(userId: UUID): List<BudgetSuggestion> {
        val couple = getActiveCouple(userId)
        val currentYm = YearMonth.now()
        val budgets = budgetRepository.findByCoupleIdAndYearMonthAndUserId(
            couple.id, currentYm.toString(), userId
        )
        if (budgets.isEmpty()) return emptyList()

        val suggestions = mutableListOf<BudgetSuggestion>()

        for (budget in budgets) {
            val effectiveAmount = if (budget.budgetPeriod == BudgetPeriod.WEEKLY) {
                val weeklyAmt = budget.weeklyAmount ?: (budget.amount * 7 / currentYm.lengthOfMonth())
                weeklyAmt * currentYm.lengthOfMonth().toLong() / 7
            } else {
                budget.amount
            }
            if (effectiveAmount <= 0) continue

            val avgSpending = compute3MonthAvgSpending(userId, couple.id, budget, currentYm)
            if (avgSpending <= 0) continue

            val diffRate = Math.abs(effectiveAmount - avgSpending).toDouble() / effectiveAmount * 100
            if (diffRate > 30) {
                val budgetName = budget.category?.name ?: budget.group?.name ?: "전체"
                val reason = if (avgSpending > effectiveAmount) {
                    "최근 3개월 평균 지출(${formatAmount(avgSpending)})이 예산(${formatAmount(effectiveAmount)})보다 높습니다."
                } else {
                    "최근 3개월 평균 지출(${formatAmount(avgSpending)})이 예산(${formatAmount(effectiveAmount)})보다 낮습니다."
                }

                suggestions.add(
                    BudgetSuggestion(
                        budgetId = budget.id,
                        budgetName = budgetName,
                        currentAmount = effectiveAmount,
                        suggestedAmount = avgSpending,
                        avgSpending = avgSpending,
                        reason = reason
                    )
                )
            }
        }

        return suggestions
    }

    private fun computeBudgetAdjustInsights(
        userId: UUID,
        coupleId: UUID,
        currentYm: YearMonth
    ): List<Insight> {
        val budgets = budgetRepository.findByCoupleIdAndYearMonthAndUserId(
            coupleId, currentYm.toString(), userId
        )
        val result = mutableListOf<Insight>()

        for (budget in budgets) {
            val effectiveAmount = if (budget.budgetPeriod == BudgetPeriod.WEEKLY) {
                val weeklyAmt = budget.weeklyAmount ?: (budget.amount * 7 / currentYm.lengthOfMonth())
                weeklyAmt * currentYm.lengthOfMonth().toLong() / 7
            } else {
                budget.amount
            }
            if (effectiveAmount <= 0) continue

            val avgSpending = compute3MonthAvgSpending(userId, coupleId, budget, currentYm)
            if (avgSpending <= 0) continue

            val diffRate = Math.abs(effectiveAmount - avgSpending).toDouble() / effectiveAmount * 100
            if (diffRate > 30) {
                val budgetName = budget.category?.name ?: budget.group?.name ?: "전체"
                result.add(
                    Insight(
                        type = "BUDGET_ADJUST",
                        title = "$budgetName 예산 조정 권장",
                        message = "${budgetName}의 3개월 평균 지출(${formatAmount(avgSpending)})이 " +
                            "예산(${formatAmount(effectiveAmount)})과 ${diffRate.toLong()}% 차이납니다.",
                        severity = "INFO",
                        data = mapOf(
                            "budgetName" to budgetName,
                            "budgetAmount" to effectiveAmount,
                            "avgSpending" to avgSpending,
                            "diffRate" to diffRate.toLong()
                        )
                    )
                )
            }
        }
        return result
    }

    private fun compute3MonthAvgSpending(
        userId: UUID,
        coupleId: UUID,
        budget: com.budgetbook.budget.domain.MonthlyBudget,
        currentYm: YearMonth
    ): Long {
        var totalSpending = 0L
        var monthCount = 0

        for (i in 1..3) {
            val ym = currentYm.minusMonths(i.toLong())
            val start = ym.atDay(1)
            val end = ym.atEndOfMonth()

            val spent = when {
                budget.category != null -> transactionRepository.sumAmountByCoupleIdAndDateRangeAndCategories(
                    coupleId, start, end, TransactionType.EXPENSE,
                    setOf(budget.category!!.id), userId
                )
                budget.group != null -> transactionRepository.sumAmountByGroupAndDateRange(
                    coupleId, budget.group!!.id, start, end, TransactionType.EXPENSE, userId
                )
                else -> transactionRepository.sumAmountByCoupleIdAndDateRange(
                    coupleId, start, end, TransactionType.EXPENSE, userId
                )
            }

            totalSpending += spent
            monthCount++
        }

        return if (monthCount > 0) totalSpending / monthCount else 0L
    }

    private fun formatAmount(amount: Long): String {
        return "${String.format("%,d", amount)}원"
    }
}
