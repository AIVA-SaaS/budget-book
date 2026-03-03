package com.budgetbook.category.controller

import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.dto.CategoryResponse
import com.budgetbook.category.dto.CreateCategoryRequest
import com.budgetbook.category.dto.UpdateCategoryRequest
import com.budgetbook.category.service.CategoryService
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.exception.BusinessException
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
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
        authentication: Authentication,
        @RequestParam(required = false) type: String?
    ): ApiResponse<List<CategoryResponse>> {
        val userId = authentication.principal as UUID
        val categoryType = type?.let {
            try { CategoryType.valueOf(it) } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid category type: $it")
            }
        }
        return ApiResponse.ok(categoryService.listCategories(userId, categoryType))
    }

    @PostMapping
    fun createCategory(
        authentication: Authentication,
        @Valid @RequestBody request: CreateCategoryRequest
    ): ResponseEntity<ApiResponse<CategoryResponse>> {
        val userId = authentication.principal as UUID
        val result = categoryService.createCategory(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/{id}")
    fun updateCategory(
        authentication: Authentication,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateCategoryRequest
    ): ApiResponse<CategoryResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(categoryService.updateCategory(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteCategory(
        authentication: Authentication,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        val userId = authentication.principal as UUID
        categoryService.deleteCategory(userId, id)
        return ResponseEntity.noContent().build()
    }
}
