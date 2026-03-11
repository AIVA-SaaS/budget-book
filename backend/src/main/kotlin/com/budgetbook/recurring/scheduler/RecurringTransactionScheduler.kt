package com.budgetbook.recurring.scheduler

import com.budgetbook.recurring.service.RecurringTransactionService
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component

@Component
class RecurringTransactionScheduler(
    private val recurringTransactionService: RecurringTransactionService
) {

    private val log = LoggerFactory.getLogger(javaClass)

    @Scheduled(cron = "0 0 6 * * *")
    fun processRecurringTransactions() {
        log.info("Starting scheduled recurring transaction processing")
        recurringTransactionService.executeRecurringTransactions()
        log.info("Completed scheduled recurring transaction processing")
    }
}
