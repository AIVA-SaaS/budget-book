package com.budgetbook.couple.event

import com.budgetbook.auth.event.UserCreatedEvent
import com.budgetbook.couple.service.CoupleService
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import org.springframework.transaction.event.TransactionPhase
import org.springframework.transaction.event.TransactionalEventListener

@Component
class UserCreatedEventListener(
    private val coupleService: CoupleService
) {
    private val log = LoggerFactory.getLogger(javaClass)

    @TransactionalEventListener(phase = TransactionPhase.BEFORE_COMMIT)
    fun onUserCreated(event: UserCreatedEvent) {
        log.info("New user created, creating self-couple for userId={}", event.userId)
        coupleService.createSelfCouple(event.userId)
    }
}
