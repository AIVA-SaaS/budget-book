package com.budgetbook.recurring.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.recurring.dto.CreateRecurringTransactionRequest
import com.budgetbook.recurring.dto.RecurringTransactionResponse
import com.budgetbook.recurring.dto.UpdateRecurringTransactionRequest
import com.budgetbook.recurring.service.RecurringTransactionService
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
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/recurring-transactions")
class RecurringTransactionController(
    private val recurringTransactionService: RecurringTransactionService
) {

    @GetMapping
    fun listRecurringTransactions(
        authentication: Authentication
    ): ApiResponse<List<RecurringTransactionResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(recurringTransactionService.listRecurringTransactions(userId))
    }

    @PostMapping
    fun createRecurringTransaction(
        authentication: Authentication,
        @Valid @RequestBody request: CreateRecurringTransactionRequest
    ): ResponseEntity<ApiResponse<RecurringTransactionResponse>> {
        val userId = authentication.principal as UUID
        val result = recurringTransactionService.createRecurringTransaction(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/{id}")
    fun updateRecurringTransaction(
        authentication: Authentication,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateRecurringTransactionRequest
    ): ApiResponse<RecurringTransactionResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(recurringTransactionService.updateRecurringTransaction(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteRecurringTransaction(
        authentication: Authentication,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        val userId = authentication.principal as UUID
        recurringTransactionService.deleteRecurringTransaction(userId, id)
        return ResponseEntity.noContent().build()
    }
}
