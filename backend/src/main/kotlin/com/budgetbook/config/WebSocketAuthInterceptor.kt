package com.budgetbook.config

import com.budgetbook.auth.service.JwtTokenProvider
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
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
    private val jwtTokenProvider: JwtTokenProvider,
    private val coupleRepository: CoupleRepository
) : ChannelInterceptor {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun preSend(message: Message<*>, channel: MessageChannel): Message<*>? {
        val accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor::class.java)

        if (accessor != null && StompCommand.CONNECT == accessor.command) {
            val authHeader = accessor.getFirstNativeHeader("Authorization")
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                throw MessageDeliveryException("Missing or invalid Authorization header")
            }

            val token = authHeader.substring(7)
            val claims = jwtTokenProvider.parseAndValidateToken(token)
                ?: throw MessageDeliveryException("Invalid or expired JWT token")

            val userId = jwtTokenProvider.getUserIdFromClaims(claims)
            accessor.user = StompPrincipal(userId)
            log.debug("WebSocket CONNECT authenticated for userId={}", userId)
        }

        if (accessor != null && StompCommand.SUBSCRIBE == accessor.command) {
            val destination = accessor.destination
            val principal = accessor.user as? StompPrincipal

            if (principal == null) {
                throw MessageDeliveryException("Not authenticated")
            }

            // Extract coupleId from destination pattern /topic/couple/{coupleId}
            val coupleIdStr = destination?.let { COUPLE_TOPIC_REGEX.find(it)?.groupValues?.get(1) }
            if (coupleIdStr != null) {
                val coupleId = try {
                    UUID.fromString(coupleIdStr)
                } catch (e: IllegalArgumentException) {
                    throw MessageDeliveryException("Invalid coupleId in destination")
                }

                val couple = coupleRepository.findByUserIdAndStatus(principal.userId, CoupleStatus.ACTIVE)
                if (couple == null || couple.id != coupleId) {
                    log.warn("WebSocket SUBSCRIBE denied: userId={} is not a member of coupleId={}", principal.userId, coupleId)
                    return null
                }
                log.debug("WebSocket SUBSCRIBE authorized for userId={} to coupleId={}", principal.userId, coupleId)
            }
        }

        return message
    }

    companion object {
        private val COUPLE_TOPIC_REGEX = Regex("/topic/couple/([a-f0-9\\-]+)")
    }
}

data class StompPrincipal(val userId: UUID) : Principal {
    override fun getName(): String = userId.toString()
}
