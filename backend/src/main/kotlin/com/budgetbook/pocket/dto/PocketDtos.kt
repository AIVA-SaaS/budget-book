package com.budgetbook.pocket.dto

import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.time.Instant
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

    val color: String? = null
)

data class UpdatePocketRequest(
    @field:Size(max = 50)
    val name: String? = null,

    @field:Min(0)
    @field:Max(999_999_999)
    val allocatedAmount: Long? = null,

    val icon: String? = null,

    val color: String? = null,

    val displayOrder: Int? = null
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
    val createdAt: Instant,
    val updatedAt: Instant
)
