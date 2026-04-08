package com.budgetbook.spendingplan.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.spendingplan.domain.SpendingPlanStatus
import com.budgetbook.spendingplan.dto.AssignSpendingPlanRequest
import com.budgetbook.spendingplan.dto.CompleteSpendingPlanRequest
import com.budgetbook.spendingplan.dto.CompleteWithTransactionRequest
import com.budgetbook.spendingplan.dto.CreateSpendingPlanRequest
import com.budgetbook.spendingplan.dto.LinkTransactionRequest
import com.budgetbook.spendingplan.dto.SpendingPlanListResponse
import com.budgetbook.spendingplan.dto.SpendingPlanResponse
import com.budgetbook.spendingplan.dto.SpendingPlanSuggestion
import com.budgetbook.spendingplan.dto.StatusHistoryResponse
import com.budgetbook.spendingplan.dto.UpdateSpendingPlanRequest
import com.budgetbook.spendingplan.service.SpendingPlanService
import jakarta.validation.Valid
import org.springframework.format.annotation.DateTimeFormat
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.time.LocalDate
import java.util.UUID

@RestController
@RequestMapping("/api/v1/spending-plans")
class SpendingPlanController(
    private val spendingPlanService: SpendingPlanService
) {

    @GetMapping
    fun listPlans(
        @AuthUser userId: UUID,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) startDate: LocalDate?,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) endDate: LocalDate?,
        @RequestParam(required = false) status: SpendingPlanStatus?
    ): ApiResponse<SpendingPlanListResponse> {
        return ApiResponse.ok(spendingPlanService.listPlans(userId, startDate, endDate, status))
    }

    @PostMapping
    fun createPlan(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateSpendingPlanRequest
    ): ResponseEntity<ApiResponse<SpendingPlanResponse>> {
        val result = spendingPlanService.createPlan(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    // Static path mappings BEFORE /{id} to avoid path conflict
    @GetMapping("/wishlist")
    fun getWishlist(
        @AuthUser userId: UUID
    ): ApiResponse<List<SpendingPlanResponse>> {
        return ApiResponse.ok(spendingPlanService.getWishlist(userId))
    }

    @GetMapping("/suggestions")
    fun getSuggestions(
        @AuthUser userId: UUID,
        @RequestParam(required = false) categoryId: UUID?,
        @RequestParam amount: Long,
        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) date: LocalDate
    ): ApiResponse<List<SpendingPlanSuggestion>> {
        return ApiResponse.ok(spendingPlanService.getSuggestions(userId, categoryId, amount, date))
    }

    // Dynamic path mappings with /{id}
    @PutMapping("/{id}")
    fun updatePlan(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateSpendingPlanRequest
    ): ApiResponse<SpendingPlanResponse> {
        return ApiResponse.ok(spendingPlanService.updatePlan(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deletePlan(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<Unit> {
        spendingPlanService.deletePlan(userId, id)
        return ApiResponse.ok()
    }

    @PatchMapping("/{id}/complete")
    fun completePlan(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @RequestBody(required = false) request: CompleteSpendingPlanRequest?
    ): ApiResponse<SpendingPlanResponse> {
        return ApiResponse.ok(
            spendingPlanService.completePlan(userId, id, request ?: CompleteSpendingPlanRequest())
        )
    }

    @PatchMapping("/{id}/skip")
    fun skipPlan(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<SpendingPlanResponse> {
        return ApiResponse.ok(spendingPlanService.skipPlan(userId, id))
    }

    @PatchMapping("/{id}/assign")
    fun assignPlan(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @RequestBody request: AssignSpendingPlanRequest
    ): ApiResponse<SpendingPlanResponse> {
        return ApiResponse.ok(spendingPlanService.assignPlan(userId, id, request))
    }

    @PatchMapping("/{id}/complete-with-transaction")
    fun completeWithTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @RequestBody request: CompleteWithTransactionRequest
    ): ApiResponse<SpendingPlanResponse> {
        return ApiResponse.ok(spendingPlanService.completeWithTransaction(userId, id, request))
    }

    @PutMapping("/{id}/link-transaction")
    fun linkTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @RequestBody request: LinkTransactionRequest
    ): ApiResponse<SpendingPlanResponse> {
        return ApiResponse.ok(spendingPlanService.linkTransaction(userId, id, request.transactionId))
    }

    @DeleteMapping("/{id}/link-transaction")
    fun unlinkTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<SpendingPlanResponse> {
        return ApiResponse.ok(spendingPlanService.unlinkTransaction(userId, id))
    }

    @GetMapping("/{id}/history")
    fun getStatusHistory(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<List<StatusHistoryResponse>> {
        return ApiResponse.ok(spendingPlanService.getStatusHistory(userId, id))
    }
}
