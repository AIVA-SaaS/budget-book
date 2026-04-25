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
    val createdAt: Instant,
    /** Phase 25 후속 — EXPENSE/INCOME. 기존 위치 인자 호환 위해 끝에 배치. */
    val categoryType: String = "EXPENSE",
)

data class CreateCategoryGroupRequest(
    @field:NotBlank
    @field:Size(max = 50)
    val name: String,
    val icon: String? = null,
    val color: String? = null,
    val budgetType: String = "MONTHLY",
    /** EXPENSE/INCOME. 미지정 시 EXPENSE. */
    val categoryType: String = "EXPENSE",
    val visibility: String? = "SHARED"
)

data class UpdateCategoryGroupRequest(
    @field:Size(max = 50)
    val name: String? = null,
    val icon: String? = null,
    val color: String? = null,
    val budgetType: String? = null,
    /** Phase 25 후속 — 그룹 안 카테고리들과 type 일치 시에만 변경 허용 (서비스 단 검증). */
    val categoryType: String? = null,
    val displayOrder: Int? = null,
    val visibility: String? = null
)

data class ReorderCategoryGroupRequest(
    val orderedIds: List<UUID>
)
