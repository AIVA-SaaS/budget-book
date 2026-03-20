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

    @field:NotNull
    @field:Min(1)
    @field:Max(999_999_999)
    val amount: Long,

    @field:NotBlank
    @field:Size(max = 255)
    val description: String,

    val categoryId: UUID? = null,

    @field:NotNull
    val transactionDate: LocalDate,

    val memo: String? = null,

    val paymentMethodId: UUID? = null,

    val pocketId: UUID? = null,

    val visibility: String? = "SHARED"
)

data class UpdateTransactionRequest(
    @field:Min(1)
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
