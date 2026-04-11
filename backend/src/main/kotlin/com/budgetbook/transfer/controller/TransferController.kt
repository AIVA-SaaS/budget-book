package com.budgetbook.transfer.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.security.AuthUser
import com.budgetbook.transfer.dto.CreateTransferRequest
import com.budgetbook.transfer.dto.TransferResponse
import com.budgetbook.transfer.dto.UpdateTransferRequest
import com.budgetbook.transfer.service.TransferService
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
@RequestMapping("/api/v1/transfers")
class TransferController(
    private val transferService: TransferService
) {

    @RateLimit(maxRequests = 20, windowSeconds = 60)
    @PostMapping
    fun createTransfer(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateTransferRequest
    ): ResponseEntity<ApiResponse<TransferResponse>> {
        val result = transferService.createTransfer(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @GetMapping
    fun listTransfers(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<List<TransferResponse>> {
        return ApiResponse.ok(transferService.listTransfers(userId, year, month))
    }

    @GetMapping("/{id}")
    fun getTransfer(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<TransferResponse> {
        return ApiResponse.ok(transferService.getTransfer(userId, id))
    }

    @RateLimit(maxRequests = 20, windowSeconds = 60)
    @PutMapping("/{id}")
    fun updateTransfer(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateTransferRequest
    ): ApiResponse<TransferResponse> {
        return ApiResponse.ok(transferService.updateTransfer(userId, id, request))
    }

    @RateLimit(maxRequests = 20, windowSeconds = 60)
    @DeleteMapping("/{id}")
    fun deleteTransfer(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        transferService.deleteTransfer(userId, id)
        return ResponseEntity.noContent().build()
    }
}
