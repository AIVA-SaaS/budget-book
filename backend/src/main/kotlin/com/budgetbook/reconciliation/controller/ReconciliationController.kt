package com.budgetbook.reconciliation.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.security.AuthUser
import com.budgetbook.reconciliation.dto.CreateReconciliationRequest
import com.budgetbook.reconciliation.dto.ReconciliationDetailResponse
import com.budgetbook.reconciliation.dto.ReconciliationResponse
import com.budgetbook.reconciliation.dto.ReconciliationSummaryResponse
import com.budgetbook.reconciliation.dto.UpdateReconciliationRequest
import com.budgetbook.reconciliation.service.ReconciliationService
import jakarta.validation.Valid
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

/**
 * 정산 스냅샷 API. 계약: `docs/api-spec.md § Reconciliations (정산 스냅샷)`.
 */
@RestController
@RequestMapping("/api/v1/reconciliations")
class ReconciliationController(
    private val reconciliationService: ReconciliationService
) {

    @GetMapping
    fun listReconciliations(
        @AuthUser userId: UUID,
        @RequestParam @Min(2000) @Max(2100) year: Int,
        @RequestParam @Min(1) @Max(12) month: Int
    ): ApiResponse<List<ReconciliationResponse>> {
        return ApiResponse.ok(reconciliationService.listReconciliations(userId, year, month))
    }

    /**
     * 월말 누락 점검 요약. `/{id}` 보다 **먼저** 매핑되어야 한다
     * (`summary` 가 UUID path variable 로 해석되지 않도록 — Spring 은 더 구체적인 패턴을
     * 우선하지만 의도를 명시적으로 남긴다).
     */
    @GetMapping("/summary")
    fun getSummary(
        @AuthUser userId: UUID,
        @RequestParam @Min(2000) @Max(2100) year: Int,
        @RequestParam @Min(1) @Max(12) month: Int
    ): ApiResponse<ReconciliationSummaryResponse> {
        return ApiResponse.ok(reconciliationService.getSummary(userId, year, month))
    }

    @GetMapping("/{id}")
    fun getReconciliation(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<ReconciliationDetailResponse> {
        return ApiResponse.ok(reconciliationService.getReconciliation(userId, id))
    }

    @RateLimit(maxRequests = 30, windowSeconds = 60)
    @PostMapping
    fun createReconciliation(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateReconciliationRequest
    ): ResponseEntity<ApiResponse<ReconciliationDetailResponse>> {
        val result = reconciliationService.createReconciliation(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @RateLimit(maxRequests = 30, windowSeconds = 60)
    @PatchMapping("/{id}")
    fun updateReconciliation(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateReconciliationRequest
    ): ApiResponse<ReconciliationDetailResponse> {
        return ApiResponse.ok(reconciliationService.updateReconciliation(userId, id, request))
    }

    @RateLimit(maxRequests = 30, windowSeconds = 60)
    @DeleteMapping("/{id}")
    fun deleteReconciliation(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        reconciliationService.deleteReconciliation(userId, id)
        return ResponseEntity.noContent().build()
    }
}
