package com.budgetbook.transaction.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.transaction.dto.CreateTransactionRequest
import com.budgetbook.transaction.dto.CsvImportResponse
import com.budgetbook.transaction.dto.PageResponse
import com.budgetbook.transaction.dto.TransactionResponse
import com.budgetbook.transaction.dto.UpdateTransactionRequest
import com.budgetbook.transaction.service.TransactionExportService
import com.budgetbook.transaction.service.TransactionImportService
import com.budgetbook.transaction.service.TransactionService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
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
        @RequestParam(required = false) year: Int?,
        @RequestParam(required = false) month: Int?,
        @RequestParam(required = false) type: String?,
        @RequestParam(required = false) categoryId: UUID?,
        @RequestParam(required = false) keyword: String?,
        @RequestParam(required = false) paymentMethodId: UUID?,
        @RequestParam(required = false) pocketId: UUID?,
        @RequestParam(required = false) amountMin: Long?,
        @RequestParam(required = false) amountMax: Long?,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): ApiResponse<PageResponse<TransactionResponse>> {
        return ApiResponse.ok(transactionService.listTransactions(
            userId, year, month, type, categoryId,
            keyword, paymentMethodId, pocketId, amountMin, amountMax,
            page, size
        ))
    }

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

    @PutMapping("/{id}")
    fun updateTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateTransactionRequest
    ): ApiResponse<TransactionResponse> {
        return ApiResponse.ok(transactionService.updateTransaction(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteTransaction(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        transactionService.deleteTransaction(userId, id)
        return ResponseEntity.noContent().build()
    }

    @GetMapping("/suggestions")
    fun getSuggestions(
        @AuthUser userId: UUID,
        @RequestParam q: String,
        @RequestParam(defaultValue = "10") limit: Int
    ): ApiResponse<List<String>> {
        return ApiResponse.ok(transactionService.getSuggestions(userId, q, limit))
    }

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
