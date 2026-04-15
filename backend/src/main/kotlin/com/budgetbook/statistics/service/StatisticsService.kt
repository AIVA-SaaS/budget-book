package com.budgetbook.statistics.service

import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.spendingplan.repository.SpendingPlanRepository
import com.budgetbook.statistics.dto.BudgetSpending
import com.budgetbook.statistics.dto.CategorySpending
import com.budgetbook.statistics.dto.CategoryStatisticsResponse
import com.budgetbook.statistics.dto.DailySpending
import com.budgetbook.statistics.dto.MonthlyTrendResponse
import com.budgetbook.statistics.dto.PaymentMethodSpending
import com.budgetbook.statistics.dto.PeriodSummaryResponse
import com.budgetbook.statistics.dto.StatisticsSummaryResponse
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CategorySummary
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transaction.repository.TransactionSpecifications
import com.budgetbook.transfer.repository.TransferRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class StatisticsService(
    private val transactionRepository: TransactionRepository,
    private val transferRepository: TransferRepository,
    override val coupleResolver: CoupleResolver,
    private val budgetRepository: MonthlyBudgetRepository,
    private val spendingPlanRepository: SpendingPlanRepository
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
    fun getMonthlySummary(userId: UUID, year: Int, month: Int, visibility: String = "ALL", dateFrom: LocalDate? = null, dateTo: LocalDate? = null): StatisticsSummaryResponse {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(visibility)
        val yearMonth = YearMonth.of(year, month)
        val startDate = dateFrom ?: yearMonth.atDay(1)
        val endDate = dateTo ?: yearMonth.atEndOfMonth()

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

        // Include transfer amounts: OUT = expense, IN = income
        val transferOutResults = transferRepository.sumAmountBySourceExcludingSettlement(couple.id, startDate, endDate)
        val transferOutTotal = transferOutResults.sumOf { it[1] as Long }
        val transferInResults = transferRepository.sumAmountByDestinationExcludingSettlement(couple.id, startDate, endDate)
        val transferInTotal = transferInResults.sumOf { it[1] as Long }

        totalExpense += transferOutTotal
        totalIncome += transferInTotal

        return StatisticsSummaryResponse(
            yearMonth = yearMonth.toString(),
            totalIncome = totalIncome,
            totalExpense = totalExpense,
            balance = totalIncome - totalExpense,
            transactionCount = transactionCount
        )
    }

    @Transactional(readOnly = true)
    fun getCategoryBreakdown(userId: UUID, year: Int, month: Int, type: String?, visibility: String = "ALL", dateFrom: LocalDate? = null, dateTo: LocalDate? = null): List<CategoryStatisticsResponse> {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(visibility)
        val yearMonth = YearMonth.of(year, month)
        val startDate = dateFrom ?: yearMonth.atDay(1)
        val endDate = dateTo ?: yearMonth.atEndOfMonth()

        val transactionType = try {
            TransactionType.valueOf(type ?: "EXPENSE")
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: $type")
        }

        val results = transactionRepository.sumByCategoryForCouple(couple.id, startDate, endDate, transactionType, userId, visFilter)

        val categoryEntries = results.map { row ->
            val amount = row[0] as Long
            val count = (row[1] as Long).toInt()
            val catId = row[2] as UUID
            val catName = row[3] as String
            val catType = (row[4] as Enum<*>).name
            val catIcon = row[5] as? String
            val catColor = row[6] as? String
            val groupId = row[7] as? UUID
            val groupName = row[8] as? String

            CategoryStatisticsResponse(
                category = CategorySummary(
                    id = catId,
                    name = catName,
                    type = catType,
                    icon = catIcon,
                    color = catColor,
                    groupId = groupId,
                    groupName = groupName
                ),
                amount = amount,
                percentage = 0.0, // recalculated below
                transactionCount = count
            )
        }.toMutableList()

        // Include transfers as a virtual "이체" category
        if (transactionType == TransactionType.EXPENSE) {
            val transferOutTotal = transferRepository.sumAmountBySourceExcludingSettlement(couple.id, startDate, endDate)
                .sumOf { it[1] as Long }
            if (transferOutTotal > 0) {
                categoryEntries.add(CategoryStatisticsResponse(
                    category = CategorySummary(
                        id = UUID(0, 0),
                        name = "이체",
                        type = "EXPENSE",
                        icon = "swap_horiz",
                        color = "#009688",
                        groupId = null,
                        groupName = null
                    ),
                    amount = transferOutTotal,
                    percentage = 0.0,
                    transactionCount = 0
                ))
            }
        } else {
            val transferInTotal = transferRepository.sumAmountByDestinationExcludingSettlement(couple.id, startDate, endDate)
                .sumOf { it[1] as Long }
            if (transferInTotal > 0) {
                categoryEntries.add(CategoryStatisticsResponse(
                    category = CategorySummary(
                        id = UUID(0, 0),
                        name = "이체",
                        type = "INCOME",
                        icon = "swap_horiz",
                        color = "#009688",
                        groupId = null,
                        groupName = null
                    ),
                    amount = transferInTotal,
                    percentage = 0.0,
                    transactionCount = 0
                ))
            }
        }

        // Recalculate percentages with transfer included
        val totalAmount = categoryEntries.sumOf { it.amount }
        return categoryEntries.map { entry ->
            entry.copy(
                percentage = if (totalAmount > 0) {
                    Math.round(entry.amount.toDouble() / totalAmount * 1000) / 10.0
                } else 0.0
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

            // Include transfer amounts for this month
            val monthStart = ym.atDay(1)
            val monthEnd = ym.atEndOfMonth()
            val transferOutResults = transferRepository.sumAmountBySourceExcludingSettlement(couple.id, monthStart, monthEnd)
            val transferOutTotal = transferOutResults.sumOf { it[1] as Long }
            val transferInResults = transferRepository.sumAmountByDestinationExcludingSettlement(couple.id, monthStart, monthEnd)
            val transferInTotal = transferInResults.sumOf { it[1] as Long }

            val adjustedIncome = income + transferInTotal
            val adjustedExpense = expense + transferOutTotal

            MonthlyTrendResponse(
                yearMonth = ymStr,
                totalIncome = adjustedIncome,
                totalExpense = adjustedExpense,
                balance = adjustedIncome - adjustedExpense
            )
        }
    }

    @Transactional(readOnly = true)
    fun getPeriodSummary(
        userId: UUID,
        dateFrom: LocalDate,
        dateTo: LocalDate,
        visibility: String = "ALL",
        categoryId: UUID? = null,
        paymentMethodId: UUID? = null,
        pocketId: UUID? = null
    ): PeriodSummaryResponse {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(visibility)
        val hasFilters = categoryId != null || paymentMethodId != null || pocketId != null

        var totalIncome: Long
        var totalExpense: Long
        val byCategory: List<CategorySpending>

        if (hasFilters) {
            // Use Specifications-based query when filters are applied
            val incomeSpec = TransactionSpecifications.withFilters(
                coupleId = couple.id, startDate = dateFrom, endDate = dateTo,
                type = TransactionType.INCOME, categoryId = categoryId, keyword = null,
                paymentMethodId = paymentMethodId, pocketId = pocketId,
                amountMin = null, amountMax = null, userId = userId
            )
            val expenseSpec = TransactionSpecifications.withFilters(
                coupleId = couple.id, startDate = dateFrom, endDate = dateTo,
                type = TransactionType.EXPENSE, categoryId = categoryId, keyword = null,
                paymentMethodId = paymentMethodId, pocketId = pocketId,
                amountMin = null, amountMax = null, userId = userId
            )

            val incomeTransactions = transactionRepository.findAll(incomeSpec)
            val expenseTransactions = transactionRepository.findAll(expenseSpec)

            totalIncome = incomeTransactions.sumOf { it.amount }
            totalExpense = expenseTransactions.sumOf { it.amount }

            // byCategory from filtered expense transactions
            byCategory = expenseTransactions
                .filter { it.category != null }
                .groupBy { it.category!!.id }
                .map { (_, txns) ->
                    val first = txns.first()
                    val cat = first.category!!
                    val amount = txns.sumOf { it.amount }
                    CategorySpending(
                        categoryId = cat.id,
                        categoryName = cat.name,
                        groupId = cat.group?.id,
                        groupName = cat.group?.name,
                        icon = cat.icon,
                        color = cat.color,
                        amount = amount,
                        count = txns.size,
                        percentage = 0.0
                    )
                }
                .sortedByDescending { it.amount }
                .let { entries ->
                    val total = entries.sumOf { it.amount }
                    entries.map { entry ->
                        entry.copy(
                            percentage = if (total > 0) {
                                Math.round(entry.amount.toDouble() / total * 1000) / 10.0
                            } else 0.0
                        )
                    }
                }
        } else {
            // No filters: use optimized JPQL queries (existing behavior)
            val typeResults = transactionRepository.sumByTypeForCouple(couple.id, dateFrom, dateTo, userId, visFilter)
            totalIncome = 0L
            totalExpense = 0L
            for (row in typeResults) {
                val type = row[0] as TransactionType
                val sum = row[1] as Long
                when (type) {
                    TransactionType.INCOME -> totalIncome = sum
                    TransactionType.EXPENSE -> totalExpense = sum
                }
            }

            val categoryResults = transactionRepository.sumByCategoryForCouple(
                couple.id, dateFrom, dateTo, TransactionType.EXPENSE, userId, visFilter
            )
            byCategory = categoryResults.map { row ->
                val amount = row[0] as Long
                val count = (row[1] as Long).toInt()
                val catId = row[2] as UUID
                val catName = row[3] as String
                val catIcon = row[5] as? String
                val catColor = row[6] as? String
                val groupId = row[7] as? UUID
                val groupName = row[8] as? String
                CategorySpending(
                    categoryId = catId,
                    categoryName = catName,
                    groupId = groupId,
                    groupName = groupName,
                    icon = catIcon,
                    color = catColor,
                    amount = amount,
                    count = count,
                    percentage = 0.0
                )
            }.let { entries ->
                val total = entries.sumOf { it.amount }
                entries.map { entry ->
                    entry.copy(
                        percentage = if (total > 0) {
                            Math.round(entry.amount.toDouble() / total * 1000) / 10.0
                        } else 0.0
                    )
                }
            }
        }

        // Include transfer amounts (same as getMonthlySummary)
        // Transfers have no category/paymentMethod/pocket, so skip when those filters are active
        if (!hasFilters) {
            val transferOutResults = transferRepository.sumAmountBySourceExcludingSettlement(couple.id, dateFrom, dateTo)
            val transferOutTotal = transferOutResults.sumOf { it[1] as Long }
            val transferInResults = transferRepository.sumAmountByDestinationExcludingSettlement(couple.id, dateFrom, dateTo)
            val transferInTotal = transferInResults.sumOf { it[1] as Long }

            totalExpense += transferOutTotal
            totalIncome += transferInTotal
        }

        // 3. byBudget — find budgets covering this period
        val yearMonths = generateYearMonths(dateFrom, dateTo)
        val allBudgets = yearMonths.flatMap { ym ->
            budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, ym, userId)
        }.distinctBy { it.id }

        val budgetCategoryIds = allBudgets.mapNotNull { it.category?.id }.toSet()
        val budgetGroupIds = allBudgets.mapNotNull { it.group?.id }.toSet()

        val spendingByCategory = if (budgetCategoryIds.isNotEmpty()) {
            transactionRepository.sumAmountGroupedByCategoryId(
                couple.id, dateFrom, dateTo, TransactionType.EXPENSE, budgetCategoryIds, userId
            ).associate { (it[0] as UUID) to (it[1] as Long) }
        } else emptyMap()

        val spendingByGroup = if (budgetGroupIds.isNotEmpty()) {
            transactionRepository.sumByCategoryGroupForCouple(
                couple.id, dateFrom, dateTo, TransactionType.EXPENSE, budgetGroupIds, userId
            ).associate { (it[0] as UUID) to (it[1] as Long) }
        } else emptyMap()

        val totalSpent = transactionRepository.sumAmountByCoupleIdAndDateRange(
            couple.id, dateFrom, dateTo, TransactionType.EXPENSE, userId
        )

        val plannedByCategory = if (budgetCategoryIds.isNotEmpty()) {
            spendingPlanRepository.sumPlannedAmountByCategoryIds(couple.id, budgetCategoryIds, userId)
                .associate { (it[0] as UUID) to (it[1] as Long) }
        } else emptyMap()

        val plannedByGroup = if (budgetGroupIds.isNotEmpty()) {
            spendingPlanRepository.sumPlannedAmountByGroupIds(couple.id, budgetGroupIds, userId)
                .associate { (it[0] as UUID) to (it[1] as Long) }
        } else emptyMap()

        val totalPlanned = spendingPlanRepository.sumTotalPlannedAmount(couple.id, userId)

        val byBudget = allBudgets.map { budget ->
            val catId = budget.category?.id
            val grpId = budget.group?.id
            val budgetName = budget.category?.name ?: budget.group?.name ?: "전체"

            val spent = when {
                catId != null -> spendingByCategory[catId] ?: 0L
                grpId != null -> spendingByGroup[grpId] ?: 0L
                else -> totalSpent
            }
            val planned = when {
                catId != null -> plannedByCategory[catId] ?: 0L
                grpId != null -> plannedByGroup[grpId] ?: 0L
                else -> totalPlanned
            }

            val ym = YearMonth.parse(budget.yearMonth)
            val effectiveAmount = if (budget.budgetPeriod == BudgetPeriod.WEEKLY) {
                val weeklyAmt = budget.weeklyAmount ?: (budget.amount * 7 / ym.lengthOfMonth())
                weeklyAmt * ym.lengthOfMonth().toLong() / 7
            } else {
                budget.amount
            }

            val remaining = effectiveAmount - spent - planned
            val usageRate = if (effectiveAmount > 0) {
                Math.round((spent + planned).toDouble() / effectiveAmount * 1000.0) / 10.0
            } else 0.0

            BudgetSpending(
                budgetId = budget.id,
                budgetName = budgetName,
                budgetAmount = effectiveAmount,
                spent = spent,
                planned = planned,
                remaining = remaining,
                usageRate = usageRate
            )
        }

        // 4. byPaymentMethod
        val pmResults = transactionRepository.sumByPaymentMethodWithTypeForCouple(
            couple.id, dateFrom, dateTo, userId, visFilter
        )
        val byPaymentMethod = pmResults.map { row ->
            PaymentMethodSpending(
                methodId = row[0] as UUID,
                methodName = row[1] as String,
                methodType = (row[2] as Enum<*>).name,
                amount = row[3] as Long,
                count = (row[4] as Long).toInt()
            )
        }

        // 5. byDate (daily spending)
        val dailyResults = transactionRepository.dailySummaryForCouple(
            couple.id, dateFrom, dateTo, userId, visFilter
        )
        val dailyMap = mutableMapOf<LocalDate, Pair<Long, Long>>() // date -> (income, expense)
        for (row in dailyResults) {
            val date = (row[0] as java.sql.Date).toLocalDate()
            val typeName = row[1] as String
            val sum = (row[2] as Number).toLong()
            val current = dailyMap.getOrDefault(date, 0L to 0L)
            dailyMap[date] = when (typeName) {
                "INCOME" -> sum to current.second
                "EXPENSE" -> current.first to sum
                else -> current
            }
        }
        val byDate = dailyMap.entries.sortedBy { it.key }.map { (date, pair) ->
            DailySpending(
                date = date.toString(),
                income = pair.first,
                expense = pair.second
            )
        }

        return PeriodSummaryResponse(
            dateFrom = dateFrom.toString(),
            dateTo = dateTo.toString(),
            totalIncome = totalIncome,
            totalExpense = totalExpense,
            balance = totalIncome - totalExpense,
            byCategory = byCategory,
            byBudget = byBudget,
            byPaymentMethod = byPaymentMethod,
            byDate = byDate
        )
    }

    private fun generateYearMonths(from: LocalDate, to: LocalDate): List<String> {
        val result = mutableListOf<String>()
        var ym = YearMonth.from(from)
        val end = YearMonth.from(to)
        while (!ym.isAfter(end)) {
            result.add(ym.toString())
            ym = ym.plusMonths(1)
        }
        return result
    }

}
