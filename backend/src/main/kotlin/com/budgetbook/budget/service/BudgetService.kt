package com.budgetbook.budget.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.budget.domain.BudgetPeriod
import com.budgetbook.budget.domain.BudgetRowKind
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
import com.budgetbook.spendingplan.repository.SpendingPlanRepository
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CategorySummary
import com.budgetbook.transaction.repository.TransactionRepository
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
    private val userRepository: UserRepository,
    private val spendingPlanRepository: SpendingPlanRepository
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

        // Derive visibility from category/group instead of request
        val visibility = when {
            category != null -> category.visibility
            group != null -> group.visibility
            else -> Visibility.SHARED
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

        // Phase 25 후속 C-2 — endYearMonth 와 rowKind 결정.
        // - request.endYearMonth == null → 단일월 OVERRIDE (endYearMonth=yearMonth)
        // - endYearMonth != yearMonth → TEMPLATE (yearMonth ~ endYearMonth, endYearMonth=null 도 무기한 TEMPLATE)
        val rowKind: BudgetRowKind
        val effectiveEndYearMonth: String?
        if (request.endYearMonth == null) {
            rowKind = BudgetRowKind.OVERRIDE
            effectiveEndYearMonth = request.yearMonth
        } else if (request.endYearMonth == request.yearMonth) {
            rowKind = BudgetRowKind.OVERRIDE
            effectiveEndYearMonth = request.yearMonth
        } else {
            rowKind = BudgetRowKind.TEMPLATE
            effectiveEndYearMonth = request.endYearMonth
        }

        val budget = MonthlyBudget(
            couple = couple,
            category = category,
            group = group,
            yearMonth = request.yearMonth,
            endYearMonth = effectiveEndYearMonth,
            rowKind = rowKind,
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
        val rows = budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, userId)
        return MonthlyBudgetResolver.resolveForMonth(rows).map { it.toResponse() }
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

        // Derive visibility from category/group
        val newVisibility = when {
            budget.category != null -> budget.category!!.visibility
            budget.group != null -> budget.group!!.visibility
            else -> Visibility.SHARED
        }
        budget.visibility = newVisibility
        if (newVisibility == Visibility.PRIVATE) {
            val user = userRepository.findById(userId)
                .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
            budget.owner = user
        } else {
            budget.owner = null
        }

        // Phase 25 후속 C-2 — applyToFuture=true 시 이 행을 TEMPLATE 으로 승격하고
        // endYearMonth=null (무기한) 으로 설정. 이후 같은 scope 의 OVERRIDE 가
        // 추가되면 우선순위에 따라 그 월만 덮어쓴다.
        // C-2.6: 승격 전, 같은 scope 의 다른 활성 TEMPLATE 이 있으면 자동 종료
        // (V57 partial unique 충돌 방지 + 사용자 의도 보존).
        if (request.applyToFuture) {
            terminateConflictingTemplate(budget)
            budget.rowKind = BudgetRowKind.TEMPLATE
            budget.endYearMonth = null
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
    fun deleteBudget(userId: UUID, budgetId: UUID, applyToFuture: Boolean = false) {
        val couple = getActiveCouple(userId)
        val budget = budgetRepository.findById(budgetId)
            .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Budget does not exist.") }

        OwnershipValidator.validateOwnership(budget.couple.id, couple, "Budget")
        validatePrivateOwner(budget, userId)

        // Phase 25 후속 C-2 — applyToFuture=true + TEMPLATE 인 경우, 행 삭제 대신
        // endYearMonth=(yearMonth-1) 로 종료. 이전 월들은 그대로 유효 처리.
        // - yearMonth == startYM 이면 시작월에서 종료가 불가능 → 행 삭제.
        // - OVERRIDE + applyToFuture: C-2.6 — 같은 scope 의 활성 TEMPLATE 도 종료 (사용자가
        //   "이 월 OVERRIDE + 미래 TEMPLATE 모두 종료" 의도로 누른 것으로 해석).
        if (applyToFuture && budget.rowKind == BudgetRowKind.TEMPLATE) {
            val prev = previousYearMonth(budget.yearMonth)
            if (prev >= budget.yearMonth) {
                budgetRepository.delete(budget)
            } else {
                budget.endYearMonth = prev
                budgetRepository.save(budget)
            }
        } else if (applyToFuture && budget.rowKind == BudgetRowKind.OVERRIDE) {
            terminateConflictingTemplate(budget)
            budgetRepository.delete(budget)
        } else {
            budgetRepository.delete(budget)
        }

        syncEventPublisher.publish(SyncEvent(
            type = "BUDGET_DELETED",
            entityType = "BUDGET",
            entityId = budgetId,
            coupleId = couple.id,
            authorId = userId
        ))
    }

    /** Phase 25 후속 C-2 — "YYYY-MM" 의 한 달 이전 문자열. */
    private fun previousYearMonth(yearMonth: String): String {
        val ym = YearMonth.parse(yearMonth)
        return ym.minusMonths(1).toString()
    }

    /**
     * Phase 25 후속 C-2.6 — 주어진 budget 과 같은 scope (couple, category, group) 의
     * 활성 TEMPLATE 을 (target.yearMonth - 1) 로 종료. 자기 자신은 제외.
     *
     * - 활성 TEMPLATE 이 없으면 no-op.
     * - 종료 시점이 시작월보다 이르면 (TEMPLATE 시작월 == budget.yearMonth) 행 삭제.
     * - V57 partial unique 보장으로 결과는 0~1건만 고려.
     */
    private fun terminateConflictingTemplate(budget: MonthlyBudget) {
        val existing = budgetRepository.findActiveTemplateInScope(
            coupleId = budget.couple.id,
            categoryId = budget.category?.id,
            groupId = budget.group?.id,
            targetYearMonth = budget.yearMonth,
            excludeId = budget.id
        ) ?: return
        val prev = previousYearMonth(budget.yearMonth)
        if (prev < existing.yearMonth) {
            budgetRepository.delete(existing)
        } else {
            existing.endYearMonth = prev
            budgetRepository.save(existing)
        }
    }

    @Transactional(readOnly = true)
    fun getBudgetSummary(userId: UUID, year: Int, month: Int): BudgetSummaryResponse {
        val couple = getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        val ym = YearMonth.of(year, month)
        val startDate = ym.atDay(1)
        val endDate = ym.atEndOfMonth()

        val budgets = MonthlyBudgetResolver.resolveForMonth(
            budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, yearMonth, userId)
        )

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

        // Pre-compute group spending with direct DB aggregation (no lazy loading dependency)
        val groupIds = budgets.mapNotNull { it.group?.id }.toSet()
        val spendingByGroup: Map<UUID, Long> = if (groupIds.isNotEmpty()) {
            val groupResults = transactionRepository.sumByCategoryGroupForCouple(
                couple.id, startDate, endDate, TransactionType.EXPENSE, groupIds, userId
            )
            groupResults.associate { row ->
                (row[0] as UUID) to (row[1] as Long)
            }
        } else {
            emptyMap()
        }

        // Pre-compute planned amounts from spending plans (WISHLIST/PLANNED status)
        val categoryIds = budgets.mapNotNull { it.category?.id }.toSet()
        val plannedByCategory: Map<UUID, Long> = if (categoryIds.isNotEmpty()) {
            spendingPlanRepository.sumPlannedAmountByCategoryIds(couple.id, categoryIds, userId)
                .associate { row -> (row[0] as UUID) to (row[1] as Long) }
        } else {
            emptyMap()
        }
        val plannedByGroup: Map<UUID, Long> = if (groupIds.isNotEmpty()) {
            spendingPlanRepository.sumPlannedAmountByGroupIds(couple.id, groupIds, userId)
                .associate { row -> (row[0] as UUID) to (row[1] as Long) }
        } else {
            emptyMap()
        }
        val totalPlannedAmount = spendingPlanRepository.sumTotalPlannedAmount(couple.id, userId)

        val items = budgets.map { budget ->
            val categoryId = budget.category?.id
            val groupId = budget.group?.id
            val spentAmount = when {
                categoryId != null -> spendingByCategory[categoryId] ?: 0L
                groupId != null -> spendingByGroup[groupId] ?: 0L
                else -> totalSpent
            }
            val plannedAmount = when {
                categoryId != null -> plannedByCategory[categoryId] ?: 0L
                groupId != null -> plannedByGroup[groupId] ?: 0L
                else -> totalPlannedAmount
            }

            val effectiveBudgetAmount = if (budget.budgetPeriod == BudgetPeriod.WEEKLY) {
                val weeklyAmt = budget.weeklyAmount ?: (budget.amount * 7 / ym.lengthOfMonth())
                weeklyAmt * ym.lengthOfMonth().toLong() / 7
            } else {
                budget.amount
            }

            val remainingAmount = effectiveBudgetAmount - spentAmount - plannedAmount
            val usageRate = if (effectiveBudgetAmount > 0) {
                Math.round((spentAmount + plannedAmount).toDouble() / effectiveBudgetAmount * 1000.0) / 10.0
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
                plannedAmount = plannedAmount,
                remainingAmount = remainingAmount,
                usageRate = usageRate
            )
        }

        val totalBudgetEntry = budgets.find { it.category == null && it.group == null }
        val effectiveTotalBudget: Long
        val effectiveTotalSpent: Long
        val effectiveTotalPlanned: Long

        if (totalBudgetEntry != null) {
            effectiveTotalBudget = totalBudgetEntry.amount
            effectiveTotalSpent = totalSpent
            effectiveTotalPlanned = totalPlannedAmount
        } else {
            val groupIdsWithBudget = budgets.mapNotNull { it.group?.id }.toSet()
            val coveredCategoryIds = if (groupIdsWithBudget.isNotEmpty()) {
                budgets
                    .filter { it.category != null && it.category!!.group?.id in groupIdsWithBudget }
                    .mapNotNull { it.category?.id }
                    .toSet()
            } else {
                emptySet()
            }

            val deduplicatedItems = items.filter { item ->
                val catId = item.category?.id
                catId == null || catId !in coveredCategoryIds
            }
            effectiveTotalBudget = deduplicatedItems.sumOf { it.budgetAmount }
            effectiveTotalSpent = deduplicatedItems.sumOf { it.spentAmount }
            effectiveTotalPlanned = deduplicatedItems.sumOf { it.plannedAmount }
        }

        return BudgetSummaryResponse(
            yearMonth = yearMonth,
            totalBudget = effectiveTotalBudget,
            totalSpent = effectiveTotalSpent,
            totalPlanned = effectiveTotalPlanned,
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

        val sourceBudgets = MonthlyBudgetResolver.resolveForMonth(
            budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, sourceYearMonth, userId)
        )
        if (sourceBudgets.isEmpty()) {
            throw NotFoundException("BUDGET_NOT_FOUND", "No budgets found for $sourceYearMonth.")
        }

        val existingTargetBudgets = MonthlyBudgetResolver.resolveForMonth(
            budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, targetYearMonth, userId)
        )
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
