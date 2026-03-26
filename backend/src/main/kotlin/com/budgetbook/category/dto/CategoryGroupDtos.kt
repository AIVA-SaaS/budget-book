package com.budgetbook.category.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant
import java.util.UUID

data class CategoryGroupResponse(
    val id: UUID,
    val name: String,
    val icon: String?,
    val color: String?,
    val budgetType: String,
    val displayOrder: Int,
    val isDefault: Boolean,
    val categories: List<CategoryResponse>,
    val visibility: String = "SHARED",
    val ownerId: UUID? = null,
    val createdAt: Instant
)

data class CreateCategoryGroupRequest(
    @field:NotBlank
    @field:Size(max = 50)
    val name: String,
    val icon: String? = null,
    val color: String? = null,
    val budgetType: String = "MONTHLY",
    val visibility: String? = "SHARED"
)

data class UpdateCategoryGroupRequest(
    @field:Size(max = 50)
    val name: String? = null,
    val icon: String? = null,
    val color: String? = null,
    val budgetType: String? = null,
    val displayOrder: Int? = null,
    val visibility: String? = null
)

data class ReorderCategoryGroupRequest(
    val orderedIds: List<UUID>
)
