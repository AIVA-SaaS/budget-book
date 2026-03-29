package com.budgetbook.spendingplan.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.spendingplan.domain.SpendingPlan
import com.budgetbook.spendingplan.domain.SpendingPlanPriority
import com.budgetbook.spendingplan.domain.SpendingPlanStatus
import com.budgetbook.spendingplan.dto.AssignSpendingPlanRequest
import com.budgetbook.spendingplan.dto.CompleteSpendingPlanRequest
import com.budgetbook.spendingplan.dto.CompleteWithTransactionRequest
import com.budgetbook.spendingplan.dto.CreateSpendingPlanRequest
import com.budgetbook.spendingplan.dto.SpendingPlanListResponse
import com.budgetbook.spendingplan.dto.SpendingPlanResponse
import com.budgetbook.spendingplan.dto.SpendingPlanSuggestion
import com.budgetbook.spendingplan.dto.SpendingPlanSummary
import com.budgetbook.spendingplan.dto.UpdateSpendingPlanRequest
import com.budgetbook.spendingplan.dto.toResponse
import com.budgetbook.spendingplan.repository.SpendingPlanRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.UUID
import kotlin.math.abs

@Service
class SpendingPlanService(
    private val spendingPlanRepository: SpendingPlanRepository,
    override val coupleResolver: CoupleResolver,
    private val userRepository: UserRepository,
    private val categoryRepository: CategoryRepository,
    private val paymentMethodRepository: PaymentMethodRepository,
    private val monthlyBudgetRepository: MonthlyBudgetRepository,
    private val transactionRepository: TransactionRepository
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun listPlans(
        userId: UUID,
        startDate: LocalDate?,
        endDate: LocalDate?,
        status: SpendingPlanStatus?
    ): SpendingPlanListResponse {
        val couple = getActiveCouple(userId)

        val effectiveStart = startDate ?: LocalDate.now().withDayOfMonth(1)
        val effectiveEnd = endDate ?: effectiveStart.withDayOfMonth(effectiveStart.lengthOfMonth())

        val plans = if (status != null) {
            spendingPlanRepository.findByCoupleAndDateRangeAndStatus(
                couple.id, effectiveStart, effectiveEnd, status, userId
            )
        } else {
            spendingPlanRepository.findByCoupleAndDateRange(
                couple.id, effectiveStart, effectiveEnd, userId
            )
        }

        val responses = plans.map { it.toResponse() }
        val summary = buildSummary(plans)

        return SpendingPlanListResponse(plans = responses, summary = summary)
    }

    @Transactional
    fun createPlan(userId: UUID, request: CreateSpendingPlanRequest): SpendingPlanResponse {
        val couple = getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val category = request.categoryId?.let { catId ->
            categoryRepository.findById(catId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified categoryId does not exist.") }
        }

        val paymentMethod = request.paymentMethodId?.let { pmId ->
            paymentMethodRepository.findById(pmId)
                .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified paymentMethodId does not exist.") }
                .also { OwnershipValidator.validateOwnership(it.couple.id, couple, "Payment method") }
        }

        val budget = request.budgetId?.let { budgetId ->
            monthlyBudgetRepository.findById(budgetId)
                .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Specified budgetId does not exist.") }
                .also { OwnershipValidator.validateOwnership(it.couple.id, couple, "Budget") }
        }

        if (request.isRecurring && request.frequency == null) {
            throw BusinessException("VALIDATION_ERROR", "frequency is required when isRecurring is true.")
        }

        val visibility = request.visibility?.let {
            try { Visibility.valueOf(it) } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid visibility value: $it")
            }
        } ?: Visibility.SHARED

        // Determine status: if no targetDate provided, status is WISHLIST
        val status = if (request.targetDate == null) {
            SpendingPlanStatus.WISHLIST
        } else {
            SpendingPlanStatus.PLANNED
        }

        // For PLANNED status, amount is required
        if (status == SpendingPlanStatus.PLANNED && (request.amount == null || request.amount < 1)) {
            throw BusinessException("VALIDATION_ERROR", "amount is required and must be >= 1 for PLANNED status.")
        }

        val plan = SpendingPlan(
            couple = couple,
            author = user,
            name = request.name,
            amount = request.amount ?: 0,
            targetDate = request.targetDate,
            memo = request.memo,
            category = category,
            paymentMethod = paymentMethod,
            budget = budget,
            status = status,
            priority = request.priority ?: SpendingPlanPriority.MEDIUM,
            estimatedMin = request.estimatedMin,
            estimatedMax = request.estimatedMax,
            tags = request.tags?.joinToString(","),
            weekNumber = request.weekNumber,
            isRecurring = request.isRecurring,
            frequency = request.frequency,
            visibility = visibility,
            owner = if (visibility == Visibility.PRIVATE) user else null
        )

        return spendingPlanRepository.save(plan).toResponse()
    }

    @Transactional
    fun updatePlan(userId: UUID, planId: UUID, request: UpdateSpendingPlanRequest): SpendingPlanResponse {
        val couple = getActiveCouple(userId)
        val plan = findPlanWithAccess(planId, couple.id, userId)

        request.name?.let { plan.name = it }
        request.amount?.let { plan.amount = it }
        request.targetDate?.let { plan.targetDate = it }

        request.memo?.let { patchValue ->
            plan.memo = patchValue.value
        }

        request.categoryId?.let { patchValue ->
            plan.category = patchValue.value?.let { catId ->
                categoryRepository.findById(catId)
                    .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified categoryId does not exist.") }
            }
        }

        request.paymentMethodId?.let { patchValue ->
            plan.paymentMethod = patchValue.value?.let { pmId ->
                paymentMethodRepository.findById(pmId)
                    .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified paymentMethodId does not exist.") }
                    .also { OwnershipValidator.validateOwnership(it.couple.id, couple, "Payment method") }
            }
        }

        request.budgetId?.let { patchValue ->
            plan.budget = patchValue.value?.let { budgetId ->
                monthlyBudgetRepository.findById(budgetId)
                    .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Specified budgetId does not exist.") }
                    .also { OwnershipValidator.validateOwnership(it.couple.id, couple, "Budget") }
            }
        }

        request.isRecurring?.let { plan.isRecurring = it }

        request.frequency?.let { patchValue ->
            plan.frequency = patchValue.value
        }

        request.visibility?.let { visStr ->
            val newVisibility = try { Visibility.valueOf(visStr) } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid visibility value: $visStr")
            }
            plan.visibility = newVisibility
            if (newVisibility == Visibility.PRIVATE && plan.owner == null) {
                val user = userRepository.findById(userId)
                    .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
                plan.owner = user
            } else if (newVisibility == Visibility.SHARED) {
                plan.owner = null
            }
        }

        request.priority?.let { plan.priority = it }

        request.estimatedMin?.let { patchValue ->
            plan.estimatedMin = patchValue.value
        }

        request.estimatedMax?.let { patchValue ->
            plan.estimatedMax = patchValue.value
        }

        request.tags?.let { patchValue ->
            plan.tags = patchValue.value?.joinToString(",")
        }

        request.weekNumber?.let { patchValue ->
            plan.weekNumber = patchValue.value
        }

        return spendingPlanRepository.save(plan).toResponse()
    }

    @Transactional
    fun deletePlan(userId: UUID, planId: UUID) {
        val couple = getActiveCouple(userId)
        val plan = findPlanWithAccess(planId, couple.id, userId)
        spendingPlanRepository.delete(plan)
    }

    @Transactional
    fun completePlan(userId: UUID, planId: UUID, request: CompleteSpendingPlanRequest): SpendingPlanResponse {
        val couple = getActiveCouple(userId)
        val plan = findPlanWithAccess(planId, couple.id, userId)

        if (plan.status != SpendingPlanStatus.PLANNED && plan.status != SpendingPlanStatus.OVERDUE) {
            throw BusinessException("INVALID_STATUS", "Only PLANNED or OVERDUE plans can be completed.")
        }

        request.linkedTransactionId?.let { txId ->
            val transaction = transactionRepository.findById(txId)
                .orElseThrow { NotFoundException("TRANSACTION_NOT_FOUND", "Specified transaction does not exist.") }
            plan.linkedTransaction = transaction
            // Use transaction amount as actual amount if not explicitly provided
            if (request.actualAmount == null) {
                plan.actualAmount = transaction.amount
            }
        }

        request.actualAmount?.let { plan.actualAmount = it }

        plan.completedDate = request.completedDate ?: LocalDate.now()
        plan.status = SpendingPlanStatus.COMPLETED

        return spendingPlanRepository.save(plan).toResponse()
    }

    @Transactional
    fun skipPlan(userId: UUID, planId: UUID): SpendingPlanResponse {
        val couple = getActiveCouple(userId)
        val plan = findPlanWithAccess(planId, couple.id, userId)

        if (plan.status != SpendingPlanStatus.PLANNED && plan.status != SpendingPlanStatus.OVERDUE) {
            throw BusinessException("INVALID_STATUS", "Only PLANNED or OVERDUE plans can be skipped.")
        }

        plan.status = SpendingPlanStatus.SKIPPED

        return spendingPlanRepository.save(plan).toResponse()
    }

    @Transactional
    fun assignPlan(userId: UUID, planId: UUID, request: AssignSpendingPlanRequest): SpendingPlanResponse {
        val couple = getActiveCouple(userId)
        val plan = findPlanWithAccess(planId, couple.id, userId)

        if (plan.status != SpendingPlanStatus.WISHLIST) {
            throw BusinessException("INVALID_STATUS", "Only WISHLIST plans can be assigned.")
        }

        plan.targetDate = request.targetDate
        plan.status = SpendingPlanStatus.PLANNED
        request.weekNumber?.let { plan.weekNumber = it }

        request.budgetId?.let { budgetId ->
            val budget = monthlyBudgetRepository.findById(budgetId)
                .orElseThrow { NotFoundException("BUDGET_NOT_FOUND", "Specified budgetId does not exist.") }
                .also { OwnershipValidator.validateOwnership(it.couple.id, couple, "Budget") }
            plan.budget = budget
        }

        return spendingPlanRepository.save(plan).toResponse()
    }

    @Transactional(readOnly = true)
    fun getWishlist(userId: UUID): List<SpendingPlanResponse> {
        val couple = getActiveCouple(userId)
        val plans = spendingPlanRepository.findWishlistByCoupleId(couple.id, userId)
        return plans.map { it.toResponse() }
    }

    @Transactional
    fun completeWithTransaction(userId: UUID, planId: UUID, request: CompleteWithTransactionRequest): SpendingPlanResponse {
        val couple = getActiveCouple(userId)
        val plan = findPlanWithAccess(planId, couple.id, userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        if (plan.status != SpendingPlanStatus.PLANNED && plan.status != SpendingPlanStatus.OVERDUE && plan.status != SpendingPlanStatus.WISHLIST) {
            throw BusinessException("INVALID_STATUS", "Only WISHLIST, PLANNED or OVERDUE plans can be completed.")
        }

        val category = request.categoryId?.let { catId ->
            categoryRepository.findById(catId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified categoryId does not exist.") }
        } ?: plan.category

        val paymentMethod = request.paymentMethodId?.let { pmId ->
            paymentMethodRepository.findById(pmId)
                .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified paymentMethodId does not exist.") }
                .also { OwnershipValidator.validateOwnership(it.couple.id, couple, "Payment method") }
        } ?: plan.paymentMethod

        val transaction = Transaction(
            couple = couple,
            author = user,
            category = category,
            type = TransactionType.EXPENSE,
            amount = request.amount,
            description = request.description ?: plan.name,
            transactionDate = request.transactionDate,
            paymentMethod = paymentMethod,
            visibility = plan.visibility,
            owner = plan.owner
        )
        transactionRepository.save(transaction)

        plan.linkedTransaction = transaction
        plan.status = SpendingPlanStatus.COMPLETED
        plan.actualAmount = request.amount
        plan.completedDate = request.transactionDate

        return spendingPlanRepository.save(plan).toResponse()
    }

    @Transactional(readOnly = true)
    fun getSuggestions(userId: UUID, categoryId: UUID?, amount: Long, date: LocalDate): List<SpendingPlanSuggestion> {
        val couple = getActiveCouple(userId)

        if (categoryId == null) return emptyList()

        // Search window: date +/- 3 days
        val startDate = date.minusDays(3)
        val endDate = date.plusDays(3)

        val matchingPlans = spendingPlanRepository.findMatchingPlans(
            coupleId = couple.id,
            categoryId = categoryId,
            startDate = startDate,
            endDate = endDate
        )

        return matchingPlans
            .map { plan ->
                val (score, reasons) = calculateMatchScoreWithReasons(plan, categoryId, amount, date)
                SpendingPlanSuggestion(
                    planId = plan.id,
                    name = plan.name,
                    plannedAmount = plan.amount,
                    matchScore = Math.round(score * 100) / 100.0,
                    matchReasons = reasons
                )
            }
            .filter { it.matchScore > 0.3 }
            .sortedByDescending { it.matchScore }
    }

    // ── Private Helpers ──

    private fun findPlanWithAccess(planId: UUID, coupleId: UUID, userId: UUID): SpendingPlan {
        val plan = spendingPlanRepository.findByIdAndCoupleId(planId, coupleId)
            ?: throw NotFoundException("SPENDING_PLAN_NOT_FOUND", "Spending plan does not exist or belongs to another couple.")

        if (plan.visibility == Visibility.PRIVATE && plan.owner?.id != null && plan.owner?.id != userId) {
            throw ForbiddenException("PRIVATE_ACCESS_DENIED", "Spending plan is PRIVATE and caller is not the owner.")
        }

        return plan
    }

    private fun buildSummary(plans: List<SpendingPlan>): SpendingPlanSummary {
        var totalPlanned = 0L
        var totalCompleted = 0L
        var totalSkipped = 0L
        var plannedCount = 0
        var completedCount = 0
        var skippedCount = 0
        var overdueCount = 0
        var wishlistCount = 0

        for (plan in plans) {
            when (plan.status) {
                SpendingPlanStatus.WISHLIST -> {
                    wishlistCount++
                }
                SpendingPlanStatus.PLANNED -> {
                    totalPlanned += plan.amount
                    plannedCount++
                }
                SpendingPlanStatus.COMPLETED -> {
                    totalCompleted += (plan.actualAmount ?: plan.amount)
                    completedCount++
                }
                SpendingPlanStatus.SKIPPED -> {
                    totalSkipped += plan.amount
                    skippedCount++
                }
                SpendingPlanStatus.OVERDUE -> {
                    totalPlanned += plan.amount
                    overdueCount++
                }
            }
        }

        return SpendingPlanSummary(
            totalPlanned = totalPlanned,
            totalCompleted = totalCompleted,
            totalSkipped = totalSkipped,
            plannedCount = plannedCount,
            completedCount = completedCount,
            skippedCount = skippedCount,
            overdueCount = overdueCount,
            wishlistCount = wishlistCount
        )
    }

    private fun calculateMatchScoreWithReasons(
        plan: SpendingPlan,
        categoryId: UUID?,
        amount: Long,
        date: LocalDate
    ): Pair<Double, List<String>> {
        var score = 0.0
        val reasons = mutableListOf<String>()

        // Category match (40% weight)
        if (plan.category?.id == categoryId) {
            score += 0.4
            reasons.add("Same category")
        }

        // Amount similarity (30% weight) - within 20%
        if (plan.amount > 0) {
            val amountDiff = abs(plan.amount - amount).toDouble() / plan.amount
            if (amountDiff <= 0.2) {
                val amountScore = 0.3 * (1 - amountDiff)
                score += amountScore
                val diffPercent = Math.round(amountDiff * 1000) / 10.0
                reasons.add("Amount diff ${diffPercent}%")
            }
        }

        // Date proximity (30% weight) - within 3 days
        val targetDate = plan.targetDate ?: return Pair(score, reasons)
        val daysDiff = abs(ChronoUnit.DAYS.between(targetDate, date))
        if (daysDiff <= 3) {
            val dateScore = 0.3 * (1 - daysDiff / 3.0)
            score += dateScore
            if (daysDiff == 0L) {
                reasons.add("Same date")
            } else {
                reasons.add("Date diff ${daysDiff}d")
            }
        }

        return Pair(score, reasons)
    }
}
