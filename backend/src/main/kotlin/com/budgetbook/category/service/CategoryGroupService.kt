package com.budgetbook.category.service

import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.domain.BudgetType
import com.budgetbook.category.domain.CategoryGroup
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.dto.CategoryGroupResponse
import com.budgetbook.category.dto.CategoryResponse
import com.budgetbook.category.dto.CreateCategoryGroupRequest
import com.budgetbook.category.dto.UpdateCategoryGroupRequest
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transaction.service.TransactionService
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class CategoryGroupService(
    private val categoryGroupRepository: CategoryGroupRepository,
    private val categoryRepository: CategoryRepository,
    private val categoryService: CategoryService,
    override val coupleResolver: CoupleResolver,
    private val syncEventPublisher: SyncEventPublisher,
    private val userRepository: UserRepository,
    private val transactionRepository: TransactionRepository
) : CoupleAwareService {

    private val log = org.slf4j.LoggerFactory.getLogger(javaClass)

    @Transactional
    fun listCategoryGroups(userId: UUID): List<CategoryGroupResponse> {
        val couple = getActiveCouple(userId)
        ensurePrivateGroupExists(couple, userId)
        val groups = categoryGroupRepository.findByCoupleIdAndUserIdOrderByDisplayOrder(couple.id, userId)

        // Batch load all visible categories once, then group by groupId in memory
        val allCategories = categoryRepository.findByCoupleIdAndUserId(couple.id, userId)
        val categoriesByGroupId = allCategories.groupBy { it.group?.id }
        val uncategorized = categoriesByGroupId[null] ?: emptyList()

        val result = groups.map { group ->
            val categories = categoriesByGroupId[group.id] ?: emptyList()
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

        val visibility = TransactionService.parseVisibility(request.visibility)

        val owner = if (visibility == Visibility.PRIVATE) {
            userRepository.findById(userId)
                .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
        } else null

        val categoryType = try {
            CategoryType.valueOf(request.categoryType)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid category type: ${request.categoryType}")
        }

        val group = CategoryGroup(
            couple = couple,
            name = request.name,
            icon = request.icon,
            color = request.color,
            budgetType = budgetType,
            categoryType = categoryType,
            displayOrder = 0,
            isDefault = false,
            visibility = visibility,
            owner = owner
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
        validatePrivateOwner(group, userId)

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
        request.categoryType?.let { ct ->
            val newType = try {
                CategoryType.valueOf(ct)
            } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid category type: $ct")
            }
            // type 변경 시 그룹 안 모든 카테고리 type 과 일치해야 함.
            if (newType != group.categoryType) {
                val children = categoryRepository.findByCoupleIdAndGroupId(couple.id, group.id)
                val mismatched = children.filter { it.type != newType }
                if (mismatched.isNotEmpty()) {
                    throw BusinessException(
                        "CATEGORY_TYPE_MISMATCH",
                        "그룹 안 ${mismatched.size}개 카테고리의 type 이 다릅니다. 먼저 카테고리를 이동하세요.",
                    )
                }
                group.categoryType = newType
            }
        }
        request.displayOrder?.let { group.displayOrder = it }

        // Handle visibility change with cascade to child categories
        request.visibility?.let { visStr ->
            val newVisibility = TransactionService.parseVisibility(visStr)
            val oldVisibility = group.visibility
            group.visibility = newVisibility
            if (newVisibility == Visibility.PRIVATE) {
                val user = userRepository.findById(userId)
                    .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
                group.owner = user
            } else {
                group.owner = null
            }

            // Cascade visibility change to child categories and their transactions
            if (oldVisibility != newVisibility) {
                val childCategories = categoryRepository.findByCoupleIdAndGroupId(couple.id, group.id)
                childCategories.forEach { cat ->
                    cat.visibility = newVisibility
                    if (newVisibility == Visibility.PRIVATE) {
                        cat.owner = group.owner
                    } else {
                        cat.owner = null
                    }
                    categoryRepository.save(cat)

                    // Cascade to transactions via CategoryService's existing logic
                    val ownerId = if (newVisibility == Visibility.PRIVATE) group.owner?.id else null
                    transactionRepository.updateVisibilityByCategoryId(
                        categoryId = cat.id,
                        visibility = newVisibility.name,
                        ownerId = ownerId
                    )
                }
                log.info("Cascaded visibility change to {} categories for groupId={}, visibility={}", childCategories.size, group.id, newVisibility)
            }
        }

        val saved = categoryGroupRepository.save(group)
        syncEventPublisher.publish(SyncEvent(
            type = "CATEGORY_GROUP_UPDATED",
            entityType = "CATEGORY_GROUP",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        val categories = categoryRepository.findByCoupleIdAndGroupIdAndUserId(couple.id, saved.id, userId)
        return saved.toResponse(categories.map { it.run { categoryService.run { toResponse() } } })
    }

    @Transactional
    fun deleteCategoryGroup(userId: UUID, groupId: UUID) {
        val couple = getActiveCouple(userId)
        val group = categoryGroupRepository.findByIdAndCoupleId(groupId, couple.id)
            ?: throw NotFoundException("GROUP_NOT_FOUND", "Category group does not exist.")

        OwnershipValidator.validateOwnership(group.couple.id, couple, "Category group")
        validatePrivateOwner(group, userId)

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
    fun reorderGroups(userId: UUID, orderedIds: List<UUID>): List<CategoryGroupResponse> {
        val couple = getActiveCouple(userId)
        val groups = categoryGroupRepository.findByCoupleIdOrderByDisplayOrder(couple.id)
        val groupMap = groups.associateBy { it.id }

        // Validate all IDs belong to this couple
        orderedIds.forEach { id ->
            if (!groupMap.containsKey(id)) {
                throw NotFoundException("GROUP_NOT_FOUND", "Category group $id does not exist for this couple.")
            }
        }

        // Set displayOrder based on orderedIds position
        orderedIds.forEachIndexed { index, id ->
            groupMap[id]!!.displayOrder = index
        }

        categoryGroupRepository.saveAll(groups)

        syncEventPublisher.publish(SyncEvent(
            type = "CATEGORY_GROUP_REORDERED",
            entityType = "CATEGORY_GROUP",
            entityId = couple.id,
            coupleId = couple.id,
            authorId = userId
        ))

        // Return updated list in order
        val sortedGroups = groups.sortedBy { it.displayOrder }
        return sortedGroups.map { group ->
            val categories = categoryRepository.findByCoupleIdAndGroupIdAndUserId(couple.id, group.id, userId)
            group.toResponse(categories.map { it.run { categoryService.run { toResponse() } } })
        }
    }

    @Transactional
    fun seedDefaultCategoryGroups(couple: Couple) {
        // Phase 25 후속 — 신규 사용자에게 EXPENSE 3개 + INCOME 1개 기본 그룹.
        val defaults = listOf(
            DefaultGroup("생활비", "account_balance_wallet", "#4CAF50",
                BudgetType.WEEKLY, CategoryType.EXPENSE, 1),
            DefaultGroup("고정지출", "receipt_long", "#2196F3",
                BudgetType.MONTHLY, CategoryType.EXPENSE, 2),
            DefaultGroup("기타", "more_horiz", "#9E9E9E",
                BudgetType.NONE, CategoryType.EXPENSE, 3),
            DefaultGroup("수입", "attach_money", "#4CAF50",
                BudgetType.NONE, CategoryType.INCOME, 100),
        )

        val groups = defaults.map { d ->
            CategoryGroup(
                couple = couple,
                name = d.name,
                icon = d.icon,
                color = d.color,
                budgetType = d.budgetType,
                categoryType = d.categoryType,
                displayOrder = d.displayOrder,
                isDefault = true
            )
        }
        val savedGroups = categoryGroupRepository.saveAll(groups)

        // Assign existing default categories to groups
        val groupMap = savedGroups.associateBy { it.name }

        val livingGroup = groupMap["생활비"]
        val etcGroup = groupMap["기타"]
        val incomeGroup = groupMap["수입"]

        val livingCategoryNames = listOf("식비", "교통비", "쇼핑")
        val etcCategoryNames = listOf("기타", "의료/건강", "문화/여가")
        val incomeCategoryNames = listOf("급여", "부업/용돈")

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

        if (incomeGroup != null) {
            val incomeCategories = categoryRepository.findByCoupleIdAndNameIn(couple.id, incomeCategoryNames)
            incomeCategories.forEach { it.group = incomeGroup }
            categoryRepository.saveAll(incomeCategories)
        }
    }

    /**
     * Ensure a PRIVATE "개인 항목" group exists for the user.
     * Auto-seeds for existing couples that were created before the visibility feature.
     */
    private fun ensurePrivateGroupExists(couple: Couple, userId: UUID) {
        try {
            val hasPrivateGroup = categoryGroupRepository
                .findByCoupleIdAndUserIdOrderByDisplayOrder(couple.id, userId)
                .any { it.visibility == Visibility.PRIVATE && it.owner?.id == userId }

            if (!hasPrivateGroup) {
                val user = userRepository.findById(userId).orElse(null) ?: return
                val group = seedPrivateCategoryGroup(couple, user)
                categoryService.seedPrivateCategories(couple, user, group)
            }
        } catch (e: Exception) {
            // Silently ignore seeding failures (e.g. constraint violations during concurrent access)
            log.warn("Failed to auto-seed private categories for userId={}: {}", userId, e.message)
        }
    }

    /**
     * Seed a PRIVATE "개인 항목" category group for a user.
     */
    @Transactional
    fun seedPrivateCategoryGroup(couple: Couple, user: User): CategoryGroup {
        val group = CategoryGroup(
            couple = couple,
            name = "개인 항목",
            icon = "person",
            color = "#607D8B",
            budgetType = BudgetType.NONE,
            displayOrder = 100,
            isDefault = false,
            visibility = Visibility.PRIVATE,
            owner = user
        )
        return categoryGroupRepository.save(group)
    }

    private fun CategoryGroup.toResponse(categories: List<CategoryResponse>) = CategoryGroupResponse(
        id = id,
        name = name,
        icon = icon,
        color = color,
        budgetType = budgetType.name,
        categoryType = categoryType.name,
        displayOrder = displayOrder,
        isDefault = isDefault,
        categories = categories,
        visibility = visibility.name,
        ownerId = owner?.id,
        createdAt = createdAt
    )

    private fun validatePrivateOwner(group: CategoryGroup, userId: UUID) {
        if (group.visibility == Visibility.PRIVATE && group.owner?.id != null && group.owner?.id != userId) {
            throw ForbiddenException("FORBIDDEN", "Only the owner can modify a private category group.")
        }
    }

    private data class DefaultGroup(
        val name: String,
        val icon: String,
        val color: String,
        val budgetType: BudgetType,
        val categoryType: CategoryType,
        val displayOrder: Int
    )
}
