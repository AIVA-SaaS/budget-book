package com.budgetbook.category.service

import com.budgetbook.category.domain.BudgetType
import com.budgetbook.category.domain.CategoryGroup
import com.budgetbook.category.dto.CategoryGroupResponse
import com.budgetbook.category.dto.CategoryResponse
import com.budgetbook.category.dto.CreateCategoryGroupRequest
import com.budgetbook.category.dto.UpdateCategoryGroupRequest
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class CategoryGroupService(
    private val categoryGroupRepository: CategoryGroupRepository,
    private val categoryRepository: CategoryRepository,
    private val categoryService: CategoryService,
    override val coupleResolver: CoupleResolver,
    private val syncEventPublisher: SyncEventPublisher
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun listCategoryGroups(userId: UUID): List<CategoryGroupResponse> {
        val couple = getActiveCouple(userId)
        val groups = categoryGroupRepository.findByCoupleIdOrderByDisplayOrder(couple.id)
        val uncategorized = categoryRepository.findByCoupleIdAndGroupIsNull(couple.id)

        val result = groups.map { group ->
            val categories = categoryRepository.findByCoupleIdAndGroupId(couple.id, group.id)
            group.toResponse(categories.map { it.run { categoryService.run { toResponse() } } })
        }.toMutableList()

        if (uncategorized.isNotEmpty()) {
            result.add(
                CategoryGroupResponse(
                    id = UUID(0L, 0L),
                    name = "미분류",
                    icon = "help_outline",
                    color = "#BDBDBD",
                    budgetType = BudgetType.NONE.name,
                    displayOrder = Int.MAX_VALUE,
                    isDefault = false,
                    categories = uncategorized.map { it.run { categoryService.run { toResponse() } } },
                    createdAt = uncategorized.minOf { it.createdAt }
                )
            )
        }

        return result
    }

    @Transactional
    fun createCategoryGroup(userId: UUID, request: CreateCategoryGroupRequest): CategoryGroupResponse {
        val couple = getActiveCouple(userId)
        val budgetType = try {
            BudgetType.valueOf(request.budgetType)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid budget type: ${request.budgetType}")
        }

        val group = CategoryGroup(
            couple = couple,
            name = request.name,
            icon = request.icon,
            color = request.color,
            budgetType = budgetType,
            displayOrder = 0,
            isDefault = false
        )
        val saved = categoryGroupRepository.save(group)
        syncEventPublisher.publish(SyncEvent(
            type = "CATEGORY_GROUP_CREATED",
            entityType = "CATEGORY_GROUP",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse(emptyList())
    }

    @Transactional
    fun updateCategoryGroup(userId: UUID, groupId: UUID, request: UpdateCategoryGroupRequest): CategoryGroupResponse {
        val couple = getActiveCouple(userId)
        val group = categoryGroupRepository.findByIdAndCoupleId(groupId, couple.id)
            ?: throw NotFoundException("GROUP_NOT_FOUND", "Category group does not exist.")

        OwnershipValidator.validateOwnership(group.couple.id, couple, "Category group")

        request.name?.let { group.name = it }
        request.icon?.let { group.icon = it }
        request.color?.let { group.color = it }
        request.budgetType?.let { bt ->
            group.budgetType = try {
                BudgetType.valueOf(bt)
            } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid budget type: $bt")
            }
        }
        request.displayOrder?.let { group.displayOrder = it }

        val saved = categoryGroupRepository.save(group)
        syncEventPublisher.publish(SyncEvent(
            type = "CATEGORY_GROUP_UPDATED",
            entityType = "CATEGORY_GROUP",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        val categories = categoryRepository.findByCoupleIdAndGroupId(couple.id, saved.id)
        return saved.toResponse(categories.map { it.run { categoryService.run { toResponse() } } })
    }

    @Transactional
    fun deleteCategoryGroup(userId: UUID, groupId: UUID) {
        val couple = getActiveCouple(userId)
        val group = categoryGroupRepository.findByIdAndCoupleId(groupId, couple.id)
            ?: throw NotFoundException("GROUP_NOT_FOUND", "Category group does not exist.")

        OwnershipValidator.validateOwnership(group.couple.id, couple, "Category group")

        if (group.isDefault) {
            throw BusinessException("CANNOT_DELETE_DEFAULT_GROUP", "Default category groups cannot be deleted.")
        }

        // Unassign categories from this group before deleting
        val categories = categoryRepository.findByCoupleIdAndGroupId(couple.id, groupId)
        categories.forEach { it.group = null }
        categoryRepository.saveAll(categories)

        categoryGroupRepository.delete(group)
        syncEventPublisher.publish(SyncEvent(
            type = "CATEGORY_GROUP_DELETED",
            entityType = "CATEGORY_GROUP",
            entityId = groupId,
            coupleId = couple.id,
            authorId = userId
        ))
    }

    @Transactional
    fun seedDefaultCategoryGroups(couple: Couple) {
        val defaults = listOf(
            DefaultGroup("생활비", "account_balance_wallet", "#4CAF50", BudgetType.WEEKLY, 1),
            DefaultGroup("고정지출", "receipt_long", "#2196F3", BudgetType.MONTHLY, 2),
            DefaultGroup("기타", "more_horiz", "#9E9E9E", BudgetType.NONE, 3)
        )

        val groups = defaults.map { d ->
            CategoryGroup(
                couple = couple,
                name = d.name,
                icon = d.icon,
                color = d.color,
                budgetType = d.budgetType,
                displayOrder = d.displayOrder,
                isDefault = true
            )
        }
        val savedGroups = categoryGroupRepository.saveAll(groups)

        // Assign existing default categories to groups
        val groupMap = savedGroups.associateBy { it.name }

        val livingGroup = groupMap["생활비"]
        val etcGroup = groupMap["기타"]

        val livingCategoryNames = listOf("식비", "교통비", "쇼핑")
        val etcCategoryNames = listOf("기타", "의료/건강", "문화/여가")

        if (livingGroup != null) {
            val livingCategories = categoryRepository.findByCoupleIdAndNameIn(couple.id, livingCategoryNames)
            livingCategories.forEach { it.group = livingGroup }
            categoryRepository.saveAll(livingCategories)
        }

        if (etcGroup != null) {
            val etcCategories = categoryRepository.findByCoupleIdAndNameIn(couple.id, etcCategoryNames)
            etcCategories.forEach { it.group = etcGroup }
            categoryRepository.saveAll(etcCategories)
        }
    }

    private fun CategoryGroup.toResponse(categories: List<CategoryResponse>) = CategoryGroupResponse(
        id = id,
        name = name,
        icon = icon,
        color = color,
        budgetType = budgetType.name,
        displayOrder = displayOrder,
        isDefault = isDefault,
        categories = categories,
        createdAt = createdAt
    )

    private data class DefaultGroup(
        val name: String,
        val icon: String,
        val color: String,
        val budgetType: BudgetType,
        val displayOrder: Int
    )
}
