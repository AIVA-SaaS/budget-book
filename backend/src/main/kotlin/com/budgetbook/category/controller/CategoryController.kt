package com.budgetbook.category.controller

import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.dto.CategoryResponse
import com.budgetbook.category.dto.CreateCategoryRequest
import com.budgetbook.category.dto.UpdateCategoryRequest
import com.budgetbook.category.service.CategoryService
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.exception.BusinessException
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
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/categories")
class CategoryController(
    private val categoryService: CategoryService
) {

    @GetMapping
    fun listCategories(
        @AuthUser userId: UUID,
        @RequestParam(required = false) type: String?
    ): ApiResponse<List<CategoryResponse>> {
        val categoryType = type?.let {
            try { CategoryType.valueOf(it) } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid category type: $it")
            }
        }
        return ApiResponse.ok(categoryService.listCategories(userId, categoryType))
    }

    @PostMapping
    fun createCategory(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateCategoryRequest
    ): ResponseEntity<ApiResponse<CategoryResponse>> {
        val result = categoryService.createCategory(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/{id}")
    fun updateCategory(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateCategoryRequest
    ): ApiResponse<CategoryResponse> {
        return ApiResponse.ok(categoryService.updateCategory(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteCategory(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        categoryService.deleteCategory(userId, id)
        return ResponseEntity.noContent().build()
    }
}
