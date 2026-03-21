package com.budgetbook.recurring.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.recurring.domain.Frequency
import com.budgetbook.transaction.service.TransactionService
import com.budgetbook.recurring.domain.RecurringTransaction
import com.budgetbook.recurring.dto.CreateRecurringTransactionRequest
import com.budgetbook.recurring.dto.RecurringTransactionResponse
import com.budgetbook.recurring.dto.UpdateRecurringTransactionRequest
import com.budgetbook.recurring.dto.toResponse
import com.budgetbook.recurring.repository.RecurringTransactionRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class RecurringTransactionService(
    private val recurringRepository: RecurringTransactionRepository,
    private val transactionRepository: TransactionRepository,
    override val coupleResolver: CoupleResolver,
    private val userRepository: UserRepository,
    private val categoryRepository: CategoryRepository,
    private val paymentMethodRepository: PaymentMethodRepository
) : CoupleAwareService {

    private val log = LoggerFactory.getLogger(javaClass)

    @Transactional(readOnly = true)
    fun listRecurringTransactions(userId: UUID): List<RecurringTransactionResponse> {
        val couple = getActiveCouple(userId)
        return recurringRepository.findByCoupleIdAndUserId(couple.id, userId)
            .map { it.toResponse() }
    }

    @Transactional
    fun createRecurringTransaction(
        userId: UUID,
        request: CreateRecurringTransactionRequest
    ): RecurringTransactionResponse {
        val couple = getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val transactionType = try {
            TransactionType.valueOf(request.type)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: ${request.type}")
        }

        val frequency = try {
            Frequency.valueOf(request.frequency)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid frequency: ${request.frequency}")
        }

        // Validate frequency + day combinations
        validateFrequencyDays(frequency, request.dayOfMonth, request.dayOfWeek)

        val category = request.categoryId?.let { catId ->
            val cat = categoryRepository.findById(catId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified category does not exist.") }
            OwnershipValidator.validateOwnership(cat.couple.id, couple, "Category")
            cat
        }

        val paymentMethod = request.paymentMethodId?.let { pmId ->
            val pm = paymentMethodRepository.findById(pmId)
                .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified payment method does not exist.") }
            OwnershipValidator.validateOwnership(pm.couple.id, couple, "Payment method")
            pm
        }

        val nextRunDate = calculateInitialNextRunDate(frequency, request.dayOfMonth, request.dayOfWeek)

        val visibility = TransactionService.parseVisibility(request.visibility)

        val recurring = RecurringTransaction(
            couple = couple,
            author = user,
            category = category,
            paymentMethod = paymentMethod,
            type = transactionType,
            amount = request.amount,
            description = request.description,
            memo = request.memo,
            frequency = frequency,
            dayOfMonth = request.dayOfMonth,
            dayOfWeek = request.dayOfWeek,
            nextRunDate = nextRunDate,
            visibility = visibility
        )

        return recurringRepository.save(recurring).toResponse()
    }

    @Transactional
    fun updateRecurringTransaction(
        userId: UUID,
        id: UUID,
        request: UpdateRecurringTransactionRequest
    ): RecurringTransactionResponse {
        val couple = getActiveCouple(userId)
        val recurring = recurringRepository.findById(id)
            .orElseThrow { NotFoundException("RECURRING_NOT_FOUND", "Recurring transaction does not exist.") }

        OwnershipValidator.validateOwnership(recurring.couple.id, couple, "Recurring transaction")

        // PRIVATE recurring transactions can only be modified by the author (owner)
        if (recurring.visibility == Visibility.PRIVATE && recurring.author.id != userId) {
            throw ForbiddenException("FORBIDDEN", "Only the owner can modify a private recurring transaction.")
        }

        request.amount?.let { recurring.amount = it }
        request.description?.let { recurring.description = it }
        request.memo?.let { recurring.memo = it }
        request.isActive?.let { recurring.isActive = it }

        // Handle visibility change
        request.visibility?.let { visStr ->
            recurring.visibility = TransactionService.parseVisibility(visStr)
        }

        request.categoryId?.let { catId ->
            val cat = categoryRepository.findById(catId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified category does not exist.") }
            OwnershipValidator.validateOwnership(cat.couple.id, couple, "Category")
            recurring.category = cat
        }

        request.paymentMethodId?.let { pmId ->
            val pm = paymentMethodRepository.findById(pmId)
                .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified payment method does not exist.") }
            OwnershipValidator.validateOwnership(pm.couple.id, couple, "Payment method")
            recurring.paymentMethod = pm
        }

        request.dayOfMonth?.let { recurring.dayOfMonth = it }
        request.dayOfWeek?.let { recurring.dayOfWeek = it }

        return recurringRepository.save(recurring).toResponse()
    }

    @Transactional
    fun deleteRecurringTransaction(userId: UUID, id: UUID) {
        val couple = getActiveCouple(userId)
        val recurring = recurringRepository.findById(id)
            .orElseThrow { NotFoundException("RECURRING_NOT_FOUND", "Recurring transaction does not exist.") }

        OwnershipValidator.validateOwnership(recurring.couple.id, couple, "Recurring transaction")

        if (recurring.visibility == Visibility.PRIVATE && recurring.author.id != userId) {
            throw ForbiddenException("FORBIDDEN", "Only the owner can delete a private recurring transaction.")
        }

        recurringRepository.delete(recurring)
    }

    @Transactional
    fun executeRecurringTransactions() {
        val today = LocalDate.now()
        val dueTransactions = recurringRepository.findByNextRunDateLessThanEqualAndIsActiveTrue(today)

        log.info("Processing {} due recurring transactions", dueTransactions.size)

        for (recurring in dueTransactions) {
            try {
                // Create actual transaction with visibility propagation
                val txVisibility = recurring.category?.visibility ?: recurring.visibility
                val txOwner = if (txVisibility == Visibility.PRIVATE) recurring.author else null
                val transaction = Transaction(
                    couple = recurring.couple,
                    author = recurring.author,
                    category = recurring.category,
                    type = recurring.type,
                    amount = recurring.amount,
                    description = recurring.description,
                    memo = recurring.memo,
                    transactionDate = recurring.nextRunDate,
                    paymentMethod = recurring.paymentMethod,
                    visibility = txVisibility,
                    owner = txOwner
                )
                transactionRepository.save(transaction)

                // Advance nextRunDate
                recurring.lastRunDate = recurring.nextRunDate
                recurring.nextRunDate = calculateNextRunDate(recurring)
                recurringRepository.save(recurring)

                log.info("Executed recurring transaction {} ({}), next run: {}",
                    recurring.id, recurring.description, recurring.nextRunDate)
            } catch (e: Exception) {
                log.error("Failed to execute recurring transaction {}: {}", recurring.id, e.message)
            }
        }
    }

    private fun validateFrequencyDays(frequency: Frequency, dayOfMonth: Int?, dayOfWeek: Int?) {
        when (frequency) {
            Frequency.MONTHLY -> {
                if (dayOfMonth == null) {
                    throw BusinessException("VALIDATION_ERROR", "dayOfMonth is required for MONTHLY frequency.")
                }
                if (dayOfMonth < 1 || dayOfMonth > 31) {
                    throw BusinessException("VALIDATION_ERROR", "dayOfMonth must be between 1 and 31.")
                }
            }
            Frequency.WEEKLY -> {
                if (dayOfWeek == null) {
                    throw BusinessException("VALIDATION_ERROR", "dayOfWeek is required for WEEKLY frequency.")
                }
                if (dayOfWeek < 1 || dayOfWeek > 7) {
                    throw BusinessException("VALIDATION_ERROR", "dayOfWeek must be between 1 and 7.")
                }
            }
            Frequency.YEARLY -> {
                if (dayOfMonth == null) {
                    throw BusinessException("VALIDATION_ERROR", "dayOfMonth is required for YEARLY frequency.")
                }
            }
            Frequency.DAILY -> { /* no day constraints */ }
        }
    }

    private fun calculateInitialNextRunDate(frequency: Frequency, dayOfMonth: Int?, dayOfWeek: Int?): LocalDate {
        val today = LocalDate.now()
        return when (frequency) {
            Frequency.DAILY -> today.plusDays(1)
            Frequency.WEEKLY -> {
                val targetDow = dayOfWeek!! // validated above
                val todayDow = today.dayOfWeek.value // 1=Monday, 7=Sunday
                val daysUntil = if (targetDow > todayDow) {
                    (targetDow - todayDow).toLong()
                } else if (targetDow == todayDow) {
                    7L
                } else {
                    (7 - todayDow + targetDow).toLong()
                }
                today.plusDays(daysUntil)
            }
            Frequency.MONTHLY -> {
                val dom = dayOfMonth!! // validated above
                val ym = YearMonth.of(today.year, today.monthValue)
                val targetDay = dom.coerceAtMost(ym.lengthOfMonth())
                val targetDate = today.withDayOfMonth(targetDay)
                if (targetDate.isAfter(today)) {
                    targetDate
                } else {
                    val nextYm = ym.plusMonths(1)
                    val nextDay = dom.coerceAtMost(nextYm.lengthOfMonth())
                    nextYm.atDay(nextDay)
                }
            }
            Frequency.YEARLY -> {
                val dom = dayOfMonth!! // validated above
                val currentMonth = today.monthValue
                val targetDate = LocalDate.of(today.year, currentMonth, dom.coerceAtMost(
                    YearMonth.of(today.year, currentMonth).lengthOfMonth()
                ))
                if (targetDate.isAfter(today)) {
                    targetDate
                } else {
                    LocalDate.of(today.year + 1, currentMonth, dom.coerceAtMost(
                        YearMonth.of(today.year + 1, currentMonth).lengthOfMonth()
                    ))
                }
            }
        }
    }

    fun calculateNextRunDate(recurring: RecurringTransaction): LocalDate {
        val current = recurring.nextRunDate
        return when (recurring.frequency) {
            Frequency.DAILY -> current.plusDays(1)
            Frequency.WEEKLY -> current.plusDays(7)
            Frequency.MONTHLY -> {
                val dom = recurring.dayOfMonth ?: current.dayOfMonth
                val nextYm = YearMonth.of(current.year, current.monthValue).plusMonths(1)
                val nextDay = dom.coerceAtMost(nextYm.lengthOfMonth())
                nextYm.atDay(nextDay)
            }
            Frequency.YEARLY -> {
                val dom = recurring.dayOfMonth ?: current.dayOfMonth
                val nextYear = current.year + 1
                val nextMonth = current.monthValue
                val nextDay = dom.coerceAtMost(
                    YearMonth.of(nextYear, nextMonth).lengthOfMonth()
                )
                LocalDate.of(nextYear, nextMonth, nextDay)
            }
        }
    }

}
