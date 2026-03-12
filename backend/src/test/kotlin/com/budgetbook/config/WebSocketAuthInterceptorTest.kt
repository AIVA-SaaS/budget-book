package com.budgetbook.config

import com.budgetbook.auth.service.JwtTokenProvider
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.mockk.every
import io.mockk.mockk
import org.springframework.messaging.MessageDeliveryException
import org.springframework.messaging.simp.stomp.StompCommand
import org.springframework.messaging.simp.stomp.StompHeaderAccessor
import org.springframework.messaging.support.MessageBuilder
import java.util.UUID

class WebSocketAuthInterceptorTest : BehaviorSpec({

    val jwtTokenProvider = mockk<JwtTokenProvider>()
    val interceptor = WebSocketAuthInterceptor(jwtTokenProvider)

    Given("a STOMP CONNECT frame with a valid JWT token") {
        val userId = UUID.randomUUID()
        val token = "valid-jwt-token"

        every { jwtTokenProvider.validateToken(token) } returns true
        every { jwtTokenProvider.getUserIdFromToken(token) } returns userId

        When("preSend is called") {
            val accessor = StompHeaderAccessor.create(StompCommand.CONNECT)
            accessor.setLeaveMutable(true)
            accessor.addNativeHeader("Authorization", "Bearer $token")
            val message = MessageBuilder.createMessage(ByteArray(0), accessor.messageHeaders)

            val result = interceptor.preSend(message, mockk())

            Then("sets the principal with the userId") {
                val resultAccessor = StompHeaderAccessor.wrap(result)
                resultAccessor.user shouldNotBe null
                resultAccessor.user!!.name shouldBe userId.toString()
            }
        }
    }

    Given("a STOMP CONNECT frame without an Authorization header") {
        When("preSend is called") {
            val accessor = StompHeaderAccessor.create(StompCommand.CONNECT)
            accessor.setLeaveMutable(true)
            val message = MessageBuilder.createMessage(ByteArray(0), accessor.messageHeaders)

            Then("throws MessageDeliveryException") {
                shouldThrow<MessageDeliveryException> {
                    interceptor.preSend(message, mockk())
                }
            }
        }
    }

    Given("a STOMP CONNECT frame with an invalid JWT token") {
        every { jwtTokenProvider.validateToken("bad-token") } returns false

        When("preSend is called") {
            val accessor = StompHeaderAccessor.create(StompCommand.CONNECT)
            accessor.setLeaveMutable(true)
            accessor.addNativeHeader("Authorization", "Bearer bad-token")
            val message = MessageBuilder.createMessage(ByteArray(0), accessor.messageHeaders)

            Then("throws MessageDeliveryException") {
                shouldThrow<MessageDeliveryException> {
                    interceptor.preSend(message, mockk())
                }
            }
        }
    }

    Given("a STOMP SEND frame (non-CONNECT)") {
        When("preSend is called") {
            val accessor = StompHeaderAccessor.create(StompCommand.SEND)
            accessor.setLeaveMutable(true)
            accessor.destination = "/app/test"
            val message = MessageBuilder.createMessage(ByteArray(0), accessor.messageHeaders)

            val result = interceptor.preSend(message, mockk())

            Then("passes through without authentication") {
                result shouldNotBe null
            }
        }
    }
})
