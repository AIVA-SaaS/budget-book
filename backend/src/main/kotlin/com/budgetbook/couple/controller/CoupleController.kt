package com.budgetbook.couple.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.ratelimit.RateLimitKeyType
import com.budgetbook.common.security.AuthUser
import com.budgetbook.couple.dto.CoupleResponse
import com.budgetbook.couple.dto.InvitationResponse
import com.budgetbook.couple.dto.InvitationStatusResponse
import com.budgetbook.couple.service.CoupleService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
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
    private val coupleService: CoupleService
) {

    @RateLimit(maxRequests = 10, windowSeconds = 3600)
    @PostMapping("/invitations")
    fun createInvitation(
        @AuthUser userId: UUID
    ): ResponseEntity<ApiResponse<InvitationResponse>> {
        val result = coupleService.createInvitation(userId)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @GetMapping("/invitations/me")
    fun getMyInvitation(@AuthUser userId: UUID): ApiResponse<InvitationStatusResponse> {
        return ApiResponse.ok(coupleService.getMyInvitation(userId))
    }

    @RateLimit(maxRequests = 5, windowSeconds = 3600, keyType = RateLimitKeyType.IP)
    @PostMapping("/invitations/{code}/accept")
    fun acceptInvitation(
        @AuthUser userId: UUID,
        @PathVariable code: String
    ): ApiResponse<CoupleResponse> {
        return ApiResponse.ok(coupleService.acceptInvitation(userId, code))
    }

    @GetMapping("/me")
    fun getMyCouple(@AuthUser userId: UUID): ApiResponse<CoupleResponse> {
        return ApiResponse.ok(coupleService.getMyCouple(userId))
    }

    @DeleteMapping("/me")
    fun dissolveCouple(@AuthUser userId: UUID): ResponseEntity<Void> {
        coupleService.dissolveCouple(userId)
        return ResponseEntity.noContent().build()
    }
}
