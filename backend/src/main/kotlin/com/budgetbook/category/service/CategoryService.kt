package com.budgetbook.category.service

import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.dto.CategoryResponse
import com.budgetbook.category.dto.CreateCategoryRequest
import com.budgetbook.category.dto.UpdateCategoryRequest
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class CategoryService(
    private val categoryRepository: CategoryRepository,
    private val coupleRepository: CoupleRepository
) {

    @Transactional(readOnly = true)
    fun listCategories(userId: UUID, type: CategoryType?): List<CategoryResponse> {
        val couple = getActiveCouple(userId)
        val categories = if (type != null) {
            categoryRepository.findByCoupleIdAndType(couple.id, type)
        } else {
            categoryRepository.findByCoupleId(couple.id)
        }
        return categories.map { it.toResponse() }
    }

    @Transactional
    fun createCategory(userId: UUID, request: CreateCategoryRequest): CategoryResponse {
        val couple = getActiveCouple(userId)
        val categoryType = try {
            CategoryType.valueOf(request.type)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid category type: ${request.type}")
        }

        val category = Category(
            couple = couple,
            name = request.name,
            type = categoryType,
            icon = request.icon,
            color = request.color,
            isDefault = false,
            displayOrder = 0
        )
        return categoryRepository.save(category).toResponse()
    }

    @Transactional
    fun updateCategory(userId: UUID, categoryId: UUID, request: UpdateCategoryRequest): CategoryResponse {
        val couple = getActiveCouple(userId)
        val category = categoryRepository.findById(categoryId)
            .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Category does not exist.") }

        if (category.couple.id != couple.id) {
            throw ForbiddenException("FORBIDDEN", "Category belongs to a different couple.")
        }

        request.name?.let { category.name = it }
        request.icon?.let { category.icon = it }
        request.color?.let { category.color = it }
        request.displayOrder?.let { category.displayOrder = it }

        return categoryRepository.save(category).toResponse()
    }

    @Transactional
    fun deleteCategory(userId: UUID, categoryId: UUID) {
        val couple = getActiveCouple(userId)
        val category = categoryRepository.findById(categoryId)
            .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Category does not exist.") }

        if (category.couple.id != couple.id) {
            throw ForbiddenException("FORBIDDEN", "Category belongs to a different couple.")
        }

        if (category.isDefault) {
            throw BusinessException("CANNOT_DELETE_DEFAULT_CATEGORY", "Default categories cannot be deleted.")
        }

        categoryRepository.delete(category)
    }

    @Transactional
    fun seedDefaultCategories(couple: Couple) {
        val defaults = listOf(
            // INCOME
            DefaultCategory("급여", CategoryType.INCOME, "payments", "#4CAF50", 1),
            DefaultCategory("부업/용돈", CategoryType.INCOME, "attach_money", "#8BC34A", 2),
            // EXPENSE
            DefaultCategory("식비", CategoryType.EXPENSE, "restaurant", "#FF5733", 1),
            DefaultCategory("교통비", CategoryType.EXPENSE, "directions_car", "#2196F3", 2),
            DefaultCategory("쇼핑", CategoryType.EXPENSE, "shopping_bag", "#9C27B0", 3),
            DefaultCategory("의료/건강", CategoryType.EXPENSE, "local_hospital", "#F44336", 4),
            DefaultCategory("문화/여가", CategoryType.EXPENSE, "movie", "#FF9800", 5),
            DefaultCategory("기타", CategoryType.EXPENSE, "more_horiz", "#9E9E9E", 6)
        )

        val categories = defaults.map { d ->
            Category(
                couple = couple,
                name = d.name,
                type = d.type,
                icon = d.icon,
                color = d.color,
                isDefault = true,
                displayOrder = d.displayOrder
            )
        }
        categoryRepository.saveAll(categories)
    }

    private fun getActiveCouple(userId: UUID): Couple {
        return coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
            ?: throw NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")
    }

    private fun Category.toResponse() = CategoryResponse(
        id = id,
        name = name,
        type = type.name,
        icon = icon,
        color = color,
        isDefault = isDefault,
        displayOrder = displayOrder,
        createdAt = createdAt
    )

    private data class DefaultCategory(
        val name: String,
        val type: CategoryType,
        val icon: String,
        val color: String,
        val displayOrder: Int
    )
}
