package com.budgetbook.config

import com.budgetbook.auth.service.JwtTokenProvider
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import io.jsonwebtoken.Claims
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.nulls.shouldBeNull
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
    val coupleRepository = mockk<CoupleRepository>()
    val interceptor = WebSocketAuthInterceptor(jwtTokenProvider, coupleRepository)

    Given("a STOMP CONNECT frame with a valid JWT token") {
        val userId = UUID.randomUUID()
        val token = "valid-jwt-token"
        val claims = mockk<Claims>()

        every { jwtTokenProvider.parseAndValidateToken(token) } returns claims
        every { jwtTokenProvider.getUserIdFromClaims(claims) } returns userId

        When("preSend is called") {
            val accessor = StompHeaderAccessor.create(StompCommand.CONNECT)
            accessor.setLeaveMutable(true)
            accessor.addNativeHeader("Authorization", "Bearer $token")
            val message = MessageBuilder.createMessage(ByteArray(0), accessor.messageHeaders)

            val result = interceptor.preSend(message, mockk())

            Then("sets the principal with the userId") {
                val resultAccessor = StompHeaderAccessor.wrap(result!!)
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
        every { jwtTokenProvider.parseAndValidateToken("bad-token") } returns null

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

    Given("a STOMP SUBSCRIBE to a couple topic by an authorized member") {
        val userId = UUID.randomUUID()
        val coupleId = UUID.randomUUID()
        val couple = mockk<Couple>()
        every { couple.id } returns coupleId

        every { coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE) } returns couple

        When("preSend is called") {
            val accessor = StompHeaderAccessor.create(StompCommand.SUBSCRIBE)
            accessor.setLeaveMutable(true)
            accessor.destination = "/topic/couple/$coupleId"
            accessor.user = StompPrincipal(userId)
            val message = MessageBuilder.createMessage(ByteArray(0), accessor.messageHeaders)

            val result = interceptor.preSend(message, mockk())

            Then("allows the subscription") {
                result shouldNotBe null
            }
        }
    }

    Given("a STOMP SUBSCRIBE to a couple topic by a non-member") {
        val userId = UUID.randomUUID()
        val coupleId = UUID.randomUUID()

        every { coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE) } returns null

        When("preSend is called") {
            val accessor = StompHeaderAccessor.create(StompCommand.SUBSCRIBE)
            accessor.setLeaveMutable(true)
            accessor.destination = "/topic/couple/$coupleId"
            accessor.user = StompPrincipal(userId)
            val message = MessageBuilder.createMessage(ByteArray(0), accessor.messageHeaders)

            val result = interceptor.preSend(message, mockk())

            Then("blocks the subscription by returning null") {
                result.shouldBeNull()
            }
        }
    }

    Given("a STOMP SUBSCRIBE to a couple topic by a member of a different couple") {
        val userId = UUID.randomUUID()
        val userCoupleId = UUID.randomUUID()
        val targetCoupleId = UUID.randomUUID()
        val couple = mockk<Couple>()
        every { couple.id } returns userCoupleId

        every { coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE) } returns couple

        When("preSend is called") {
            val accessor = StompHeaderAccessor.create(StompCommand.SUBSCRIBE)
            accessor.setLeaveMutable(true)
            accessor.destination = "/topic/couple/$targetCoupleId"
            accessor.user = StompPrincipal(userId)
            val message = MessageBuilder.createMessage(ByteArray(0), accessor.messageHeaders)

            val result = interceptor.preSend(message, mockk())

            Then("blocks the subscription by returning null") {
                result.shouldBeNull()
            }
        }
    }

    Given("a STOMP SUBSCRIBE without authentication") {
        When("preSend is called") {
            val accessor = StompHeaderAccessor.create(StompCommand.SUBSCRIBE)
            accessor.setLeaveMutable(true)
            accessor.destination = "/topic/couple/${UUID.randomUUID()}"
            val message = MessageBuilder.createMessage(ByteArray(0), accessor.messageHeaders)

            Then("throws MessageDeliveryException") {
                shouldThrow<MessageDeliveryException> {
                    interceptor.preSend(message, mockk())
                }
            }
        }
    }
})
