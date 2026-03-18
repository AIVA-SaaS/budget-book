package com.budgetbook.category.controller

import com.budgetbook.category.dto.CategoryGroupResponse
import com.budgetbook.category.dto.CreateCategoryGroupRequest
import com.budgetbook.category.dto.UpdateCategoryGroupRequest
import com.budgetbook.category.service.CategoryGroupService
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/category-groups")
class CategoryGroupController(
    private val categoryGroupService: CategoryGroupService
) {

    @GetMapping
    fun listCategoryGroups(@AuthUser userId: UUID): ApiResponse<List<CategoryGroupResponse>> {
        return ApiResponse.ok(categoryGroupService.listCategoryGroups(userId))
    }

    @PostMapping
    fun createCategoryGroup(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateCategoryGroupRequest
    ): ResponseEntity<ApiResponse<CategoryGroupResponse>> {
        val result = categoryGroupService.createCategoryGroup(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/{id}")
    fun updateCategoryGroup(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateCategoryGroupRequest
    ): ApiResponse<CategoryGroupResponse> {
        return ApiResponse.ok(categoryGroupService.updateCategoryGroup(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteCategoryGroup(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        categoryGroupService.deleteCategoryGroup(userId, id)
        return ResponseEntity.noContent().build()
    }
}
