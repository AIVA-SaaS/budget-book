package com.budgetbook.pocket.dto

import jakarta.validation.Valid
import jakarta.validation.constraints.DecimalMax
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotEmpty
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class CreatePocketRequest(
    @field:NotBlank
    @field:Size(max = 50)
    val name: String,

    @field:NotBlank
    val type: String,

    @field:NotNull
    @field:Min(0)
    @field:Max(999_999_999)
    val allocatedAmount: Long,

    val icon: String? = null,

    val color: String? = null,

    @field:Min(0)
    @field:Max(999_999_999)
    val goalAmount: Long? = null,

    val targetDate: LocalDate? = null
)

data class UpdatePocketRequest(
    @field:Size(max = 50)
    val name: String? = null,

    @field:Min(0)
    @field:Max(999_999_999)
    val allocatedAmount: Long? = null,

    val icon: String? = null,

    val color: String? = null,

    val displayOrder: Int? = null,

    @field:Min(0)
    @field:Max(999_999_999)
    val goalAmount: Long? = null,

    val targetDate: LocalDate? = null
)

data class PocketResponse(
    val id: UUID,
    val name: String,
    val type: String,
    val allocatedAmount: Long,
    val balance: Long,
    val icon: String?,
    val color: String?,
    val displayOrder: Int,
    val isActive: Boolean,
    val goalAmount: Long?,
    val targetDate: LocalDate?,
    val createdAt: Instant,
    val updatedAt: Instant
)

// Distribution Ratio DTOs

data class RatioEntry(
    @field:NotNull
    val pocketId: UUID,

    @field:NotNull
    @field:DecimalMin("0.00")
    @field:DecimalMax("100.00")
    val ratio: BigDecimal
)

data class SaveDistributionRatiosRequest(
    @field:NotEmpty
    @field:Valid
    val ratios: List<RatioEntry>
)

data class DistributionRatioResponse(
    val pocketId: UUID,
    val pocketName: String,
    val ratio: BigDecimal
)
