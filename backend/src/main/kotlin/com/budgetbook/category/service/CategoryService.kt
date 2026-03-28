package com.budgetbook.category.service

import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.dto.CategoryResponse
import com.budgetbook.category.dto.CreateCategoryRequest
import com.budgetbook.category.dto.ReorderCategoryRequest
import com.budgetbook.category.dto.UpdateCategoryRequest
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transaction.service.TransactionService
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class CategoryService(
    private val categoryRepository: CategoryRepository,
    private val categoryGroupRepository: CategoryGroupRepository,
    override val coupleResolver: CoupleResolver,
    private val syncEventPublisher: SyncEventPublisher,
    private val redisCacheService: RedisCacheService,
    private val userRepository: UserRepository,
    private val transactionRepository: TransactionRepository
) : CoupleAwareService {

    private val log = LoggerFactory.getLogger(javaClass)

    @Transactional(readOnly = true)
    fun listCategories(userId: UUID, type: CategoryType?): List<CategoryResponse> {
        val couple = getActiveCouple(userId)
        val categories = if (type != null) {
            categoryRepository.findByCoupleIdAndTypeAndUserId(couple.id, type, userId)
        } else {
            categoryRepository.findByCoupleIdAndUserId(couple.id, userId)
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

        val visibility = TransactionService.parseVisibility(request.visibility)

        val group = request.groupId?.let { groupId ->
            categoryGroupRepository.findByIdAndCoupleId(groupId, couple.id)
                ?: throw NotFoundException("GROUP_NOT_FOUND", "Category group does not exist.")
        }

        // Validate visibility consistency with parent group
        if (group != null) {
            validateVisibilityConsistency(group.visibility, visibility)
        }

        val owner = if (visibility == Visibility.PRIVATE) {
            userRepository.findById(userId)
                .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
        } else null

        val category = Category(
            couple = couple,
            name = request.name,
            type = categoryType,
            icon = request.icon,
            color = request.color,
            group = group,
            isDefault = false,
            displayOrder = 0,
            visibility = visibility,
            owner = owner
        )
        val saved = categoryRepository.save(category)
        syncEventPublisher.publish(SyncEvent(
            type = "CATEGORY_CREATED",
            entityType = "CATEGORY",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        evictCategoryCache(couple.id)
        return saved.toResponse()
    }

    @Transactional
    fun updateCategory(userId: UUID, categoryId: UUID, request: UpdateCategoryRequest): CategoryResponse {
        val couple = getActiveCouple(userId)
        val category = categoryRepository.findById(categoryId)
            .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Category does not exist.") }

        OwnershipValidator.validateOwnership(category.couple.id, couple, "Category")
        validatePrivateOwner(category, userId)

        request.name?.let { category.name = it }
        request.icon?.let { category.icon = it }
        request.color?.let { category.color = it }
        request.displayOrder?.let { category.displayOrder = it }
        request.groupId?.let { groupId ->
            val group = categoryGroupRepository.findByIdAndCoupleId(groupId, couple.id)
                ?: throw NotFoundException("GROUP_NOT_FOUND", "Category group does not exist.")
            // Validate visibility consistency with new group
            val effectiveVisibility = request.visibility?.let { TransactionService.parseVisibility(it) } ?: category.visibility
            validateVisibilityConsistency(group.visibility, effectiveVisibility)
            category.group = group
        }

        // Handle visibility change and cascade to associated transactions
        request.visibility?.let { visStr ->
            val newVisibility = TransactionService.parseVisibility(visStr)
            // Validate visibility consistency with parent group before applying
            category.group?.let { grp -> validateVisibilityConsistency(grp.visibility, newVisibility) }

            val oldVisibility = category.visibility
            category.visibility = newVisibility
            if (newVisibility == Visibility.PRIVATE) {
                val user = userRepository.findById(userId)
                    .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
                category.owner = user
            } else {
                category.owner = null
            }

            // Cascade visibility change to associated transactions
            if (oldVisibility != newVisibility) {
                val ownerId = if (newVisibility == Visibility.PRIVATE) {
                    category.owner?.id
                } else {
                    null
                }
                transactionRepository.updateVisibilityByCategoryId(
                    categoryId = category.id,
                    visibility = newVisibility.name,
                    ownerId = ownerId
                )
                log.info("Cascaded visibility change to transactions for categoryId={}, visibility={}", category.id, newVisibility)
            }
        }

        val saved = categoryRepository.save(category)
        syncEventPublisher.publish(SyncEvent(
            type = "CATEGORY_UPDATED",
            entityType = "CATEGORY",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        evictCategoryCache(couple.id)
        return saved.toResponse()
    }

    @Transactional
    fun reorderCategories(userId: UUID, request: ReorderCategoryRequest) {
        val couple = getActiveCouple(userId)
        val categories = categoryRepository.findByCoupleId(couple.id)
        val categoryMap = categories.associateBy { it.id }

        // Validate all IDs belong to this couple
        request.orderedIds.forEach { id ->
            if (!categoryMap.containsKey(id)) {
                throw NotFoundException("CATEGORY_NOT_FOUND", "Category $id does not exist for this couple.")
            }
        }

        // Set displayOrder based on orderedIds position
        request.orderedIds.forEachIndexed { index, id ->
            categoryMap[id]!!.displayOrder = index
        }

        categoryRepository.saveAll(categories.filter { it.id in request.orderedIds })

        syncEventPublisher.publish(SyncEvent(
            type = "CATEGORY_REORDERED",
            entityType = "CATEGORY",
            entityId = couple.id,
            coupleId = couple.id,
            authorId = userId
        ))
        evictCategoryCache(couple.id)
    }

    @Transactional
    fun deleteCategory(userId: UUID, categoryId: UUID) {
        val couple = getActiveCouple(userId)
        val category = categoryRepository.findById(categoryId)
            .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Category does not exist.") }

        OwnershipValidator.validateOwnership(category.couple.id, couple, "Category")
        validatePrivateOwner(category, userId)

        categoryRepository.delete(category)
        syncEventPublisher.publish(SyncEvent(
            type = "CATEGORY_DELETED",
            entityType = "CATEGORY",
            entityId = categoryId,
            coupleId = couple.id,
            authorId = userId
        ))
        evictCategoryCache(couple.id)
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

    /**
     * Seed default PRIVATE categories for a user in a couple.
     */
    @Transactional
    fun seedPrivateCategories(couple: Couple, user: User, group: com.budgetbook.category.domain.CategoryGroup) {
        val privateCategories = listOf(
            DefaultCategory("용돈", CategoryType.EXPENSE, "money", "#FF9800", 1),
            DefaultCategory("비상금", CategoryType.EXPENSE, "savings", "#F44336", 2)
        )

        val categories = privateCategories.map { d ->
            Category(
                couple = couple,
                name = d.name,
                type = d.type,
                icon = d.icon,
                color = d.color,
                isDefault = false,
                displayOrder = d.displayOrder,
                group = group,
                visibility = Visibility.PRIVATE,
                owner = user
            )
        }
        categoryRepository.saveAll(categories)
    }

    private fun evictCategoryCache(coupleId: UUID) {
        redisCacheService.evict("categories:$coupleId")
        log.debug("Evicted category cache for coupleId={}", coupleId)
    }

    fun Category.toResponse() = CategoryResponse(
        id = id,
        name = name,
        type = type.name,
        icon = icon,
        color = color,
        groupId = group?.id,
        isDefault = isDefault,
        displayOrder = displayOrder,
        visibility = visibility.name,
        ownerId = owner?.id,
        createdAt = createdAt
    )

    private fun validateVisibilityConsistency(groupVisibility: Visibility, categoryVisibility: Visibility) {
        if (groupVisibility != categoryVisibility) {
            throw BusinessException(
                "VISIBILITY_MISMATCH",
                "Category visibility ($categoryVisibility) must match the parent group visibility ($groupVisibility)."
            )
        }
    }

    private fun validatePrivateOwner(category: Category, userId: UUID) {
        if (category.visibility == Visibility.PRIVATE && category.owner?.id != null && category.owner?.id != userId) {
            throw ForbiddenException("FORBIDDEN", "Only the owner can modify a private category.")
        }
    }

    private data class DefaultCategory(
        val name: String,
        val type: CategoryType,
        val icon: String,
        val color: String,
        val displayOrder: Int
    )
}
