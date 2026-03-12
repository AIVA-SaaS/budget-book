package com.budgetbook.config

import com.budgetbook.auth.service.JwtTokenProvider
import org.slf4j.LoggerFactory
import org.springframework.messaging.Message
import org.springframework.messaging.MessageChannel
import org.springframework.messaging.MessageDeliveryException
import org.springframework.messaging.simp.stomp.StompCommand
import org.springframework.messaging.simp.stomp.StompHeaderAccessor
import org.springframework.messaging.support.ChannelInterceptor
import org.springframework.messaging.support.MessageHeaderAccessor
import org.springframework.stereotype.Component
import java.security.Principal
import java.util.UUID

@Component
class WebSocketAuthInterceptor(
    private val jwtTokenProvider: JwtTokenProvider
) : ChannelInterceptor {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun preSend(message: Message<*>, channel: MessageChannel): Message<*> {
        val accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor::class.java)

        if (accessor != null && StompCommand.CONNECT == accessor.command) {
            val authHeader = accessor.getFirstNativeHeader("Authorization")
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                throw MessageDeliveryException("Missing or invalid Authorization header")
            }

            val token = authHeader.substring(7)
            if (!jwtTokenProvider.validateToken(token)) {
                throw MessageDeliveryException("Invalid or expired JWT token")
            }

            val userId = jwtTokenProvider.getUserIdFromToken(token)
            accessor.user = StompPrincipal(userId)
            log.debug("WebSocket CONNECT authenticated for userId={}", userId)
        }

        return message
    }
}

data class StompPrincipal(val userId: UUID) : Principal {
    override fun getName(): String = userId.toString()
}
