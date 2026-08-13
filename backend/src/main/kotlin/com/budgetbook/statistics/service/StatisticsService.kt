package com.budgetbook.statistics.service

import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.filter.LedgerTypeSelection
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
import com.budgetbook.transaction.domain.Transaction
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
    /**
     * 장부 합계바가 쓰는 월/기간 합계.
     *
     * ## 2026-08-12 — `hasContentFilters` 분기를 **제거**했다
     *
     * 이전에는 두 갈래였다:
     *  - 필터 없음 → `ExpenseCalculator` (이체 **포함**)
     *  - 필터 있음 → 거래만 집계 + `totalTransfer = 0` (이체 **제외**)
     *
     * 같은 화면의 합계가 필터 유무에 따라 다른 규칙을 쓴 것이 "합계 ≠ 행" 의 원인이었다.
     * 이제 경로가 하나다 — 거래는 spec, 이체는 [ExpenseCalculator.transferBuckets]
     * (= 이체 목록 조회와 **동일한** `TransferGating` 판정).
     * 분기가 없으므로 한쪽만 규칙을 어기는 재발이 구조적으로 불가능하다.
     *
     * 필터는 VO 하나로 받는다 — 필드 수동 나열은 누락 4회 재발의 원인이었다.
     */
    fun getMonthlySummary(
        userId: UUID,
        year: Int,
        month: Int,
        filter: CommonFilterParams = CommonFilterParams()
    ): StatisticsSummaryResponse {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(filter.visibility ?: "ALL")
        val yearMonth = YearMonth.of(year, month)
        // dateFrom/dateTo 가 있으면 월을 덮어쓴다 — 거래 목록·이체 목록과 같은 범위 규칙.
        val startDate = filter.dateFrom ?: yearMonth.atDay(1)
        val endDate = filter.dateTo ?: yearMonth.atEndOfMonth()

        val scope = resolveTransactionScope(couple.id, userId, visFilter, filter, startDate, endDate)
        val buckets = expenseCalculator.transferBuckets(couple.id, startDate, endDate, filter)

        val totalIncome = scope.incomeTotal + buckets.income
        val totalExpense = scope.expenseTotal + buckets.expense

        return StatisticsSummaryResponse(
            yearMonth = yearMonth.toString(),
            totalIncome = totalIncome,
            totalExpense = totalExpense,
            totalTransfer = buckets.generic,
            balance = totalIncome - totalExpense,
            transactionCount = scope.transactionCount,
            transferCount = buckets.count
        )
    }

    /**
     * 거래 쪽 집계 — 타입 선택([LedgerTypeSelection])을 반영한 spec 조회.
     *
     * `ADJUSTMENT` 는 통계 범주 밖이므로 INCOME/EXPENSE 만 조회한다(잔액 전용).
     * 타입 필터가 켜졌는데 거래 타입이 하나도 없으면("이체만 보기") 거래는 0건이 정답이다.
     */
    private fun resolveTransactionScope(
        coupleId: UUID,
        userId: UUID,
        visFilter: String?,
        filter: CommonFilterParams,
        startDate: LocalDate,
        endDate: LocalDate,
    ): TransactionScope {
        val effectiveCategoryIds = filter.categoryIds.toMutableSet().also { set ->
            filter.categoryId?.let { set.add(it) }
            if (filter.categoryGroupIds.isNotEmpty()) {
                set.addAll(categoryRepository.findByGroupIdIn(filter.categoryGroupIds).map { it.id })
            }
        }
        val effectivePaymentMethodIds = filter.paymentMethodIds.toMutableSet().also { set ->
            filter.paymentMethodId?.let { set.add(it) }
        }
        val effectivePocketIds = filter.pocketIds.toMutableSet().also { set ->
            filter.pocketId?.let { set.add(it) }
        }

        val selection = LedgerTypeSelection.parse(filter.transactionTypes)
        // 단수 `type` 은 `transactionTypes` 가 비어 있을 때만 의미가 있다(FE toQueryParams 우선순위와 일치).
        val singularType = if (!selection.hasSelection) {
            filter.type?.let {
                try { TransactionType.valueOf(it) } catch (_: IllegalArgumentException) {
                    throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: ${filter.type}")
                }
            }
        } else null

        val selectedTypes: Set<TransactionType> = when {
            selection.hasSelection -> selection.transactionTypes
            singularType != null -> setOf(singularType)
            else -> emptySet()
        }
        // ADJUSTMENT 는 통계 범주 밖이다(잔액 전용) → 집계 대상은 INCOME/EXPENSE 뿐.
        val statisticalTypes = setOf(TransactionType.INCOME, TransactionType.EXPENSE)
        // 주의: "타입 필터 없음"(전체)과 "타입 필터가 거래를 하나도 고르지 않음"(이체만 보기)은
        // 다르다. 후자를 전체로 착각하면 이체만 보기에서 거래 합계가 그대로 남는다.
        val hasTypeFilter = selection.hasSelection || singularType != null
        val queryTypes =
            if (!hasTypeFilter) statisticalTypes else selectedTypes intersect statisticalTypes

        // "이체만 보기" — 집계 대상 거래 타입이 하나도 없으면 조회 자체를 생략한다.
        if (queryTypes.isEmpty()) return TransactionScope(0L, 0L, 0)

        // 한 번의 조회로 가져와 타입별로 접는다 (타입마다 쿼리하면 왕복이 2배).
        val transactions = transactionRepository.findAll(
            TransactionSpecifications.withFilters(
                coupleId = coupleId, startDate = startDate, endDate = endDate,
                type = null, categoryId = null, keyword = filter.keyword,
                paymentMethodId = null, pocketId = null,
                amountMin = filter.amountMin, amountMax = filter.amountMax, userId = userId,
                visibility = visFilter,
                categoryIds = effectiveCategoryIds,
                paymentMethodIds = effectivePaymentMethodIds,
                pocketIds = effectivePocketIds,
                types = queryTypes,
                needsReviewOnly = filter.needsReviewOnly
            )
        )

        return TransactionScope(
            incomeTotal = transactions.filter { it.type == TransactionType.INCOME }.sumOf { it.amount },
            expenseTotal = transactions.filter { it.type == TransactionType.EXPENSE }.sumOf { it.amount },
            transactionCount = transactions.size,
            transactions = transactions,
        )
    }

    /**
     * 거래 집계 결과. [transactions] 를 함께 들고 있어 카테고리 분해 같은 파생 계산이
     * **같은 행 집합**을 쓰도록 한다(다시 조회하면 두 값이 어긋날 수 있다).
     */
    private data class TransactionScope(
        val incomeTotal: Long,
        val expenseTotal: Long,
        val transactionCount: Int,
        val transactions: List<Transaction> = emptyList(),
    )

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
        filter: CommonFilterParams = CommonFilterParams()
    ): PeriodSummaryResponse {
        val couple = getActiveCouple(userId)
        val visFilter = validateVisibility(filter.visibility ?: "ALL")

        // PR-C2: 단수 + 복수 병합, 그룹 펼치기
        val effectiveCategoryIds = filter.categoryIds.toMutableSet().also { set ->
            filter.categoryId?.let { set.add(it) }
            if (filter.categoryGroupIds.isNotEmpty()) {
                set.addAll(categoryRepository.findByGroupIdIn(filter.categoryGroupIds).map { it.id })
            }
        }
        val effectivePaymentMethodIds = filter.paymentMethodIds.toMutableSet().also { set ->
            filter.paymentMethodId?.let { set.add(it) }
        }
        val effectivePocketIds = filter.pocketIds.toMutableSet().also { set ->
            filter.pocketId?.let { set.add(it) }
        }
        val hasFilters = effectiveCategoryIds.isNotEmpty() ||
            effectivePaymentMethodIds.isNotEmpty() ||
            effectivePocketIds.isNotEmpty()

        // 2026-08-12 — 이체는 필터 유무와 무관하게 **같은 판정**으로 집계한다.
        // (이전: 필터가 켜지면 totalTransfer = 0 → 합계가 목록과 다른 집합을 셌다)
        val transferBuckets = expenseCalculator.transferBuckets(couple.id, dateFrom, dateTo, filter)

        // 거래 집계는 getMonthlySummary 와 **같은 헬퍼**를 쓴다 — 두 엔드포인트가 다른 기전을
        // 쓰면 같은 기간의 수치가 갈라진다(회귀 가드: "consistency between ..." 테스트).
        val scope = resolveTransactionScope(couple.id, userId, visFilter, filter, dateFrom, dateTo)
        var totalIncome: Long = scope.incomeTotal
        var totalExpense: Long = scope.expenseTotal
        val byCategory: List<CategorySpending>

        if (hasFilters) {
            // byCategory 는 **합계와 같은 행 집합**에서 파생한다(다시 조회하면 어긋날 수 있다).
            byCategory = scope.transactions
                .filter { it.type == TransactionType.EXPENSE }
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
            // 합계는 위 scope 가 이미 계산했다. 여기서는 카테고리 분해만 집계 쿼리로 얻는다
            // (총액을 다시 계산하면 두 값이 갈라진다 — 그것이 이번 회차의 근본 원인이었다).
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

        // 이체 버킷을 거래 합계에 더한다 — 두 분기 공통(규칙이 갈라지지 않게 여기 한 곳에서).
        totalIncome += transferBuckets.income
        totalExpense += transferBuckets.expense

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
            totalTransfer = transferBuckets.generic,
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
