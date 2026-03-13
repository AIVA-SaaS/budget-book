package com.budgetbook.couple.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.exception.TooManyRequestsException
import com.budgetbook.common.ratelimit.RateLimiter
import com.budgetbook.couple.dto.CoupleResponse
import com.budgetbook.couple.dto.InvitationResponse
import com.budgetbook.couple.service.CoupleService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/couples")
class CoupleController(
    private val coupleService: CoupleService,
    private val rateLimiter: RateLimiter
) {

    companion object {
        private const val INVITE_ACCEPT_MAX_REQUESTS = 5
        private const val INVITE_ACCEPT_WINDOW_MILLIS = 3_600_000L // 1 hour
    }

    @PostMapping("/invitations")
    fun createInvitation(authentication: Authentication): ResponseEntity<ApiResponse<InvitationResponse>> {
        val userId = authentication.principal as UUID
        val result = coupleService.createInvitation(userId)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PostMapping("/invitations/{code}/accept")
    fun acceptInvitation(
        authentication: Authentication,
        @PathVariable code: String,
        request: HttpServletRequest
    ): ApiResponse<CoupleResponse> {
        val clientIp = request.getHeader("X-Forwarded-For")?.split(",")?.firstOrNull()?.trim()
            ?: request.remoteAddr
        val rateLimitKey = "invite-accept:$clientIp"

        if (!rateLimiter.tryAcquire(rateLimitKey, INVITE_ACCEPT_MAX_REQUESTS, INVITE_ACCEPT_WINDOW_MILLIS)) {
            throw TooManyRequestsException(
                "RATE_LIMIT_EXCEEDED",
                "Too many invitation accept attempts. Please try again later."
            )
        }

        val userId = authentication.principal as UUID
        return ApiResponse.ok(coupleService.acceptInvitation(userId, code))
    }

    @GetMapping("/me")
    fun getMyCouple(authentication: Authentication): ApiResponse<CoupleResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(coupleService.getMyCouple(userId))
    }

    @DeleteMapping("/me")
    fun dissolveCouple(authentication: Authentication): ResponseEntity<Void> {
        val userId = authentication.principal as UUID
        coupleService.dissolveCouple(userId)
        return ResponseEntity.noContent().build()
    }
}
