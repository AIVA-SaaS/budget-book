package com.budgetbook.sync

import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.springframework.messaging.simp.SimpMessagingTemplate
import java.util.UUID

class SyncEventPublisherTest : BehaviorSpec({

    val messagingTemplate = mockk<SimpMessagingTemplate>(relaxed = true)
    val publisher = SyncEventPublisher(messagingTemplate)

    Given("a sync event") {
        val coupleId = UUID.randomUUID()
        val entityId = UUID.randomUUID()
        val authorId = UUID.randomUUID()

        val event = SyncEvent(
            type = "TRANSACTION_CREATED",
            entityType = "TRANSACTION",
            entityId = entityId,
            coupleId = coupleId,
            authorId = authorId
        )

        When("publish is called") {
            publisher.publish(event)

            Then("sends the event to the correct STOMP destination") {
                val destinationSlot = slot<String>()
                val eventSlot = slot<SyncEvent>()
                verify { messagingTemplate.convertAndSend(capture(destinationSlot), capture(eventSlot)) }
                destinationSlot.captured shouldBe "/topic/couple/$coupleId"
                eventSlot.captured.type shouldBe "TRANSACTION_CREATED"
                eventSlot.captured.entityId shouldBe entityId
            }
        }
    }

    Given("a messaging template that throws an exception") {
        val coupleId = UUID.randomUUID()
        val event = SyncEvent(
            type = "BUDGET_UPDATED",
            entityType = "BUDGET",
            entityId = UUID.randomUUID(),
            coupleId = coupleId,
            authorId = UUID.randomUUID()
        )

        every { messagingTemplate.convertAndSend(any<String>(), any<Any>()) } throws RuntimeException("WebSocket down")

        When("publish is called") {
            // Should not throw -- failure is caught internally
            publisher.publish(event)

            Then("does not propagate the exception") {
                // Test passes if no exception was thrown
            }
        }
    }
})
