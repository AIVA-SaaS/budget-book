package com.budgetbook.budget.service

import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.WeeklyBudgetSnapshot
import com.budgetbook.budget.domain.WeeklyStatus
import com.budgetbook.budget.dto.CurrentWeekSummaryResponse
import com.budgetbook.budget.dto.WeeklyBudgetItemResponse
import com.budgetbook.budget.dto.WeeklyOverviewResponse
import com.budgetbook.budget.dto.WeeklyWeekResponse
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.budget.repository.WeeklyBudgetSnapshotRepository
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.ChronoUnit
import java.util.UUID

@Service
class WeeklyBudgetService(
    private val snapshotRepository: WeeklyBudgetSnapshotRepository,
    private val budgetRepository: MonthlyBudgetRepository,
    override val coupleResolver: CoupleResolver,
    private val categoryGroupRepository: CategoryGroupRepository,
    private val categoryRepository: CategoryRepository,
    private val transactionRepository: TransactionRepository
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun getWeeklyOverview(userId: UUID, year: Int, month: Int): WeeklyOverviewResponse {
        val couple = getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        val ym = YearMonth.of(year, month)
        val weekRanges = calculateWeekRanges(ym)

        // Only WEEKLY budgets for the weekly view
        val allBudgets = MonthlyBudgetResolver.resolveForMonth(
            budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, userId)
        )
        val weeklyBudgets = allBudgets.filter { it.budgetPeriod == BudgetPeriod.WEEKLY }

        // Early return if no WEEKLY budgets
        if (weeklyBudgets.isEmpty()) {
            val weeks = weekRanges.mapIndexed { index, (weekStart, weekEnd) ->
                WeeklyWeekResponse(
                    weekNumber = index + 1,
                    weekStart = weekStart.toString(),
                    weekEnd = weekEnd.toString(),
                    totalBudget = 0,
                    totalSpent = 0,
                    totalRemaining = 0,
                    items = emptyList()
                )
            }
            return WeeklyOverviewResponse(yearMonth = yearMonth, weeks = weeks)
        }

        // Collect all category/group IDs from weekly budgets for batch queries
        val budgetCategoryIds = weeklyBudgets.mapNotNull { it.category?.id }.toSet()
        val budgetGroupIds = weeklyBudgets.mapNotNull { it.group?.id }.toSet()

        // For group budgets, collect underlying category IDs
        val categoriesInGroups: Map<UUID, Set<UUID>> = if (budgetGroupIds.isNotEmpty()) {
            val allCategories = categoryRepository.findByCoupleId(couple.id)
            budgetGroupIds.associateWith { groupId ->
                allCategories.filter { it.group?.id == groupId }.map { it.id }.toSet()
            }
        } else {
            emptyMap()
        }

        // Pre-compute per-budget pro-rata amounts for each week,
        // with the last week receiving the remainder to eliminate rounding errors.
        val proRataByBudgetAndWeek: Map<UUID, List<Long>> = weeklyBudgets.associate { budget ->
            val perWeekAmount = budget.weeklyAmount ?: (budget.amount * 7L / ym.lengthOfMonth())
            val monthlyTotal = perWeekAmount * ym.lengthOfMonth().toLong() / 7
            val amounts = weekRanges.mapIndexed { index, (weekStart, weekEnd) ->
                if (index == weekRanges.size - 1) {
                    // Last week gets the remainder
                    val sumOfPrevious = weekRanges.take(index).sumOf { (s, e) ->
                        calculateProRataBudget(perWeekAmount, s, e)
                    }
                    monthlyTotal - sumOfPrevious
                } else {
                    calculateProRataBudget(perWeekAmount, weekStart, weekEnd)
                }
            }
            budget.id to amounts
        }

        val weeks = weekRanges.mapIndexed { index, (weekStart, weekEnd) ->
            val weekNumber = index + 1

            // Batch query: spending per category for this week
            val allRelevantCategoryIds = budgetCategoryIds + categoriesInGroups.values.flatten().toSet()
            val spentByCategoryId: Map<UUID, Long> = if (allRelevantCategoryIds.isNotEmpty()) {
                transactionRepository.sumAmountGroupedByCategoryId(
                    coupleId = couple.id,
                    startDate = weekStart,
                    endDate = weekEnd,
                    type = TransactionType.EXPENSE,
                    categoryIds = allRelevantCategoryIds,
                    userId = userId
                ).associate { row ->
                    val categoryId = row[0] as UUID
                    val amount = (row[1] as Number).toLong()
                    categoryId to amount
                }
            } else {
                emptyMap()
            }

            // For budgets with no category/group (total budget), get total spending
            val hasUncategorizedBudget = weeklyBudgets.any { it.category == null && it.group == null }
            val totalSpentForWeek: Long = if (hasUncategorizedBudget) {
                transactionRepository.sumAmountByCoupleIdAndDateRange(
                    coupleId = couple.id,
                    startDate = weekStart,
                    endDate = weekEnd,
                    type = TransactionType.EXPENSE,
                    userId = userId
                )
            } else 0L

            val items = weeklyBudgets.map { budget ->
                val proRataBudget = proRataByBudgetAndWeek[budget.id]!![index]

                val spentAmount: Long = when {
                    budget.category != null -> spentByCategoryId[budget.category!!.id] ?: 0L
                    budget.group != null -> {
                        val catIds = categoriesInGroups[budget.group!!.id] ?: emptySet()
                        catIds.sumOf { catId -> spentByCategoryId[catId] ?: 0L }
                    }
                    else -> totalSpentForWeek
                }

                val remaining = proRataBudget - spentAmount
                val usageRate = if (proRataBudget > 0) {
                    Math.round(spentAmount.toDouble() / proRataBudget * 1000.0) / 10.0
                } else 0.0

                WeeklyBudgetItemResponse(
                    budgetId = budget.id,
                    categoryId = budget.category?.id,
                    categoryName = budget.category?.name,
                    groupId = budget.group?.id,
                    groupName = budget.group?.name,
                    budgetAmount = proRataBudget,
                    spentAmount = spentAmount,
                    remainingAmount = remaining,
                    usageRate = usageRate
                )
            }

            val totalBudget = items.sumOf { it.budgetAmount }
            val totalSpent = items.sumOf { it.spentAmount }

            WeeklyWeekResponse(
                weekNumber = weekNumber,
                weekStart = weekStart.toString(),
                weekEnd = weekEnd.toString(),
                totalBudget = totalBudget,
                totalSpent = totalSpent,
                totalRemaining = totalBudget - totalSpent,
                items = items
            )
        }

        return WeeklyOverviewResponse(
            yearMonth = yearMonth,
            weeks = weeks
        )
    }

    @Transactional(readOnly = true)
    fun getCurrentWeekSummary(userId: UUID): CurrentWeekSummaryResponse {
        val couple = getActiveCouple(userId)
        val today = LocalDate.now()
        val ym = YearMonth.of(today.year, today.monthValue)
        val yearMonth = formatYearMonth(today.year, today.monthValue)

        val weekRanges = calculateWeekRanges(ym)
        val currentWeekIndex = weekRanges.indexOfFirst { (start, end) ->
            !today.isBefore(start) && !today.isAfter(end)
        }
        val weekNumber = currentWeekIndex + 1
        val (weekStart, weekEnd) = weekRanges[currentWeekIndex]

        // Only WEEKLY budgets
        val allBudgets = MonthlyBudgetResolver.resolveForMonth(
            budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, userId)
        )
        val weeklyBudgets = allBudgets.filter { it.budgetPeriod == BudgetPeriod.WEEKLY }

        // Early return if no WEEKLY budgets
        if (weeklyBudgets.isEmpty()) {
            return CurrentWeekSummaryResponse(
                yearMonth = yearMonth,
                weekNumber = weekNumber,
                weekStart = weekStart.toString(),
                weekEnd = weekEnd.toString(),
                items = emptyList()
            )
        }

        // Collect category IDs for batch query
        val budgetCategoryIds = weeklyBudgets.mapNotNull { it.category?.id }.toSet()
        val budgetGroupIds = weeklyBudgets.mapNotNull { it.group?.id }.toSet()

        val categoriesInGroups: Map<UUID, Set<UUID>> = if (budgetGroupIds.isNotEmpty()) {
            val allCategories = categoryRepository.findByCoupleId(couple.id)
            budgetGroupIds.associateWith { groupId ->
                allCategories.filter { it.group?.id == groupId }.map { it.id }.toSet()
            }
        } else {
            emptyMap()
        }

        val allRelevantCategoryIds = budgetCategoryIds + categoriesInGroups.values.flatten().toSet()
        val spentByCategoryId: Map<UUID, Long> = if (allRelevantCategoryIds.isNotEmpty()) {
            transactionRepository.sumAmountGroupedByCategoryId(
                coupleId = couple.id,
                startDate = weekStart,
                endDate = weekEnd,
                type = TransactionType.EXPENSE,
                categoryIds = allRelevantCategoryIds,
                userId = userId
            ).associate { row ->
                val categoryId = row[0] as UUID
                val amount = (row[1] as Number).toLong()
                categoryId to amount
            }
        } else {
            emptyMap()
        }

        val hasUncategorizedBudget = weeklyBudgets.any { it.category == null && it.group == null }
        val totalSpentForWeek: Long = if (hasUncategorizedBudget) {
            transactionRepository.sumAmountByCoupleIdAndDateRange(
                coupleId = couple.id,
                startDate = weekStart,
                endDate = weekEnd,
                type = TransactionType.EXPENSE,
                userId = userId
            )
        } else 0L

        val isLastWeek = currentWeekIndex == weekRanges.size - 1

        val items = weeklyBudgets.map { budget ->
            val perWeekAmount = budget.weeklyAmount ?: (budget.amount * 7L / ym.lengthOfMonth())
            val proRataBudget = if (isLastWeek) {
                // Last week gets the remainder to eliminate rounding errors
                val monthlyTotal = perWeekAmount * ym.lengthOfMonth().toLong() / 7
                val sumOfPrevious = weekRanges.take(currentWeekIndex).sumOf { (s, e) ->
                    calculateProRataBudget(perWeekAmount, s, e)
                }
                monthlyTotal - sumOfPrevious
            } else {
                calculateProRataBudget(perWeekAmount, weekStart, weekEnd)
            }

            val spentAmount: Long = when {
                budget.category != null -> spentByCategoryId[budget.category!!.id] ?: 0L
                budget.group != null -> {
                    val catIds = categoriesInGroups[budget.group!!.id] ?: emptySet()
                    catIds.sumOf { catId -> spentByCategoryId[catId] ?: 0L }
                }
                else -> totalSpentForWeek
            }

            val remaining = proRataBudget - spentAmount
            val usageRate = if (proRataBudget > 0) {
                Math.round(spentAmount.toDouble() / proRataBudget * 1000.0) / 10.0
            } else 0.0

            WeeklyBudgetItemResponse(
                budgetId = budget.id,
                categoryId = budget.category?.id,
                categoryName = budget.category?.name,
                groupId = budget.group?.id,
                groupName = budget.group?.name,
                budgetAmount = proRataBudget,
                spentAmount = spentAmount,
                remainingAmount = remaining,
                usageRate = usageRate
            )
        }

        return CurrentWeekSummaryResponse(
            yearMonth = yearMonth,
            weekNumber = weekNumber,
            weekStart = weekStart.toString(),
            weekEnd = weekEnd.toString(),
            items = items
        )
    }

    @Transactional
    fun refreshWeeklySnapshots(userId: UUID, year: Int, month: Int) {
        val couple = getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        val ym = YearMonth.of(year, month)
        val weekRanges = calculateWeekRanges(ym)
        val today = LocalDate.now()

        // Per-week budget amount (before pro-rata) - WEEKLY budgets only
        val perWeekBudget = calculatePerWeekBudgetAmount(couple.id, yearMonth, userId)
        val monthlyTotal = perWeekBudget * ym.lengthOfMonth().toLong() / 7

        weekRanges.forEachIndexed { index, (weekStart, weekEnd) ->
            val weekNumber = index + 1
            // Pro-rata budget; last week gets remainder to eliminate rounding errors
            val budgetAmount = if (index == weekRanges.size - 1) {
                val sumOfPrevious = weekRanges.take(index).sumOf { (s, e) ->
                    calculateProRataBudget(perWeekBudget, s, e)
                }
                monthlyTotal - sumOfPrevious
            } else {
                calculateProRataBudget(perWeekBudget, weekStart, weekEnd)
            }
            val spent = calculateSpentForPeriod(couple.id, weekStart, weekEnd, userId)

            val status = when {
                weekEnd.isBefore(today) && spent <= budgetAmount -> WeeklyStatus.UNDER
                weekEnd.isBefore(today) && spent > budgetAmount -> WeeklyStatus.OVER
                else -> WeeklyStatus.IN_PROGRESS
            }

            val existing = snapshotRepository.findByCoupleIdAndYearMonthAndWeekNumber(
                couple.id, yearMonth, weekNumber
            )

            if (existing != null) {
                existing.spentAmount = spent
                existing.budgetAmount = budgetAmount
                existing.status = status
                snapshotRepository.save(existing)
            } else {
                snapshotRepository.save(
                    WeeklyBudgetSnapshot(
                        couple = couple,
                        yearMonth = yearMonth,
                        weekNumber = weekNumber,
                        weekStart = weekStart,
                        weekEnd = weekEnd,
                        budgetAmount = budgetAmount,
                        spentAmount = spent,
                        status = status
                    )
                )
            }
        }
    }

    private fun calculateSpentForPeriod(coupleId: UUID, start: LocalDate, end: LocalDate, userId: UUID): Long {
        return transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = coupleId,
            startDate = start,
            endDate = end,
            type = TransactionType.EXPENSE,
            userId = userId
        )
    }

    /**
     * Returns the per-week budget amount (before pro-rata adjustment) from WEEKLY budgets only.
     * This is the budget for a full 7-day week; partial weeks should
     * be scaled using [calculateProRataBudget].
     */
    private fun calculatePerWeekBudgetAmount(coupleId: UUID, yearMonth: String, userId: UUID): Long {
        val budgets = MonthlyBudgetResolver.resolveForMonth(
            budgetRepository.findByCoupleIdAndYearMonthAndUserId(coupleId, yearMonth, userId)
        )
        val weeklyBudgets = budgets.filter { it.budgetPeriod == BudgetPeriod.WEEKLY }
        if (weeklyBudgets.isEmpty()) return 0L

        // Sum weekly contributions: use weeklyAmount if set, otherwise derive from monthly
        val parts = yearMonth.split("-")
        val ym = YearMonth.of(parts[0].toInt(), parts[1].toInt())
        val daysInMonth = ym.lengthOfMonth()

        return weeklyBudgets.sumOf { budget ->
            budget.weeklyAmount ?: ((budget.amount * 7) / daysInMonth)
        }
    }

    private fun formatYearMonth(year: Int, month: Int): String =
        "%04d-%02d".format(year, month)

    companion object {
        /**
         * Calculates real Monday-Sunday week ranges for a given month,
         * clipping to the month boundaries.
         */
        fun calculateWeekRanges(yearMonth: YearMonth): List<Pair<LocalDate, LocalDate>> {
            val firstDay = yearMonth.atDay(1)
            val lastDay = yearMonth.atEndOfMonth()
            val ranges = mutableListOf<Pair<LocalDate, LocalDate>>()

            var weekStart = firstDay.with(DayOfWeek.MONDAY)
            if (weekStart.isAfter(firstDay)) {
                weekStart = weekStart.minusWeeks(1)
            }

            while (!weekStart.isAfter(lastDay)) {
                val weekEnd = weekStart.plusDays(6)
                val effectiveStart = if (weekStart.isBefore(firstDay)) firstDay else weekStart
                val effectiveEnd = if (weekEnd.isAfter(lastDay)) lastDay else weekEnd
                ranges.add(effectiveStart to effectiveEnd)
                weekStart = weekStart.plusWeeks(1)
            }

            return ranges
        }

        /**
         * Calculate the pro-rata budget for a week range within a month.
         * Full week (7 days in month) = weeklyBudgetAmount
         * Partial week (N days in month) = weeklyBudgetAmount * N / 7
         */
        fun calculateProRataBudget(weeklyAmount: Long, start: LocalDate, end: LocalDate): Long {
            val days = ChronoUnit.DAYS.between(start, end) + 1
            return (weeklyAmount * days) / 7
        }
    }
}
