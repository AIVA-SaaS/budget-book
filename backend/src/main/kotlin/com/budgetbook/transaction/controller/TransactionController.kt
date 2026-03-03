package com.budgetbook.transaction.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.transaction.dto.CreateTransactionRequest
import com.budgetbook.transaction.dto.PageResponse
import com.budgetbook.transaction.dto.TransactionResponse
import com.budgetbook.transaction.dto.UpdateTransactionRequest
import com.budgetbook.transaction.service.TransactionService
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
@RequestMapping("/api/v1/transactions")
class TransactionController(
    private val transactionService: TransactionService
) {

    @GetMapping
    fun listTransactions(
        authentication: Authentication,
        @RequestParam(required = false) year: Int?,
        @RequestParam(required = false) month: Int?,
        @RequestParam(required = false) type: String?,
        @RequestParam(required = false) categoryId: UUID?,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): ApiResponse<PageResponse<TransactionResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(transactionService.listTransactions(userId, year, month, type, categoryId, page, size))
    }

    @PostMapping
    fun createTransaction(
        authentication: Authentication,
        @Valid @RequestBody request: CreateTransactionRequest
    ): ResponseEntity<ApiResponse<TransactionResponse>> {
        val userId = authentication.principal as UUID
        val result = transactionService.createTransaction(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @GetMapping("/{id}")
    fun getTransaction(
        authentication: Authentication,
        @PathVariable id: UUID
    ): ApiResponse<TransactionResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(transactionService.getTransaction(userId, id))
    }

    @PutMapping("/{id}")
    fun updateTransaction(
        authentication: Authentication,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateTransactionRequest
    ): ApiResponse<TransactionResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(transactionService.updateTransaction(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteTransaction(
        authentication: Authentication,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        val userId = authentication.principal as UUID
        transactionService.deleteTransaction(userId, id)
        return ResponseEntity.noContent().build()
    }
}
