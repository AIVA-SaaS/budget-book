package com.budgetbook.recurring.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.security.AuthUser
import com.budgetbook.recurring.dto.CreateRecurringTransactionRequest
import com.budgetbook.recurring.dto.RecurringTransactionResponse
import com.budgetbook.recurring.dto.UpdateRecurringTransactionRequest
import com.budgetbook.recurring.service.RecurringTransactionService
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
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/recurring-transactions")
class RecurringTransactionController(
    private val recurringTransactionService: RecurringTransactionService
) {

    @GetMapping
    fun listRecurringTransactions(@AuthUser userId: UUID): ApiResponse<List<RecurringTransactionResponse>> {
        return ApiResponse.ok(recurringTransactionService.listRecurringTransactions(userId))
    }

    @RateLimit(maxRequests = 10, windowSeconds = 60)
    @PostMapping
    fun createRecurringTransaction(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateRecurringTransactionRequest
    ): ResponseEntity<ApiResponse<RecurringTransactionResponse>> {
        val result = recurringTransactionService.createRecurringTransaction(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @RateLimit(maxRequests = 10, windowSeconds = 60)
    @PutMapping("/{id}")
    fun updateRecurringTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateRecurringTransactionRequest
    ): ApiResponse<RecurringTransactionResponse> {
        return ApiResponse.ok(recurringTransactionService.updateRecurringTransaction(userId, id, request))
    }

    @RateLimit(maxRequests = 10, windowSeconds = 60)
    @DeleteMapping("/{id}")
    fun deleteRecurringTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        recurringTransactionService.deleteRecurringTransaction(userId, id)
        return ResponseEntity.noContent().build()
    }
}
