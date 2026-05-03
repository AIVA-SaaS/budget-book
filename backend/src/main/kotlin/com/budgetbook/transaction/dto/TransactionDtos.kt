package com.budgetbook.transaction.dto

import com.budgetbook.common.dto.PatchValue
import com.budgetbook.common.dto.StringPatchValueDeserializer
import com.budgetbook.common.dto.UUIDPatchValueDeserializer
import com.budgetbook.couple.dto.UserSummary
import com.fasterxml.jackson.databind.annotation.JsonDeserialize
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class TransactionResponse(
    val id: UUID,
    val coupleId: UUID,
    val author: UserSummary,
    val category: CategorySummary?,
    val type: String,
    val amount: Long,
    val description: String,
    val memo: String?,
    val transactionDate: LocalDate,
    val paymentMethodId: UUID? = null,
    val paymentMethodName: String? = null,
    val paymentMethodType: String? = null,
    val settlementDate: String? = null,
    val pocketId: UUID? = null,
    val pocketName: String? = null,
    val visibility: String = "SHARED",
    val ownerId: UUID? = null,
    val createdAt: Instant,
    val updatedAt: Instant
)

data class CategorySummary(
    val id: UUID,
    val name: String,
    val type: String,
    val icon: String?,
    val color: String?,
    val groupId: UUID? = null,
    val groupName: String? = null
)

data class CreateTransactionRequest(
    @field:NotBlank
    val type: String,

    // Phase 22 T11: @Min(0) 제거. ADJUSTMENT 는 잔액 하향 조정 시 음수 필요.
    // 부호 검증은 TransactionService 에서 type 별로 수행한다.
    @field:NotNull
    @field:Min(-999_999_999)
    @field:Max(999_999_999)
    val amount: Long,

    @field:NotBlank
    @field:Size(max = 255)
    val description: String,

    val categoryId: UUID? = null,

    @field:NotNull
    val transactionDate: LocalDate,

    @field:Size(max = 1000)
    val memo: String? = null,

    val paymentMethodId: UUID? = null,

    val pocketId: UUID? = null,

    val visibility: String? = "SHARED"
)

data class UpdateTransactionRequest(
    // Phase 22 T11: @Min(0) 제거. ADJUSTMENT 는 잔액 하향 조정 시 음수 필요.
    // 부호 검증은 TransactionService 에서 type 별로 수행한다.
    @field:Min(-999_999_999)
    @field:Max(999_999_999)
    val amount: Long? = null,

    @field:Size(max = 255)
    val description: String? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val categoryId: PatchValue<UUID>? = null,

    val transactionDate: LocalDate? = null,

    @JsonDeserialize(using = StringPatchValueDeserializer::class)
    val memo: PatchValue<String>? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val paymentMethodId: PatchValue<UUID>? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val pocketId: PatchValue<UUID>? = null,

    val visibility: String? = null
)

data class PageResponse<T>(
    val content: List<T>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int,
    val first: Boolean,
    val last: Boolean
)

data class CsvImportResponse(
    val imported: Int,
    val skipped: Int,
    val errors: List<CsvImportError>
)

data class CsvImportError(
    val row: Int,
    val reason: String
)

data class SuggestionResponse(
    val description: String,
    val patterns: List<SuggestionPattern>
)

data class SuggestionPattern(
    val categoryId: UUID? = null,
    val categoryName: String? = null,
    // 회차 12 follow-up (2026-05-04) — 카테고리 표시 통일.
    // FE 가 "그룹 > 하위" 형식으로 표시할 때 group lookup 부하 없이 사용.
    val categoryGroupName: String? = null,
    val categoryIcon: String? = null,
    val categoryColor: String? = null,
    val paymentMethodId: UUID? = null,
    val paymentMethodName: String? = null,
    val count: Long
)

data class SettlementTransactionsResponse(
    val totalAmount: Long,
    val transactionCount: Int,
    val transactions: List<SettlementTransactionItem>
)

data class SettlementTransactionItem(
    val id: UUID,
    val transactionDate: LocalDate,
    val settlementDate: LocalDate?,
    val description: String,
    val amount: Long,
    val categoryName: String?,
    val categoryIcon: String?,
    val type: String = "TRANSACTION" // TRANSACTION or TRANSFER
)
