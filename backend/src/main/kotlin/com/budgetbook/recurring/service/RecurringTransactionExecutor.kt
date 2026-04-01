package com.budgetbook.recurring.service

import com.budgetbook.common.entity.Visibility
import com.budgetbook.recurring.domain.RecurringTransaction
import com.budgetbook.recurring.repository.RecurringTransactionRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.repository.TransactionRepository
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate

/**
 * Handles individual recurring transaction execution in its own transaction.
 * Separated from RecurringTransactionService to ensure REQUIRES_NEW propagation
 * works correctly (Spring proxy limitation prevents self-invocation).
 */
@Service
class RecurringTransactionExecutor(
    private val transactionRepository: TransactionRepository,
    private val recurringRepository: RecurringTransactionRepository
) {

    private val log = LoggerFactory.getLogger(javaClass)

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun executeSingle(recurring: RecurringTransaction, nextRunDate: LocalDate) {
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

        recurring.lastRunDate = recurring.nextRunDate
        recurring.nextRunDate = nextRunDate
        recurringRepository.save(recurring)

        log.info(
            "Executed recurring transaction {} ({}), next run: {}",
            recurring.id, recurring.description, recurring.nextRunDate
        )
    }
}
