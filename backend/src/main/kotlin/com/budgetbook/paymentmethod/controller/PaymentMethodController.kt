package com.budgetbook.paymentmethod.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.paymentmethod.dto.CardPendingResponse
import com.budgetbook.paymentmethod.dto.CreatePaymentMethodRequest
import com.budgetbook.paymentmethod.dto.PaymentMethodResponse
import com.budgetbook.paymentmethod.dto.UpdatePaymentMethodRequest
import com.budgetbook.paymentmethod.service.PaymentMethodService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
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
    fun listPaymentMethods(authentication: Authentication): ApiResponse<List<PaymentMethodResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(paymentMethodService.listPaymentMethods(userId))
    }

    @PostMapping
    fun createPaymentMethod(
        authentication: Authentication,
        @Valid @RequestBody request: CreatePaymentMethodRequest
    ): ResponseEntity<ApiResponse<PaymentMethodResponse>> {
        val userId = authentication.principal as UUID
        val result = paymentMethodService.createPaymentMethod(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/{id}")
    fun updatePaymentMethod(
        authentication: Authentication,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdatePaymentMethodRequest
    ): ApiResponse<PaymentMethodResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(paymentMethodService.updatePaymentMethod(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deletePaymentMethod(
        authentication: Authentication,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        val userId = authentication.principal as UUID
        paymentMethodService.deletePaymentMethod(userId, id)
        return ResponseEntity.noContent().build()
    }

    @GetMapping("/card-pending")
    fun getCardPendingSummary(
        authentication: Authentication,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<List<CardPendingResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(paymentMethodService.getCardPendingSummary(userId, year, month))
    }
}
