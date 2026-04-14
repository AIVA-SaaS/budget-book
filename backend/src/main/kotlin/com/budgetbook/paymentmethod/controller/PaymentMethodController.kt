package com.budgetbook.paymentmethod.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.paymentmethod.dto.CardPendingResponse
import com.budgetbook.paymentmethod.dto.CardSettlementSummaryResponse
import com.budgetbook.paymentmethod.dto.CreatePaymentMethodRequest
import com.budgetbook.paymentmethod.dto.PaymentMethodResponse
import com.budgetbook.paymentmethod.dto.ReorderPaymentMethodRequest
import com.budgetbook.paymentmethod.dto.UpdatePaymentMethodRequest
import com.budgetbook.paymentmethod.service.PaymentMethodService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/payment-methods")
class PaymentMethodController(
    private val paymentMethodService: PaymentMethodService
) {

    @GetMapping
    fun listPaymentMethods(@AuthUser userId: UUID): ApiResponse<List<PaymentMethodResponse>> {
        return ApiResponse.ok(paymentMethodService.listPaymentMethods(userId))
    }

    @PostMapping
    fun createPaymentMethod(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreatePaymentMethodRequest
    ): ResponseEntity<ApiResponse<PaymentMethodResponse>> {
        val result = paymentMethodService.createPaymentMethod(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/reorder")
    fun reorderPaymentMethods(
        @AuthUser userId: UUID,
        @RequestBody request: ReorderPaymentMethodRequest
    ): ApiResponse<Unit> {
        paymentMethodService.reorderPaymentMethods(userId, request)
        return ApiResponse.ok()
    }

    @PutMapping("/{id}")
    fun updatePaymentMethod(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdatePaymentMethodRequest
    ): ApiResponse<PaymentMethodResponse> {
        return ApiResponse.ok(paymentMethodService.updatePaymentMethod(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deletePaymentMethod(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        paymentMethodService.deletePaymentMethod(userId, id)
        return ResponseEntity.noContent().build()
    }

    @GetMapping("/card-settlement-summary")
    fun getCardSettlementSummary(
        @AuthUser userId: UUID,
        @RequestParam(required = false) year: Int?,
        @RequestParam(required = false) month: Int?
    ): ApiResponse<CardSettlementSummaryResponse> {
        return ApiResponse.ok(paymentMethodService.getCardSettlementSummary(userId, year, month))
    }

    @GetMapping("/card-pending")
    fun getCardPendingSummary(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<List<CardPendingResponse>> {
        return ApiResponse.ok(paymentMethodService.getCardPendingSummary(userId, year, month))
    }
}
