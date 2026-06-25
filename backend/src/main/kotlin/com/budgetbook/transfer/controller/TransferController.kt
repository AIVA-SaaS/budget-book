package com.budgetbook.transfer.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.security.AuthUser
import com.budgetbook.transfer.dto.CreateCardSettlementRequest
import com.budgetbook.transfer.dto.CreateTransferRequest
import com.budgetbook.transfer.dto.TransferResponse
import com.budgetbook.transfer.dto.UpdateCardSettlementRequest
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

    /**
     * 카드 결제 처리 전용 엔드포인트.
     * - Transfer 생성 (is_card_settlement=true, 통계 이중 계산 방지)
     * - 선택된 거래들의 paid_at 업데이트 (미결제 목록에서 제외)
     */
    @RateLimit(maxRequests = 20, windowSeconds = 60)
    @PostMapping("/card-settlement")
    fun createCardSettlement(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateCardSettlementRequest
    ): ResponseEntity<ApiResponse<TransferResponse>> {
        val result = transferService.createCardSettlement(
            userId = userId,
            sourcePaymentMethodId = request.sourcePaymentMethodId,
            destinationPaymentMethodId = request.destinationPaymentMethodId,
            amount = request.amount,
            transferDate = request.transferDate,
            description = request.description,
            transactionIds = request.transactionIds
        )
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    /**
     * 카드 정산 편집 전용 엔드포인트 (V63).
     * - 기존 연결 거래의 paid_at 복원 → 이체 필드 갱신 → 새 선택 거래 마킹·링크 저장.
     * - 미결제 합계가 새 선택 기준으로 재계산된다.
     */
    @RateLimit(maxRequests = 20, windowSeconds = 60)
    @PutMapping("/card-settlement/{transferId}")
    fun updateCardSettlement(
        @AuthUser userId: UUID,
        @PathVariable transferId: UUID,
        @Valid @RequestBody request: UpdateCardSettlementRequest
    ): ApiResponse<TransferResponse> {
        val result = transferService.updateCardSettlement(
            userId = userId,
            transferId = transferId,
            sourcePaymentMethodId = request.sourcePaymentMethodId,
            destinationPaymentMethodId = request.destinationPaymentMethodId,
            amount = request.amount,
            transferDate = request.transferDate,
            description = request.description,
            transactionIds = request.transactionIds
        )
        return ApiResponse.ok(result)
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
