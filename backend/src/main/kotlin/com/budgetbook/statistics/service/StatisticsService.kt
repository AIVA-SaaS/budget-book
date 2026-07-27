package com.budgetbook.statistics.service

import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
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
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class StatisticsService(
    private val transactionRepository: TransactionRepository,
    private val transferRepository: com.budgetbook.transfer.repository.TransferRepository,
    override val coupleResolver: CoupleResolver,
    private val budgetRepository: MonthlyBudgetRepository,
    private val spendingPlanRepository: SpendingPlanRepository,
    private val categoryRepository: CategoryRepository,
    private val expenseCalculator: ExpenseCalculator,
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
    fun getMonthlySummary(
        userId: UUID,
        year: Int,
        month: Int,
        visibility: String = "ALL",
        dateFrom: LocalDate? = null,
        dateTo: LocalDate? = null,
        // 회차 8 — 모든 필터 지원 (period-summary 패턴 차용). client-side fold 부정확 회귀 fix.
        categoryId: UUID? = null,
        paymentMethodId: UUID? = null,
        pocketId: UUID? = null,
        categoryIds: List<UUID> = emptyList(),
        categoryGroupIds: List<UUID> = emptyList(),
        paymentMethodIds: List<UUID> = emptyList(),
        pocketIds: List<UUID> = emptyList(),
        amountMin: Long? = null,
        amountMax: Long? = null,
        keyword: String? = null,
        transactionTypes: List<String> = emptyList(),
        // 2026-07-27 — 거래 목록에만 적용되고 summary 에는 누락돼 있던 필터.
        // 목록은 needs_review 만 보여주는데 합계는 전체였다 → "합계 ≠ 보이는 행".
        needsReviewOnly: Boolean? = null
    ): StatisticsSummaryResponse {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(visibility)
        val yearMonth = YearMonth.of(year, month)
        val startDate = dateFrom ?: yearMonth.atDay(1)
        val endDate = dateTo ?: yearMonth.atEndOfMonth()

        // PR-C2 + 회차 8: 단수+복수 병합, 그룹 펼치기
        val effectiveCategoryIds = categoryIds.toMutableSet().also { set ->
            categoryId?.let { set.add(it) }
            if (categoryGroupIds.isNotEmpty()) {
                set.addAll(categoryRepository.findByGroupIdIn(categoryGroupIds).map { it.id })
            }
        }
        val effectivePaymentMethodIds = paymentMethodIds.toMutableSet().also { set ->
            paymentMethodId?.let { set.add(it) }
        }
        val effectivePocketIds = pocketIds.toMutableSet().also { set ->
            pocketId?.let { set.add(it) }
        }
        val effectiveTypes = transactionTypes.mapNotNull {
            try { TransactionType.valueOf(it) } catch (_: IllegalArgumentException) { null }
        }.toSet()

        val hasContentFilters = effectiveCategoryIds.isNotEmpty() ||
            effectivePaymentMethodIds.isNotEmpty() ||
            effectivePocketIds.isNotEmpty() ||
            amountMin != null ||
            amountMax != null ||
            !keyword.isNullOrBlank() ||
            effectiveTypes.isNotEmpty() ||
            needsReviewOnly == true

        val totalIncome: Long
        val totalExpense: Long
        val totalTransfer: Long
        val transactionCount: Int

        if (hasContentFilters) {
            // 회차 8 — 모든 필터 지원: Specifications-based query 로 정확한 합계 계산.
            val incomeSpec = TransactionSpecifications.withFilters(
                coupleId = couple.id, startDate = startDate, endDate = endDate,
                type = TransactionType.INCOME, categoryId = null, keyword = keyword,
                paymentMethodId = null, pocketId = null,
                amountMin = amountMin, amountMax = amountMax, userId = userId,
                visibility = visFilter,
                categoryIds = effectiveCategoryIds,
                paymentMethodIds = effectivePaymentMethodIds,
                pocketIds = effectivePocketIds,
                needsReviewOnly = needsReviewOnly
            )
            val expenseSpec = TransactionSpecifications.withFilters(
                coupleId = couple.id, startDate = startDate, endDate = endDate,
                type = TransactionType.EXPENSE, categoryId = null, keyword = keyword,
                paymentMethodId = null, pocketId = null,
                amountMin = amountMin, amountMax = amountMax, userId = userId,
                visibility = visFilter,
                categoryIds = effectiveCategoryIds,
                paymentMethodIds = effectivePaymentMethodIds,
                pocketIds = effectivePocketIds,
                needsReviewOnly = needsReviewOnly
            )

            val incomeTransactions = transactionRepository.findAll(incomeSpec)
            val expenseTransactions = transactionRepository.findAll(expenseSpec)

            // transactionTypes 필터 — INCOME/EXPENSE 만 받음 (TRANSFER 는 별도, ADJUSTMENT 통계 제외)
            val includeIncome = effectiveTypes.isEmpty() || effectiveTypes.contains(TransactionType.INCOME)
            val includeExpense = effectiveTypes.isEmpty() || effectiveTypes.contains(TransactionType.EXPENSE)

            totalIncome = if (includeIncome) incomeTransactions.sumOf { it.amount } else 0L
            totalExpense = if (includeExpense) expenseTransactions.sumOf { it.amount } else 0L
            // Transfer 는 카테고리/결제수단/포켓 없으므로 필터 활성 시 제외
            totalTransfer = 0L
            transactionCount = (if (includeIncome) incomeTransactions.size else 0) +
                (if (includeExpense) expenseTransactions.size else 0)
        } else {
            // No content filters: ExpenseCalculator 일원화 (Phase 22 S1).
            val results = transactionRepository.sumByTypeForCouple(couple.id, startDate, endDate, userId, visFilter)
            var count = 0
            for (row in results) {
                val type = row[0] as TransactionType
                val rowCount = (row[2] as Long).toInt()
                if (type == TransactionType.INCOME || type == TransactionType.EXPENSE) {
                    count += rowCount
                }
            }
            transactionCount = count
            totalIncome = expenseCalculator.totalIncome(couple.id, startDate, endDate, userId, visFilter)
            totalExpense = expenseCalculator.totalExpense(couple.id, startDate, endDate, userId, visFilter)
            totalTransfer = expenseCalculator.totalTransfer(couple.id, startDate, endDate)
        }

        return StatisticsSummaryResponse(
            yearMonth = yearMonth.toString(),
            totalIncome = totalIncome,
            totalExpense = totalExpense,
            totalTransfer = totalTransfer,
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
        // Phase 22: ADJUSTMENT 는 카테고리 통계 범주 밖.
        if (transactionType == TransactionType.ADJUSTMENT) {
            throw BusinessException("VALIDATION_ERROR", "ADJUSTMENT 는 카테고리 통계에 집계되지 않습니다.")
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

        // Phase 22: "이체" 가상 카테고리는 EXPENSE_TRANSFER / INCOME_TRANSFER 만 반영.
        // GENERIC 은 수입/지출 범주 밖이므로 카테고리 브레이크다운에 포함하지 않는다.
        if (transactionType == TransactionType.EXPENSE) {
            val transferExpense = transferRepository
                .sumAmountBySourceByKind(couple.id, startDate, endDate, com.budgetbook.transfer.domain.TransferKinds.EXPENSE_AFFECTING)
                .sumOf { it[1] as Long }
            if (transferExpense > 0) {
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
                    amount = transferExpense,
                    percentage = 0.0,
                    transactionCount = 0
                ))
            }
        } else {
            val transferIncome = transferRepository
                .sumAmountByDestinationByKind(couple.id, startDate, endDate, com.budgetbook.transfer.domain.TransferKinds.INCOME_AFFECTING)
                .sumOf { it[1] as Long }
            if (transferIncome > 0) {
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
                    amount = transferIncome,
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
                else -> current // ADJUSTMENT 기타: 트렌드 제외
            }
        }

        return (0 until validMonths).map { offset ->
            val ym = startMonth.plusMonths(offset.toLong())
            val ymStr = ym.toString()
            val (txIncome, txExpense) = trendMap.getOrDefault(ymStr, 0L to 0L)

            // Phase 22 S1: Transfer 는 kind 기반으로 합산. Transaction 은 bulk trendMap 재사용.
            val monthStart = ym.atDay(1)
            val monthEnd = ym.atEndOfMonth()
            val transferExpense = transferRepository
                .sumAmountBySourceByKind(couple.id, monthStart, monthEnd, com.budgetbook.transfer.domain.TransferKinds.EXPENSE_AFFECTING)
                .sumOf { it[1] as Long }
            val transferIncome = transferRepository
                .sumAmountByDestinationByKind(couple.id, monthStart, monthEnd, com.budgetbook.transfer.domain.TransferKinds.INCOME_AFFECTING)
                .sumOf { it[1] as Long }
            val totalTransfer = transferRepository
                .sumAmountBySourceByKind(couple.id, monthStart, monthEnd, com.budgetbook.transfer.domain.TransferKinds.TRANSFER_ONLY)
                .sumOf { it[1] as Long }

            val totalIncome = txIncome + transferIncome
            val totalExpense = txExpense + transferExpense

            MonthlyTrendResponse(
                yearMonth = ymStr,
                totalIncome = totalIncome,
                totalExpense = totalExpense,
                totalTransfer = totalTransfer,
                balance = totalIncome - totalExpense
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
        pocketId: UUID? = null,
        // PR-C2 다중/그룹 필터. 단수 필드와 합쳐 Set 으로 전달됨.
        categoryIds: List<UUID> = emptyList(),
        categoryGroupIds: List<UUID> = emptyList(),
        paymentMethodIds: List<UUID> = emptyList(),
        pocketIds: List<UUID> = emptyList()
    ): PeriodSummaryResponse {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(visibility)

        // PR-C2: 단수 + 복수 병합, 그룹 펼치기
        val effectiveCategoryIds = categoryIds.toMutableSet().also { set ->
            categoryId?.let { set.add(it) }
            if (categoryGroupIds.isNotEmpty()) {
                set.addAll(categoryRepository.findByGroupIdIn(categoryGroupIds).map { it.id })
            }
        }
        val effectivePaymentMethodIds = paymentMethodIds.toMutableSet().also { set ->
            paymentMethodId?.let { set.add(it) }
        }
        val effectivePocketIds = pocketIds.toMutableSet().also { set ->
            pocketId?.let { set.add(it) }
        }
        val hasFilters = effectiveCategoryIds.isNotEmpty() ||
            effectivePaymentMethodIds.isNotEmpty() ||
            effectivePocketIds.isNotEmpty()

        var totalIncome: Long
        var totalExpense: Long
        var totalTransfer = 0L
        val byCategory: List<CategorySpending>

        if (hasFilters) {
            // Use Specifications-based query when filters are applied
            val incomeSpec = TransactionSpecifications.withFilters(
                coupleId = couple.id, startDate = dateFrom, endDate = dateTo,
                type = TransactionType.INCOME, categoryId = null, keyword = null,
                paymentMethodId = null, pocketId = null,
                amountMin = null, amountMax = null, userId = userId,
                categoryIds = effectiveCategoryIds,
                paymentMethodIds = effectivePaymentMethodIds,
                pocketIds = effectivePocketIds
            )
            val expenseSpec = TransactionSpecifications.withFilters(
                coupleId = couple.id, startDate = dateFrom, endDate = dateTo,
                type = TransactionType.EXPENSE, categoryId = null, keyword = null,
                paymentMethodId = null, pocketId = null,
                amountMin = null, amountMax = null, userId = userId,
                categoryIds = effectiveCategoryIds,
                paymentMethodIds = effectivePaymentMethodIds,
                pocketIds = effectivePocketIds
            )

            val incomeTransactions = transactionRepository.findAll(incomeSpec)
            val expenseTransactions = transactionRepository.findAll(expenseSpec)

            totalIncome = incomeTransactions.sumOf { it.amount }
            totalExpense = expenseTransactions.sumOf { it.amount }
            // Transfer 는 카테고리/결제수단/포켓 필드가 없으므로 필터 활성 시 집계에서 제외됨.
            // totalTransfer 도 0 유지.

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
            // No filters: ExpenseCalculator 로 일원화 (Phase 22 S1).
            totalIncome = expenseCalculator.totalIncome(couple.id, dateFrom, dateTo, userId, visFilter)
            totalExpense = expenseCalculator.totalExpense(couple.id, dateFrom, dateTo, userId, visFilter)
            totalTransfer = expenseCalculator.totalTransfer(couple.id, dateFrom, dateTo)

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

        // 3. byBudget — find budgets covering this period
        val yearMonths = generateYearMonths(dateFrom, dateTo)
        val allBudgets = yearMonths.flatMap { ym ->
            com.budgetbook.budget.service.MonthlyBudgetResolver.resolveForMonth(
                budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, ym, userId)
            )
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

        // 회차 12 P4 — month 필터 적용 (period-summary 의 dateFrom/To 기준).
        val plannedByCategory = if (budgetCategoryIds.isNotEmpty()) {
            spendingPlanRepository.sumPlannedAmountByCategoryIds(couple.id, budgetCategoryIds, userId, dateFrom, dateTo)
                .associate { (it[0] as UUID) to (it[1] as Long) }
        } else emptyMap()

        val plannedByGroup = if (budgetGroupIds.isNotEmpty()) {
            spendingPlanRepository.sumPlannedAmountByGroupIds(couple.id, budgetGroupIds, userId, dateFrom, dateTo)
                .associate { (it[0] as UUID) to (it[1] as Long) }
        } else emptyMap()

        val totalPlanned = spendingPlanRepository.sumTotalPlannedAmount(couple.id, userId, dateFrom, dateTo)

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
                else -> current // ADJUSTMENT 제외
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
            totalTransfer = totalTransfer,
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
