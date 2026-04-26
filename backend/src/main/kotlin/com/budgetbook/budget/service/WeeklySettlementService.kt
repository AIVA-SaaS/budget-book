package com.budgetbook.budget.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.budget.domain.SettlementStatus
import com.budgetbook.budget.domain.WeeklyBudgetSettlement
import com.budgetbook.budget.dto.SettleWeekRequest
import com.budgetbook.budget.dto.SettlementItemResponse
import com.budgetbook.budget.dto.UnsettleWeekRequest
import com.budgetbook.budget.dto.WeekSettlementResponse
import com.budgetbook.budget.dto.WeeklySettlementOverviewResponse
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.budget.repository.WeeklyBudgetSettlementRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant
import java.time.YearMonth
import java.util.UUID

@Service
class WeeklySettlementService(
    override val coupleResolver: CoupleResolver,
    private val settlementRepository: WeeklyBudgetSettlementRepository,
    private val budgetRepository: MonthlyBudgetRepository,
    private val transactionRepository: TransactionRepository,
    private val categoryRepository: CategoryRepository,
    private val userRepository: UserRepository,
    private val syncEventPublisher: SyncEventPublisher
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun getSettlementOverview(userId: UUID, year: Int, month: Int): WeeklySettlementOverviewResponse {
        val couple = getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        val ym = YearMonth.of(year, month)
        val weekRanges = WeeklyBudgetService.calculateWeekRanges(ym)

        // Load all weekly budgets for this couple/month
        val budgets = MonthlyBudgetResolver.resolveForMonth(
            budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, userId)
        ).filter { it.budgetPeriod == com.budgetbook.budget.domain.BudgetPeriod.WEEKLY }

        // Load existing settlements
        val existingSettlements = settlementRepository.findByCoupleIdAndYearMonth(couple.id, yearMonth)
        val settlementMap = existingSettlements.associateBy {
            Triple(it.budget.id, it.weekNumber, it.category?.id)
        }

        // Load category names for display
        val allCategoryIds = budgets.mapNotNull { it.category?.id }.toSet()
        val categoryNames: Map<UUID, String> = if (allCategoryIds.isNotEmpty()) {
            categoryRepository.findAllById(allCategoryIds).associate { it.id to it.name }
        } else {
            emptyMap()
        }

        // Collect category IDs for spending queries
        val budgetGroupIds = budgets.mapNotNull { it.group?.id }.toSet()
        val categoriesInGroups: Map<UUID, Set<UUID>> = if (budgetGroupIds.isNotEmpty()) {
            val allCategories = categoryRepository.findByCoupleId(couple.id)
            budgetGroupIds.associateWith { groupId ->
                allCategories.filter { it.group?.id == groupId }.map { it.id }.toSet()
            }
        } else {
            emptyMap()
        }

        val weeks = weekRanges.mapIndexed { index, (weekStart, weekEnd) ->
            val weekNumber = index + 1

            // Calculate spending per category for this week
            val allRelevantCategoryIds = allCategoryIds + categoriesInGroups.values.flatten().toSet()
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

            // For uncategorized budgets, total spending
            val hasUncategorizedBudget = budgets.any { it.category == null && it.group == null }
            val totalSpentForWeek: Long = if (hasUncategorizedBudget) {
                transactionRepository.sumAmountByCoupleIdAndDateRange(
                    coupleId = couple.id,
                    startDate = weekStart,
                    endDate = weekEnd,
                    type = TransactionType.EXPENSE,
                    userId = userId
                )
            } else 0L

            val items = budgets.map { budget ->
                val spentAmount: Long = when {
                    budget.category != null -> spentByCategoryId[budget.category!!.id] ?: 0L
                    budget.group != null -> {
                        val catIds = categoriesInGroups[budget.group!!.id] ?: emptySet()
                        catIds.sumOf { catId -> spentByCategoryId[catId] ?: 0L }
                    }
                    else -> totalSpentForWeek
                }

                val key = Triple(budget.id, weekNumber, budget.category?.id)
                val settlement = settlementMap[key]

                SettlementItemResponse(
                    settlementId = settlement?.id,
                    budgetId = budget.id,
                    categoryId = budget.category?.id,
                    categoryName = budget.category?.let { categoryNames[it.id] },
                    amount = spentAmount,
                    status = (settlement?.status ?: SettlementStatus.PENDING).name,
                    settledAt = settlement?.settledAt
                )
            }

            WeekSettlementResponse(
                weekNumber = weekNumber,
                weekStart = weekStart.toString(),
                weekEnd = weekEnd.toString(),
                items = items,
                allSettled = items.isNotEmpty() && items.all { it.status == SettlementStatus.SETTLED.name }
            )
        }

        return WeeklySettlementOverviewResponse(yearMonth = yearMonth, weeks = weeks)
    }

    @Transactional
    fun settleWeek(userId: UUID, request: SettleWeekRequest) {
        val couple = getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found") }

        val budget = budgetRepository.findById(request.budgetId)
            .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Budget not found") }

        require(budget.couple.id == couple.id) { "Budget does not belong to this couple" }

        val ym = parseYearMonth(request.yearMonth)
        val weekRanges = WeeklyBudgetService.calculateWeekRanges(ym)
        require(request.weekNumber in 1..weekRanges.size) { "Invalid week number" }

        val (weekStart, weekEnd) = weekRanges[request.weekNumber - 1]

        // Determine which category IDs to settle
        val categoriesToSettle = resolveCategoriesToSettle(budget, request.categoryIds, couple.id)

        val existingSettlements = settlementRepository
            .findByBudgetIdAndYearMonthAndWeekNumber(request.budgetId, request.yearMonth, request.weekNumber)
            .associateBy { it.category?.id }

        val now = Instant.now()

        for (categoryId in categoriesToSettle) {
            val existing = existingSettlements[categoryId]
            if (existing != null) {
                existing.status = SettlementStatus.SETTLED
                existing.settledAt = now
                existing.settledBy = user
                existing.settledAmount = calculateSpentAmount(couple.id, categoryId, weekStart, weekEnd, userId)
                settlementRepository.save(existing)
            } else {
                val category = categoryId?.let {
                    categoryRepository.findById(it).orElse(null)
                }
                val spentAmount = calculateSpentAmount(couple.id, categoryId, weekStart, weekEnd, userId)
                settlementRepository.save(
                    WeeklyBudgetSettlement(
                        couple = couple,
                        budget = budget,
                        yearMonth = request.yearMonth,
                        weekNumber = request.weekNumber,
                        weekStart = weekStart,
                        weekEnd = weekEnd,
                        category = category,
                        settledAmount = spentAmount,
                        status = SettlementStatus.SETTLED,
                        settledAt = now,
                        settledBy = user
                    )
                )
            }
        }

        syncEventPublisher.publish(
            SyncEvent(
                type = "SETTLEMENT_UPDATED",
                entityType = "WEEKLY_SETTLEMENT",
                entityId = request.budgetId,
                coupleId = couple.id,
                authorId = userId
            )
        )
    }

    @Transactional
    fun unsettleWeek(userId: UUID, request: UnsettleWeekRequest) {
        val couple = getActiveCouple(userId)

        val budget = budgetRepository.findById(request.budgetId)
            .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Budget not found") }

        require(budget.couple.id == couple.id) { "Budget does not belong to this couple" }

        val ym = parseYearMonth(request.yearMonth)
        val weekRanges = WeeklyBudgetService.calculateWeekRanges(ym)
        require(request.weekNumber in 1..weekRanges.size) { "Invalid week number" }

        val categoriesToUnsettle = resolveCategoriesToSettle(budget, request.categoryIds, couple.id)

        val existingSettlements = settlementRepository
            .findByBudgetIdAndYearMonthAndWeekNumber(request.budgetId, request.yearMonth, request.weekNumber)
            .associateBy { it.category?.id }

        for (categoryId in categoriesToUnsettle) {
            val existing = existingSettlements[categoryId]
            if (existing != null && existing.status == SettlementStatus.SETTLED) {
                existing.status = SettlementStatus.PENDING
                existing.settledAt = null
                existing.settledBy = null
                settlementRepository.save(existing)
            }
        }

        syncEventPublisher.publish(
            SyncEvent(
                type = "SETTLEMENT_UPDATED",
                entityType = "WEEKLY_SETTLEMENT",
                entityId = request.budgetId,
                coupleId = couple.id,
                authorId = userId
            )
        )
    }

    private fun resolveCategoriesToSettle(
        budget: com.budgetbook.budget.domain.MonthlyBudget,
        requestCategoryIds: List<UUID>?,
        coupleId: UUID
    ): List<UUID?> {
        return when {
            // Specific categories requested
            requestCategoryIds != null -> requestCategoryIds.map { it }
            // Budget has a specific category
            budget.category != null -> listOf(budget.category!!.id)
            // Budget is for a group — settle all categories in the group
            budget.group != null -> {
                categoryRepository.findByCoupleId(coupleId)
                    .filter { it.group?.id == budget.group!!.id }
                    .map { it.id }
            }
            // No category/group — settle as null (total budget)
            else -> listOf(null)
        }
    }

    private fun calculateSpentAmount(
        coupleId: UUID,
        categoryId: UUID?,
        weekStart: java.time.LocalDate,
        weekEnd: java.time.LocalDate,
        userId: UUID
    ): Long {
        return if (categoryId != null) {
            transactionRepository.sumAmountGroupedByCategoryId(
                coupleId = coupleId,
                startDate = weekStart,
                endDate = weekEnd,
                type = TransactionType.EXPENSE,
                categoryIds = setOf(categoryId),
                userId = userId
            ).firstOrNull()?.let { (it[1] as Number).toLong() } ?: 0L
        } else {
            transactionRepository.sumAmountByCoupleIdAndDateRange(
                coupleId = coupleId,
                startDate = weekStart,
                endDate = weekEnd,
                type = TransactionType.EXPENSE,
                userId = userId
            )
        }
    }

    private fun formatYearMonth(year: Int, month: Int): String =
        "%04d-%02d".format(year, month)

    private fun parseYearMonth(yearMonth: String): YearMonth {
        val parts = yearMonth.split("-")
        return YearMonth.of(parts[0].toInt(), parts[1].toInt())
    }
}
