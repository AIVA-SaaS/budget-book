package com.budgetbook.transaction.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.security.AuthUser
import com.budgetbook.transaction.dto.CreateTransactionRequest
import com.budgetbook.transaction.dto.CsvImportResponse
import com.budgetbook.transaction.dto.PageResponse
import com.budgetbook.transaction.dto.SettlementTransactionsResponse
import com.budgetbook.transaction.dto.TransactionResponse
import com.budgetbook.transaction.dto.UpdateTransactionRequest
import com.budgetbook.transaction.service.TransactionExportService
import com.budgetbook.transaction.service.TransactionImportService
import com.budgetbook.transaction.service.TransactionService
import jakarta.validation.Valid
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.ModelAttribute
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.multipart.MultipartFile
import java.util.UUID

@RestController
@RequestMapping("/api/v1/transactions")
class TransactionController(
    private val transactionService: TransactionService,
    private val transactionExportService: TransactionExportService,
    private val transactionImportService: TransactionImportService
) {

    @GetMapping
    fun listTransactions(
        @AuthUser userId: UUID,
        @ModelAttribute filter: CommonFilterParams,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): ApiResponse<PageResponse<TransactionResponse>> {
        return ApiResponse.ok(transactionService.listTransactions(
            userId = userId,
            year = filter.year,
            month = filter.month,
            type = filter.type,
            categoryId = filter.categoryId,
            keyword = filter.keyword,
            paymentMethodId = filter.paymentMethodId,
            pocketId = filter.pocketId,
            amountMin = filter.amountMin,
            amountMax = filter.amountMax,
            dateFrom = filter.dateFrom,
            dateTo = filter.dateTo,
            visibility = filter.visibility,
            page = page,
            size = size,
            // PR-C2 다중/그룹 필터 (Spring `categoryIds=a&categoryIds=b` 자동 바인딩)
            categoryIds = filter.categoryIds,
            categoryGroupIds = filter.categoryGroupIds,
            paymentMethodIds = filter.paymentMethodIds,
            pocketIds = filter.pocketIds,
            // Phase 22 T10: 다중 타입 필터. `transactionTypes=EXPENSE&transactionTypes=INCOME`.
            transactionTypes = filter.transactionTypes,
            // V61 (2026-05-06) — 확인/입력 필요만 보기.
            needsReviewOnly = filter.needsReviewOnly
        ))
    }

    @RateLimit(maxRequests = 30, windowSeconds = 60)
    @PostMapping
    fun createTransaction(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateTransactionRequest
    ): ResponseEntity<ApiResponse<TransactionResponse>> {
        val result = transactionService.createTransaction(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @GetMapping("/{id}")
    fun getTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<TransactionResponse> {
        return ApiResponse.ok(transactionService.getTransaction(userId, id))
    }

    @RateLimit(maxRequests = 30, windowSeconds = 60)
    @PutMapping("/{id}")
    fun updateTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateTransactionRequest
    ): ApiResponse<TransactionResponse> {
        return ApiResponse.ok(transactionService.updateTransaction(userId, id, request))
    }

    @RateLimit(maxRequests = 30, windowSeconds = 60)
    @DeleteMapping("/{id}")
    fun deleteTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        transactionService.deleteTransaction(userId, id)
        return ResponseEntity.noContent().build()
    }

    @GetMapping("/settlement")
    fun getSettlementTransactions(
        @AuthUser userId: UUID,
        @RequestParam paymentMethodId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<SettlementTransactionsResponse> {
        return ApiResponse.ok(transactionService.getSettlementTransactions(userId, paymentMethodId, year, month))
    }

    @GetMapping("/suggestions")
    fun getSuggestions(
        @AuthUser userId: UUID,
        @RequestParam q: String,
        @RequestParam(defaultValue = "5") limit: Int
    ): ApiResponse<List<com.budgetbook.transaction.dto.SuggestionResponse>> {
        return ApiResponse.ok(transactionService.getSuggestions(userId, q, limit))
    }

    @RateLimit(maxRequests = 5, windowSeconds = 60)
    @PostMapping("/import/csv")
    fun importCsv(
        @AuthUser userId: UUID,
        @RequestParam("file") file: MultipartFile
    ): ApiResponse<CsvImportResponse> {
        return ApiResponse.ok(transactionImportService.importCsv(userId, file))
    }

    @GetMapping("/export/csv")
    fun exportCsv(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int,
        @RequestParam(required = false) type: String?,
        @RequestParam(required = false) categoryId: UUID?
    ): ResponseEntity<ByteArray> {
        val csv = transactionExportService.exportCsv(userId, year, month, type, categoryId)
        val bytes = csv.toByteArray(Charsets.UTF_8)
        val filename = "transactions_${year}_${String.format("%02d", month)}.csv"

        return ResponseEntity.ok()
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"$filename\"")
            .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
            .contentLength(bytes.size.toLong())
            .body(bytes)
    }
}
