package com.budgetbook.pocket.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.pocket.dto.CreateTransferRequest
import com.budgetbook.pocket.dto.DistributeRequest
import com.budgetbook.pocket.dto.DistributeResponse
import com.budgetbook.pocket.dto.PocketTransferResponse
import com.budgetbook.pocket.service.PocketTransferService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
class PocketTransferController(
    private val pocketTransferService: PocketTransferService
) {

    @GetMapping("/api/v1/pocket-transfers")
    fun listTransfers(@AuthUser userId: UUID): ApiResponse<List<PocketTransferResponse>> {
        return ApiResponse.ok(pocketTransferService.getTransfers(userId))
    }

    @PostMapping("/api/v1/pocket-transfers")
    fun createTransfer(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateTransferRequest
    ): ResponseEntity<ApiResponse<PocketTransferResponse>> {
        val result = pocketTransferService.createTransfer(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PostMapping("/api/v1/pockets/distribute")
    fun distribute(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: DistributeRequest
    ): ApiResponse<DistributeResponse> {
        return ApiResponse.ok(pocketTransferService.distribute(userId, request))
    }
}
