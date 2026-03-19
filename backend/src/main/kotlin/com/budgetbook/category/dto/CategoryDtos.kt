package com.budgetbook.category.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant
import java.util.UUID

data class CategoryResponse(
    val id: UUID,
    val name: String,
    val type: String,
    val icon: String?,
    val color: String?,
    val groupId: UUID? = null,
    val isDefault: Boolean,
    val displayOrder: Int,
    val visibility: String = "SHARED",
    val ownerId: UUID? = null,
    val createdAt: Instant
)

data class CreateCategoryRequest(
    @field:NotBlank
    @field:Size(max = 50)
    val name: String,

    @field:NotBlank
    val type: String,

    val icon: String? = null,
    val color: String? = null,
    val groupId: UUID? = null,
    val visibility: String? = "SHARED"
)

data class UpdateCategoryRequest(
    @field:Size(max = 50)
    val name: String? = null,
    val icon: String? = null,
    val color: String? = null,
    val displayOrder: Int? = null,
    val groupId: UUID? = null,
    val visibility: String? = null
)
