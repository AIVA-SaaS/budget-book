package com.budgetbook.report.service

import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.budget.service.WeeklyBudgetService
import com.budgetbook.category.domain.BudgetType
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.report.dto.CardPendingReportSummary
import com.budgetbook.report.dto.CategorySpendingItem
import com.budgetbook.report.dto.DailySpendingItem
import com.budgetbook.report.dto.DayOfWeekPattern
import com.budgetbook.report.dto.GroupSpendingSummary
import com.budgetbook.report.dto.MonthComparisonResponse
import com.budgetbook.report.dto.MonthlyReportResponse
import com.budgetbook.report.dto.WeeklyReportResponse
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CategorySummary
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale
import java.util.UUID

@Service
class ReportService(
    private val transactionRepository: TransactionRepository,
    override val coupleResolver: CoupleResolver,
    private val categoryGroupRepository: CategoryGroupRepository,
    private val categoryRepository: CategoryRepository,
    private val budgetRepository: MonthlyBudgetRepository
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun getWeeklyReport(userId: UUID, year: Int, month: Int, weekNumber: Int): WeeklyReportResponse {
        val couple = getActiveCouple(userId)
        val yearMonth = YearMonth.of(year, month)
        val validWeek = weekNumber.coerceIn(1, 5)

        // Calculate week date range
        val (weekStart, weekEnd) = calculateWeekRange(yearMonth, validWeek)
        val yearMonthStr = yearMonth.toString()

        // Get expense transactions for this week
        val weekTransactions = transactionRepository.findByCoupleIdAndFilters(
            coupleId = couple.id,
            startDate = weekStart,
            endDate = weekEnd,
            type = TransactionType.EXPENSE,
            categoryId = null,
            userId = userId,
            pageable = PageRequest.of(0, MAX_TRANSACTIONS_PER_QUERY)
        ).content

        val totalSpent = weekTransactions.sumOf { it.amount }

        // Calculate total budget from WEEKLY groups' monthly budgets (divided by weeks in month)
        val weeksInMonth = getWeeksInMonth(yearMonth)
        val totalBudget = calculateWeeklyBudget(couple.id, yearMonthStr, weeksInMonth, userId)

        val remainingAmount = totalBudget - totalSpent
        val usageRate = if (totalBudget > 0) {
            Math.round(totalSpent.toDouble() / totalBudget * 1000.0) / 10.0
        } else 0.0

        // Determine status
        val today = LocalDate.now()
        val status = when {
            totalBudget > 0 && totalSpent >= totalBudget -> "OVER"
            today in weekStart..weekEnd -> "IN_PROGRESS"
            else -> "UNDER"
        }

        // Calculate category spending with 4-week average comparison
        val prevStart = weekStart.minusDays(28)
        val prevEnd = weekStart.minusDays(1)
        val topOverspendCategories = calculateCategorySpending(
            couple.id, weekStart, weekEnd, prevStart, prevEnd, userId
        )

        // Daily spending breakdown
        val dailySpending = calculateDailySpending(weekTransactions, weekStart, weekEnd)

        // Peak spending day
        val peakSpendingDay = dailySpending
            .maxByOrNull { it.amount }
            ?.takeIf { it.amount > 0 }
            ?.dayOfWeek

        return WeeklyReportResponse(
            yearMonth = yearMonthStr,
            weekNumber = validWeek,
            weekStart = weekStart.toString(),
            weekEnd = weekEnd.toString(),
            totalBudget = totalBudget,
            totalSpent = totalSpent,
            remainingAmount = remainingAmount,
            usageRate = usageRate,
            status = status,
            topOverspendCategories = topOverspendCategories,
            dailySpending = dailySpending,
            peakSpendingDay = peakSpendingDay
        )
    }

    @Transactional(readOnly = true)
    fun getMonthlyReport(userId: UUID, year: Int, month: Int): MonthlyReportResponse {
        val couple = getActiveCouple(userId)
        val yearMonth = YearMonth.of(year, month)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()
        val yearMonthStr = yearMonth.toString()

        // Get income/expense totals
        val typeResults = transactionRepository.sumByTypeForCouple(couple.id, startDate, endDate, userId)
        var totalIncome = 0L
        var totalExpense = 0L
        for (row in typeResults) {
            val type = row[0] as TransactionType
            val sum = row[1] as Long
            when (type) {
                TransactionType.INCOME -> totalIncome = sum
                TransactionType.EXPENSE -> totalExpense = sum
            }
        }
        val balance = totalIncome - totalExpense

        // Fetch category expenses ONCE and share between group summaries and top categories
        val currentCategoryExpenses = transactionRepository.sumByCategoryForCouple(
            couple.id, startDate, endDate, TransactionType.EXPENSE, userId
        )

        // Group summaries
        val groupSummaries = calculateGroupSummaries(couple.id, yearMonthStr, userId, currentCategoryExpenses)

        // Top 5 categories by amount
        val topCategories = calculateTopCategories(couple.id, year, month, userId, currentCategoryExpenses)

        // Previous month comparison
        val previousMonthComparison = calculatePreviousMonthComparison(
            couple.id, yearMonth, totalIncome, totalExpense, userId
        )

        // Card pending summary
        val cardPendingSummary = calculateCardPendingSummary(couple.id, startDate, endDate, userId)

        // Day of week pattern
        val allExpenseTransactions = transactionRepository.findByCoupleIdAndFilters(
            coupleId = couple.id,
            startDate = startDate,
            endDate = endDate,
            type = TransactionType.EXPENSE,
            categoryId = null,
            userId = userId,
            pageable = PageRequest.of(0, MAX_TRANSACTIONS_PER_QUERY)
        ).content

        val dayOfWeekPattern = calculateDayOfWeekPattern(allExpenseTransactions, yearMonth)

        return MonthlyReportResponse(
            yearMonth = yearMonthStr,
            totalIncome = totalIncome,
            totalExpense = totalExpense,
            balance = balance,
            groupSummaries = groupSummaries,
            topCategories = topCategories,
            previousMonthComparison = previousMonthComparison,
            cardPendingSummary = cardPendingSummary,
            dayOfWeekPattern = dayOfWeekPattern
        )
    }

    companion object {
        /** Safety limit to prevent OOM when loading transactions for reports */
        private const val MAX_TRANSACTIONS_PER_QUERY = 10_000
    }

    // --- Internal helpers ---

    internal fun calculateWeekRange(yearMonth: YearMonth, weekNumber: Int): Pair<LocalDate, LocalDate> {
        val weekRanges = WeeklyBudgetService.calculateWeekRanges(yearMonth)
        val index = (weekNumber - 1).coerceIn(0, weekRanges.size - 1)
        return weekRanges[index]
    }

    internal fun getWeeksInMonth(yearMonth: YearMonth): Int {
        val daysInMonth = yearMonth.lengthOfMonth()
        return if (daysInMonth > 28) 5 else 4
    }

    private fun calculateWeeklyBudget(coupleId: UUID, yearMonth: String, weeksInMonth: Int, userId: UUID): Long {
        val budgets = budgetRepository.findByCoupleIdAndYearMonthAndUserId(coupleId, yearMonth, userId)
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

    private fun calculateCategorySpending(
        coupleId: UUID,
        weekStart: LocalDate,
        weekEnd: LocalDate,
        prevStart: LocalDate,
        prevEnd: LocalDate,
        userId: UUID
    ): List<CategorySpendingItem> {
        // Current week spending by category
        val currentResults = transactionRepository.sumByCategoryForCouple(
            coupleId, weekStart, weekEnd, TransactionType.EXPENSE, userId
        )

        // Previous 4 weeks spending by category (for average)
        val prevResults = transactionRepository.sumByCategoryForCouple(
            coupleId, prevStart, prevEnd, TransactionType.EXPENSE, userId
        )
        val prevMap = prevResults.associate { row ->
            val catId = row[2] as UUID
            val amount = row[0] as Long
            catId to amount
        }

        return currentResults.map { row ->
            val amount = row[0] as Long
            val count = (row[1] as Long).toInt()
            val catId = row[2] as UUID
            val catName = row[3] as String
            val catType = (row[4] as Enum<*>).name
            val catIcon = row[5] as? String
            val catColor = row[6] as? String

            val avgAmount = (prevMap[catId] ?: 0L) / 4

            CategorySpendingItem(
                category = CategorySummary(
                    id = catId,
                    name = catName,
                    type = catType,
                    icon = catIcon,
                    color = catColor
                ),
                amount = amount,
                averageAmount = avgAmount,
                deviation = amount - avgAmount,
                transactionCount = count
            )
        }.sortedByDescending { it.deviation }
    }

    private fun calculateDailySpending(
        transactions: List<com.budgetbook.transaction.domain.Transaction>,
        weekStart: LocalDate,
        weekEnd: LocalDate
    ): List<DailySpendingItem> {
        val byDate = transactions.groupBy { it.transactionDate }

        return generateSequence(weekStart) { it.plusDays(1) }
            .takeWhile { !it.isAfter(weekEnd) }
            .map { date ->
                val dayTxs = byDate[date] ?: emptyList()
                DailySpendingItem(
                    date = date.toString(),
                    dayOfWeek = toDayOfWeekAbbr(date.dayOfWeek),
                    amount = dayTxs.sumOf { it.amount },
                    transactionCount = dayTxs.size
                )
            }
            .toList()
    }

    private fun calculateGroupSummaries(
        coupleId: UUID,
        yearMonth: String,
        userId: UUID,
        currentCategoryExpenses: List<Array<Any?>>
    ): List<GroupSpendingSummary> {
        val groups = categoryGroupRepository.findByCoupleIdAndUserIdOrderByDisplayOrder(coupleId, userId)
        val budgets = budgetRepository.findByCoupleIdAndYearMonthAndUserId(coupleId, yearMonth, userId)

        val expenseByCategoryId = currentCategoryExpenses.associate { row ->
            (row[2] as UUID) to (row[0] as Long)
        }

        return groups.map { group ->
            // Get categories in this group
            val categories = categoryRepository.findByCoupleIdAndGroupId(coupleId, group.id)
            val categoryIds = categories.map { it.id }.toSet()

            // Sum budgets for this group's categories
            val groupBudget = budgets
                .filter { it.category != null && it.category!!.id in categoryIds }
                .sumOf { it.amount }

            // Sum expenses for this group's categories from pre-fetched data
            val groupSpent = categoryIds.sumOf { expenseByCategoryId[it] ?: 0L }

            val usageRate = if (groupBudget > 0) {
                Math.round(groupSpent.toDouble() / groupBudget * 1000.0) / 10.0
            } else 0.0

            GroupSpendingSummary(
                groupId = group.id,
                groupName = group.name,
                budgetType = group.budgetType.name,
                totalBudget = groupBudget,
                totalSpent = groupSpent,
                usageRate = usageRate
            )
        }
    }

    private fun calculateTopCategories(
        coupleId: UUID,
        year: Int,
        month: Int,
        userId: UUID,
        currentCategoryExpenses: List<Array<Any?>>
    ): List<CategorySpendingItem> {
        val currentResults = currentCategoryExpenses

        // Previous month for average comparison
        val prevMonth = YearMonth.of(year, month).minusMonths(1)
        val prevStart = prevMonth.atDay(1)
        val prevEnd = prevMonth.atEndOfMonth()
        val prevResults = transactionRepository.sumByCategoryForCouple(
            coupleId, prevStart, prevEnd, TransactionType.EXPENSE, userId
        )
        val prevMap = prevResults.associate { row ->
            val catId = row[2] as UUID
            val amount = row[0] as Long
            catId to amount
        }

        return currentResults.take(5).map { row ->
            val amount = row[0] as Long
            val count = (row[1] as Long).toInt()
            val catId = row[2] as UUID
            val catName = row[3] as String
            val catType = (row[4] as Enum<*>).name
            val catIcon = row[5] as? String
            val catColor = row[6] as? String

            val avgAmount = prevMap[catId] ?: 0L

            CategorySpendingItem(
                category = CategorySummary(
                    id = catId,
                    name = catName,
                    type = catType,
                    icon = catIcon,
                    color = catColor
                ),
                amount = amount,
                averageAmount = avgAmount,
                deviation = amount - avgAmount,
                transactionCount = count
            )
        }
    }

    private fun calculatePreviousMonthComparison(
        coupleId: UUID,
        currentMonth: YearMonth,
        currentIncome: Long,
        currentExpense: Long,
        userId: UUID
    ): MonthComparisonResponse? {
        val prevMonth = currentMonth.minusMonths(1)
        val prevStart = prevMonth.atDay(1)
        val prevEnd = prevMonth.atEndOfMonth()

        val prevResults = transactionRepository.sumByTypeForCouple(coupleId, prevStart, prevEnd, userId)

        if (prevResults.isEmpty()) return null

        var prevIncome = 0L
        var prevExpense = 0L
        for (row in prevResults) {
            val type = row[0] as TransactionType
            val sum = row[1] as Long
            when (type) {
                TransactionType.INCOME -> prevIncome = sum
                TransactionType.EXPENSE -> prevExpense = sum
            }
        }

        val incomeChangeRate = if (prevIncome > 0) {
            Math.round((currentIncome - prevIncome).toDouble() / prevIncome * 1000.0) / 10.0
        } else if (currentIncome > 0) 100.0 else 0.0

        val expenseChangeRate = if (prevExpense > 0) {
            Math.round((currentExpense - prevExpense).toDouble() / prevExpense * 1000.0) / 10.0
        } else if (currentExpense > 0) 100.0 else 0.0

        return MonthComparisonResponse(
            previousYearMonth = prevMonth.toString(),
            incomeChange = currentIncome - prevIncome,
            expenseChange = currentExpense - prevExpense,
            incomeChangeRate = incomeChangeRate,
            expenseChangeRate = expenseChangeRate
        )
    }

    private fun calculateCardPendingSummary(
        coupleId: UUID,
        startDate: LocalDate,
        endDate: LocalDate,
        userId: UUID
    ): CardPendingReportSummary? {
        val results = transactionRepository.sumBySettlementDateGroupedByPaymentMethod(
            coupleId, startDate, endDate, userId
        )

        if (results.isEmpty()) return null

        var totalPending = 0L
        var cardsWithPending = 0

        for (row in results) {
            val pendingAmount = (row[1] as Number).toLong()
            if (pendingAmount > 0) {
                totalPending += pendingAmount
                cardsWithPending++
            }
        }

        return if (totalPending > 0) {
            CardPendingReportSummary(
                totalPendingAmount = totalPending,
                cardCount = cardsWithPending
            )
        } else null
    }

    private fun calculateDayOfWeekPattern(
        transactions: List<com.budgetbook.transaction.domain.Transaction>,
        yearMonth: YearMonth
    ): List<DayOfWeekPattern> {
        val byDayOfWeek = transactions.groupBy { it.transactionDate.dayOfWeek }

        // Count how many of each day of week occur in the month
        val dayCountsInMonth = mutableMapOf<DayOfWeek, Int>()
        var date = yearMonth.atDay(1)
        val lastDay = yearMonth.atEndOfMonth()
        while (!date.isAfter(lastDay)) {
            dayCountsInMonth.merge(date.dayOfWeek, 1) { a, b -> a + b }
            date = date.plusDays(1)
        }

        return DayOfWeek.entries.map { dow ->
            val dayTxs = byDayOfWeek[dow] ?: emptyList()
            val totalSpending = dayTxs.sumOf { it.amount }
            val occurrences = dayCountsInMonth[dow] ?: 1
            val avgSpending = if (occurrences > 0) totalSpending / occurrences else 0L

            DayOfWeekPattern(
                dayOfWeek = toDayOfWeekAbbr(dow),
                averageSpending = avgSpending,
                totalSpending = totalSpending,
                transactionCount = dayTxs.size
            )
        }
    }

    private fun toDayOfWeekAbbr(dow: DayOfWeek): String = when (dow) {
        DayOfWeek.MONDAY -> "MON"
        DayOfWeek.TUESDAY -> "TUE"
        DayOfWeek.WEDNESDAY -> "WED"
        DayOfWeek.THURSDAY -> "THU"
        DayOfWeek.FRIDAY -> "FRI"
        DayOfWeek.SATURDAY -> "SAT"
        DayOfWeek.SUNDAY -> "SUN"
    }

}
