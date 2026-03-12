package com.budgetbook.sync

import org.slf4j.LoggerFactory
import org.springframework.messaging.simp.SimpMessagingTemplate
import org.springframework.stereotype.Service

@Service
class SyncEventPublisher(
    private val messagingTemplate: SimpMessagingTemplate
) {

    private val log = LoggerFactory.getLogger(javaClass)

    fun publish(event: SyncEvent) {
        try {
            val destination = "/topic/couple/${event.coupleId}"
            messagingTemplate.convertAndSend(destination, event)
            log.debug("Published sync event: type={}, entityId={}, destination={}",
                event.type, event.entityId, destination)
        } catch (e: Exception) {
            log.warn("Failed to publish sync event: type={}, entityId={}, error={}",
                event.type, event.entityId, e.message)
        }
    }
}
