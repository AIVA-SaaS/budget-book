package com.budgetbook.budget.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.MonthlyBudget
import com.budgetbook.budget.domain.PeriodType
import com.budgetbook.budget.dto.BudgetRequest
import com.budgetbook.budget.dto.BudgetResponse
import com.budgetbook.budget.dto.BudgetSummaryItemResponse
import com.budgetbook.budget.dto.BudgetSummaryResponse
import com.budgetbook.budget.dto.BudgetUpdateRequest
import com.budgetbook.budget.dto.CopyBudgetRequest
import com.budgetbook.budget.dto.toResponse
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CategorySummary
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transaction.service.TransactionService
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.ChronoUnit
import java.util.UUID

@Service
class BudgetService(
    private val budgetRepository: MonthlyBudgetRepository,
    override val coupleResolver: CoupleResolver,
    private val categoryRepository: CategoryRepository,
    private val categoryGroupRepository: CategoryGroupRepository,
    private val transactionRepository: TransactionRepository,
    private val syncEventPublisher: SyncEventPublisher,
    private val moneyPocketRepository: MoneyPocketRepository,
    private val userRepository: UserRepository
) : CoupleAwareService {

    @Transactional
    fun createBudget(userId: UUID, request: BudgetRequest): BudgetResponse {
        val couple = getActiveCouple(userId)

        // Validate mutual exclusivity of categoryId and groupId
        if (request.categoryId != null && request.groupId != null) {
            throw com.budgetbook.common.exception.BusinessException(
                "VALIDATION_ERROR", "categoryId and groupId are mutually exclusive. Provide only one."
            )
        }

        val visibility = TransactionService.parseVisibility(request.visibility)

        val category = request.categoryId?.let { catId ->
            val cat = categoryRepository.findById(catId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified category does not exist.") }
            OwnershipValidator.validateOwnership(cat.couple.id, couple, "Category")
            cat
        }

        val group = request.groupId?.let { gId ->
            val g = categoryGroupRepository.findByIdAndCoupleId(gId, couple.id)
                ?: throw NotFoundException("GROUP_NOT_FOUND", "Specified category group does not exist.")
            g
        }

        // Validate pocket ownership
        val pocket = if (request.pocketId != null) {
            moneyPocketRepository.findById(request.pocketId).orElseThrow {
                NotFoundException("POCKET_NOT_FOUND", "Pocket not found.")
            }.also {
                OwnershipValidator.validateOwnership(it.couple.id, couple, "Pocket")
            }
        } else null

        if (budgetRepository.existsByCoupleIdAndCategoryGroupAndYearMonth(couple.id, request.categoryId, request.groupId, request.yearMonth)) {
            throw ConflictException("DUPLICATE_BUDGET", "Budget for this category/group and month already exists.")
        }

        val budgetPeriod = try {
            BudgetPeriod.valueOf(request.budgetPeriod ?: "MONTHLY")
        } catch (e: IllegalArgumentException) {
            throw com.budgetbook.common.exception.BusinessException(
                "VALIDATION_ERROR", "Invalid budget period: ${request.budgetPeriod}"
            )
        }

        // Resolve periodType
        val periodType = if (request.periodType != null) {
            try {
                PeriodType.valueOf(request.periodType)
            } catch (e: IllegalArgumentException) {
                throw com.budgetbook.common.exception.BusinessException(
                    "VALIDATION_ERROR", "Invalid period type: ${request.periodType}"
                )
            }
        } else {
            when (budgetPeriod) {
                BudgetPeriod.WEEKLY -> PeriodType.WEEKLY
                BudgetPeriod.MONTHLY -> PeriodType.MONTHLY
            }
        }

        val weeklyAmount = if (budgetPeriod == BudgetPeriod.WEEKLY) {
            // Use client-provided weeklyAmount (the per-week budget the user intended),
            // falling back to amount / numberOfWeeks for backward compat
            request.weeklyAmount ?: (request.amount / calculateNumberOfWeeks(request.yearMonth))
        } else {
            null
        }

        val (startDate, endDate) = resolveStartEndDates(periodType, request.yearMonth, request.startDate, request.endDate)

        val owner = if (visibility == Visibility.PRIVATE) {
            userRepository.findById(userId)
                .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
        } else null

        val budget = MonthlyBudget(
            couple = couple,
            category = category,
            group = group,
            yearMonth = request.yearMonth,
            amount = request.amount,
            budgetPeriod = budgetPeriod,
            weeklyAmount = weeklyAmount,
            periodType = periodType,
            startDate = startDate,
            endDate = endDate,
            pocket = pocket,
            visibility = visibility,
            owner = owner
        )

        val saved = budgetRepository.save(budget)
        syncEventPublisher.publish(SyncEvent(
            type = "BUDGET_CREATED",
            entityType = "BUDGET",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse()
    }

    @Transactional(readOnly = true)
    fun getBudgetsByMonth(userId: UUID, year: Int, month: Int): List<BudgetResponse> {
        val couple = getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        return budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, userId)
            .map { it.toResponse() }
    }

    @Transactional
    fun updateBudget(userId: UUID, budgetId: UUID, request: BudgetUpdateRequest): BudgetResponse {
        val couple = getActiveCouple(userId)
        val budget = budgetRepository.findById(budgetId)
            .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Budget does not exist.") }

        OwnershipValidator.validateOwnership(budget.couple.id, couple, "Budget")
        validatePrivateOwner(budget, userId)

        // Update category if provided
        request.categoryId?.let { catId ->
            val cat = categoryRepository.findById(catId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified category does not exist.") }
            OwnershipValidator.validateOwnership(cat.couple.id, couple, "Category")
            budget.category = cat
            budget.group = null  // Mutual exclusivity
        }

        // Update group if provided
        request.groupId?.let { gId ->
            val g = categoryGroupRepository.findByIdAndCoupleId(gId, couple.id)
                ?: throw NotFoundException("GROUP_NOT_FOUND", "Specified category group does not exist.")
            budget.group = g
            budget.category = null  // Mutual exclusivity
        }

        budget.amount = request.amount

        request.budgetPeriod?.let { periodStr ->
            val newPeriod = try {
                BudgetPeriod.valueOf(periodStr)
            } catch (e: IllegalArgumentException) {
                throw com.budgetbook.common.exception.BusinessException(
                    "VALIDATION_ERROR", "Invalid budget period: $periodStr"
                )
            }
            budget.budgetPeriod = newPeriod
            budget.weeklyAmount = if (newPeriod == BudgetPeriod.WEEKLY) {
                request.weeklyAmount ?: (request.amount / calculateNumberOfWeeks(budget.yearMonth))
            } else {
                null
            }
        } ?: run {
            if (budget.budgetPeriod == BudgetPeriod.WEEKLY) {
                budget.weeklyAmount = request.weeklyAmount
                    ?: (request.amount / calculateNumberOfWeeks(budget.yearMonth))
            }
        }

        // Update periodType and date range if provided
        request.periodType?.let { ptStr ->
            val newPeriodType = try {
                PeriodType.valueOf(ptStr)
            } catch (e: IllegalArgumentException) {
                throw com.budgetbook.common.exception.BusinessException(
                    "VALIDATION_ERROR", "Invalid period type: $ptStr"
                )
            }
            budget.periodType = newPeriodType
            val (sd, ed) = resolveStartEndDates(newPeriodType, budget.yearMonth, request.startDate, request.endDate)
            budget.startDate = sd
            budget.endDate = ed
        } ?: run {
            if (request.startDate != null) budget.startDate = request.startDate
            if (request.endDate != null) budget.endDate = request.endDate
        }

        // Update pocket if provided
        if (request.pocketId != null) {
            val pocket = moneyPocketRepository.findById(request.pocketId).orElseThrow {
                NotFoundException("POCKET_NOT_FOUND", "Pocket not found.")
            }
            OwnershipValidator.validateOwnership(pocket.couple.id, couple, "Pocket")
            budget.pocket = pocket
        }

        // Handle visibility change
        request.visibility?.let { visStr ->
            val newVisibility = TransactionService.parseVisibility(visStr)
            budget.visibility = newVisibility
            if (newVisibility == Visibility.PRIVATE) {
                val user = userRepository.findById(userId)
                    .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
                budget.owner = user
            } else {
                budget.owner = null
            }
        }

        val saved = budgetRepository.save(budget)
        syncEventPublisher.publish(SyncEvent(
            type = "BUDGET_UPDATED",
            entityType = "BUDGET",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse()
    }

    @Transactional
    fun deleteBudget(userId: UUID, budgetId: UUID) {
        val couple = getActiveCouple(userId)
        val budget = budgetRepository.findById(budgetId)
            .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Budget does not exist.") }

        OwnershipValidator.validateOwnership(budget.couple.id, couple, "Budget")
        validatePrivateOwner(budget, userId)

        budgetRepository.delete(budget)
        syncEventPublisher.publish(SyncEvent(
            type = "BUDGET_DELETED",
            entityType = "BUDGET",
            entityId = budgetId,
            coupleId = couple.id,
            authorId = userId
        ))
    }

    @Transactional(readOnly = true)
    fun getBudgetSummary(userId: UUID, year: Int, month: Int): BudgetSummaryResponse {
        val couple = getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        val ym = YearMonth.of(year, month)
        val startDate = ym.atDay(1)
        val endDate = ym.atEndOfMonth()

        val allBudgets = budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, userId)
        // Monthly view only includes MONTHLY budgets; WEEKLY budgets are shown in the weekly view
        val budgets = allBudgets.filter { it.budgetPeriod == BudgetPeriod.MONTHLY }

        val categoryExpenseResults = transactionRepository.sumByCategoryForCouple(
            couple.id, startDate, endDate, TransactionType.EXPENSE, userId
        )
        val spendingByCategory = categoryExpenseResults.associate { row ->
            (row[2] as UUID) to (row[0] as Long)
        }

        val totalSpent = transactionRepository.sumAmountByCoupleIdAndDateRange(
            coupleId = couple.id,
            startDate = startDate,
            endDate = endDate,
            type = TransactionType.EXPENSE,
            userId = userId
        )

        val items = budgets.map { budget ->
            val categoryId = budget.category?.id
            val groupId = budget.group?.id
            val spentAmount = when {
                categoryId != null -> spendingByCategory[categoryId] ?: 0L
                groupId != null -> transactionRepository.sumAmountByGroupAndDateRange(
                    coupleId = couple.id,
                    groupId = groupId,
                    startDate = startDate,
                    endDate = endDate,
                    type = TransactionType.EXPENSE,
                    userId = userId
                )
                else -> totalSpent
            }

            val effectiveBudgetAmount = budget.amount

            val remainingAmount = effectiveBudgetAmount - spentAmount
            val usageRate = if (effectiveBudgetAmount > 0) {
                Math.round(spentAmount.toDouble() / effectiveBudgetAmount * 1000.0) / 10.0
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
                        color = it.color,
                        groupId = it.group?.id,
                        groupName = it.group?.name
                    )
                },
                groupId = budget.group?.id,
                groupName = budget.group?.name,
                budgetAmount = effectiveBudgetAmount,
                spentAmount = spentAmount,
                remainingAmount = remainingAmount,
                usageRate = usageRate
            )
        }

        val totalBudgetEntry = budgets.find { it.category == null && it.group == null }
        val totalBudget = if (totalBudgetEntry != null) {
            totalBudgetEntry.amount
        } else {
            items.sumOf { it.budgetAmount }
        }

        return BudgetSummaryResponse(
            yearMonth = yearMonth,
            totalBudget = totalBudget,
            totalSpent = totalSpent,
            items = items
        )
    }

    @Transactional
    fun copyFromPreviousMonth(userId: UUID, request: CopyBudgetRequest): List<BudgetResponse> {
        val couple = getActiveCouple(userId)

        val sourceYearMonth = formatYearMonth(request.sourceYear, request.sourceMonth)
        val targetYearMonth = formatYearMonth(request.targetYear, request.targetMonth)

        if (sourceYearMonth == targetYearMonth) {
            throw com.budgetbook.common.exception.BusinessException(
                "VALIDATION_ERROR", "Source and target month must be different."
            )
        }

        val sourceBudgets = budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, sourceYearMonth, userId)
        if (sourceBudgets.isEmpty()) {
            throw NotFoundException("BUDGET_NOT_FOUND", "No budgets found for $sourceYearMonth.")
        }

        val existingTargetBudgets = budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, targetYearMonth, userId)
        val existingKeys = existingTargetBudgets.map { Pair(it.category?.id, it.group?.id) }.toSet()

        val numberOfWeeks = calculateNumberOfWeeks(targetYearMonth)

        val newBudgets = sourceBudgets
            .filter { Pair(it.category?.id, it.group?.id) !in existingKeys }
            .map { source ->
                val weeklyAmount = if (source.budgetPeriod == BudgetPeriod.WEEKLY) {
                    source.amount / numberOfWeeks
                } else {
                    null
                }
                val (sd, ed) = resolveStartEndDates(source.periodType, targetYearMonth, null, null)
                MonthlyBudget(
                    couple = couple,
                    category = source.category,
                    group = source.group,
                    yearMonth = targetYearMonth,
                    amount = source.amount,
                    budgetPeriod = source.budgetPeriod,
                    weeklyAmount = weeklyAmount,
                    periodType = source.periodType,
                    startDate = sd,
                    endDate = ed,
                    pocket = source.pocket,
                    visibility = source.visibility,
                    owner = source.owner
                )
            }

        if (newBudgets.isEmpty()) {
            return emptyList()
        }

        val saved = budgetRepository.saveAll(newBudgets)
        saved.forEach { budget ->
            syncEventPublisher.publish(SyncEvent(
                type = "BUDGET_CREATED",
                entityType = "BUDGET",
                entityId = budget.id,
                coupleId = couple.id,
                authorId = userId
            ))
        }
        return saved.map { it.toResponse() }
    }

    private fun validatePrivateOwner(budget: MonthlyBudget, userId: UUID) {
        if (budget.visibility == Visibility.PRIVATE && budget.owner?.id != null && budget.owner?.id != userId) {
            throw ForbiddenException("FORBIDDEN", "Only the owner can modify a private budget.")
        }
    }

    private fun formatYearMonth(year: Int, month: Int): String =
        "%04d-%02d".format(year, month)

    private fun resolveStartEndDates(
        periodType: PeriodType,
        yearMonth: String,
        requestStartDate: LocalDate?,
        requestEndDate: LocalDate?
    ): Pair<LocalDate?, LocalDate?> {
        return when (periodType) {
            PeriodType.NONE -> Pair(null, null)
            PeriodType.DAILY -> Pair(requestStartDate, requestEndDate)
            PeriodType.WEEKLY, PeriodType.MONTHLY -> {
                if (requestStartDate != null && requestEndDate != null) {
                    Pair(requestStartDate, requestEndDate)
                } else {
                    val parts = yearMonth.split("-")
                    val ym = YearMonth.of(parts[0].toInt(), parts[1].toInt())
                    Pair(ym.atDay(1), ym.atEndOfMonth())
                }
            }
        }
    }

    private fun calculateNumberOfWeeks(yearMonth: String): Int {
        val parts = yearMonth.split("-")
        val ym = YearMonth.of(parts[0].toInt(), parts[1].toInt())
        val lastDay = ym.lengthOfMonth()
        return if (lastDay > 28) 5 else 4
    }
}
