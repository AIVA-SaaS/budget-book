package com.budgetbook.pocket.dto

import jakarta.validation.Valid
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class CreateTransferRequest(
    @field:NotNull
    val fromPocketId: UUID,

    @field:NotNull
    val toPocketId: UUID,

    @field:NotNull
    @field:Min(1)
    val amount: Long,

    @field:Size(max = 255)
    val description: String? = null,

    @field:NotNull
    val transferDate: LocalDate
)

data class PocketTransferResponse(
    val id: UUID,
    val fromPocket: PocketSummary,
    val toPocket: PocketSummary,
    val amount: Long,
    val description: String?,
    val transferDate: LocalDate,
    val authorId: UUID,
    val createdAt: Instant,
    val updatedAt: Instant
)

data class PocketSummary(
    val id: UUID,
    val name: String
)

data class DistributeRequest(
    @field:NotNull
    @field:Min(0)
    val totalAmount: Long,

    @field:NotNull
    @field:Valid
    val distributions: List<DistributionItem>
)

data class DistributionItem(
    @field:NotNull
    val pocketId: UUID,

    @field:NotNull
    @field:Min(0)
    val amount: Long
)

data class DistributeResponse(
    val distributions: List<DistributionResult>,
    val totalDistributed: Long
)

data class DistributionResult(
    val pocketId: UUID,
    val pocketName: String,
    val amount: Long
)
