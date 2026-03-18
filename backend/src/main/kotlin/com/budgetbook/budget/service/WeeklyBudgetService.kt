package com.budgetbook.budget.service

import com.budgetbook.budget.domain.WeeklyBudgetSnapshot
import com.budgetbook.budget.domain.WeeklyStatus
import com.budgetbook.budget.dto.CurrentWeekSummaryResponse
import com.budgetbook.budget.dto.WeeklyGroupSummary
import com.budgetbook.budget.dto.WeeklyOverviewResponse
import com.budgetbook.budget.dto.WeeklySnapshotResponse
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.budget.repository.WeeklyBudgetSnapshotRepository
import com.budgetbook.category.domain.BudgetType
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
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

        val snapshots = snapshotRepository.findByCoupleIdAndYearMonth(couple.id, yearMonth)

        val weekRanges = calculateWeekRanges(ym)

        // Hoist budget query outside the loop (Problem 2)
        val budgetAmount = calculateWeeklyBudgetAmount(couple.id, yearMonth, weekRanges.size)

        // Early return if no budget and no snapshots (Problem 3)
        if (budgetAmount == 0L && snapshots.isEmpty()) {
            val weeks = weekRanges.mapIndexed { index, (weekStart, weekEnd) ->
                WeeklySnapshotResponse(
                    weekNumber = index + 1,
                    weekStart = weekStart.toString(),
                    weekEnd = weekEnd.toString(),
                    budgetAmount = 0,
                    spentAmount = 0,
                    remainingAmount = 0,
                    usageRate = 0.0,
                    status = if (weekEnd.isBefore(LocalDate.now())) "UNDER" else "IN_PROGRESS"
                )
            }
            return WeeklyOverviewResponse(yearMonth = yearMonth, weeks = weeks)
        }

        val weeks = weekRanges.mapIndexed { index, (weekStart, weekEnd) ->
            val weekNumber = index + 1
            val snapshot = snapshots.find { it.weekNumber == weekNumber }

            if (snapshot != null) {
                toSnapshotResponse(snapshot)
            } else {
                // Calculate in real-time using optimized SUM query
                val spent = calculateSpentForPeriod(couple.id, weekStart, weekEnd)
                val remaining = budgetAmount - spent
                val usageRate = if (budgetAmount > 0) {
                    Math.round(spent.toDouble() / budgetAmount * 1000.0) / 10.0
                } else 0.0
                val today = LocalDate.now()
                val status = when {
                    weekEnd.isBefore(today) && spent <= budgetAmount -> "UNDER"
                    weekEnd.isBefore(today) && spent > budgetAmount -> "OVER"
                    else -> "IN_PROGRESS"
                }

                WeeklySnapshotResponse(
                    weekNumber = weekNumber,
                    weekStart = weekStart.toString(),
                    weekEnd = weekEnd.toString(),
                    budgetAmount = budgetAmount,
                    spentAmount = spent,
                    remainingAmount = remaining,
                    usageRate = usageRate,
                    status = status
                )
            }
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

        // Batch-fetch all data upfront (eliminates N+1 queries)
        val allGroups = categoryGroupRepository.findByCoupleId(couple.id)
        val weeklyGroups = allGroups.filter { it.budgetType == BudgetType.WEEKLY }

        // Early return if no WEEKLY groups (Problem 3)
        if (weeklyGroups.isEmpty()) {
            return CurrentWeekSummaryResponse(
                yearMonth = yearMonth,
                weekNumber = weekNumber,
                weekStart = weekStart.toString(),
                weekEnd = weekEnd.toString(),
                groups = emptyList()
            )
        }

        val allCategories = categoryRepository.findByCoupleId(couple.id)
        val categoriesByGroupId = allCategories.groupBy { it.group?.id }

        val allBudgets = budgetRepository.findByCoupleIdAndYearMonth(couple.id, yearMonth)
        val budgetByCategoryId = allBudgets.associateBy { it.category?.id }

        // Collect ALL categoryIds across all weekly groups for batch query (Problem 1)
        val allCategoryIds = weeklyGroups.flatMap { group ->
            (categoriesByGroupId[group.id] ?: emptyList()).map { it.id }
        }.toSet()

        // Single batch query for all category spending
        val spentByCategoryId: Map<UUID, Long> = if (allCategoryIds.isNotEmpty()) {
            transactionRepository.sumAmountGroupedByCategoryId(
                coupleId = couple.id,
                startDate = weekStart,
                endDate = weekEnd,
                type = TransactionType.EXPENSE,
                categoryIds = allCategoryIds
            ).associate { row ->
                val categoryId = row[0] as UUID
                val amount = (row[1] as Number).toLong()
                categoryId to amount
            }
        } else {
            emptyMap()
        }

        val groups = weeklyGroups.map { group ->
            val categoriesInGroup = categoriesByGroupId[group.id] ?: emptyList()
            val categoryIds = categoriesInGroup.map { it.id }.toSet()

            val groupBudgetAmount = categoryIds.sumOf { catId ->
                val budget = budgetByCategoryId[catId]
                budget?.weeklyAmount ?: (budget?.amount?.div(weekRanges.size) ?: 0L)
            }

            // In-memory lookup from batch query result (no additional DB call)
            val spent = categoryIds.sumOf { catId -> spentByCategoryId[catId] ?: 0L }

            val remaining = groupBudgetAmount - spent
            val usageRate = if (groupBudgetAmount > 0) {
                Math.round(spent.toDouble() / groupBudgetAmount * 1000.0) / 10.0
            } else 0.0

            WeeklyGroupSummary(
                groupId = group.id,
                groupName = group.name,
                budgetAmount = groupBudgetAmount,
                spentAmount = spent,
                remainingAmount = remaining,
                usageRate = usageRate
            )
        }

        return CurrentWeekSummaryResponse(
            yearMonth = yearMonth,
            weekNumber = weekNumber,
            weekStart = weekStart.toString(),
            weekEnd = weekEnd.toString(),
            groups = groups
        )
    }

    @Transactional
    fun refreshWeeklySnapshots(userId: UUID, year: Int, month: Int) {
        val couple = getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        val ym = YearMonth.of(year, month)
        val weekRanges = calculateWeekRanges(ym)
        val today = LocalDate.now()

        // Hoist budget query outside the loop (Problem 2)
        val budgetAmount = calculateWeeklyBudgetAmount(couple.id, yearMonth, weekRanges.size)

        weekRanges.forEachIndexed { index, (weekStart, weekEnd) ->
            val weekNumber = index + 1
            val spent = calculateSpentForPeriod(couple.id, weekStart, weekEnd)

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

    private fun toSnapshotResponse(snapshot: WeeklyBudgetSnapshot): WeeklySnapshotResponse {
        val remaining = snapshot.budgetAmount - snapshot.spentAmount
        val usageRate = if (snapshot.budgetAmount > 0) {
            Math.round(snapshot.spentAmount.toDouble() / snapshot.budgetAmount * 1000.0) / 10.0
        } else 0.0
        return WeeklySnapshotResponse(
            weekNumber = snapshot.weekNumber,
            weekStart = snapshot.weekStart.toString(),
            weekEnd = snapshot.weekEnd.toString(),
            budgetAmount = snapshot.budgetAmount,
            spentAmount = snapshot.spentAmount,
            remainingAmount = remaining,
            usageRate = usageRate,
            status = snapshot.status.name
        )
    }

    private fun calculateSpentForPeriod(coupleId: UUID, start: LocalDate, end: LocalDate): Long {
        return transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = coupleId,
            startDate = start,
            endDate = end,
            type = TransactionType.EXPENSE
        )
    }

    private fun calculateWeeklyBudgetAmount(coupleId: UUID, yearMonth: String, numberOfWeeks: Int): Long {
        val budgets = budgetRepository.findByCoupleIdAndYearMonth(coupleId, yearMonth)
        val totalMonthlyBudget = budgets.sumOf { it.amount }
        return if (numberOfWeeks > 0) totalMonthlyBudget / numberOfWeeks else 0L
    }

    private fun formatYearMonth(year: Int, month: Int): String =
        "%04d-%02d".format(year, month)

    companion object {
        fun calculateWeekRanges(yearMonth: YearMonth): List<Pair<LocalDate, LocalDate>> {
            val lastDay = yearMonth.atEndOfMonth()
            val ranges = mutableListOf<Pair<LocalDate, LocalDate>>()

            // Week 1: 1st~7th, Week 2: 8th~14th, Week 3: 15th~21st, Week 4: 22nd~28th, Week 5: 29th~end
            val weekStarts = listOf(1, 8, 15, 22, 29)
            for (start in weekStarts) {
                if (start > lastDay.dayOfMonth) break
                val weekStart = yearMonth.atDay(start)
                val weekEnd = if (start + 6 <= lastDay.dayOfMonth) {
                    yearMonth.atDay(start + 6)
                } else {
                    lastDay
                }
                ranges.add(weekStart to weekEnd)
            }

            return ranges
        }
    }
}
