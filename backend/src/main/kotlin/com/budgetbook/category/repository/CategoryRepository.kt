package com.budgetbook.category.repository

import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface CategoryRepository : JpaRepository<Category, UUID> {

    @Query("""
        SELECT c FROM Category c
        WHERE c.couple.id = :coupleId
        AND (c.visibility = com.budgetbook.common.entity.Visibility.SHARED OR c.owner.id = :userId)
    """)
    fun findByCoupleIdAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<Category>

    @Query("""
        SELECT c FROM Category c
        WHERE c.couple.id = :coupleId
        AND c.type = :type
        AND (c.visibility = com.budgetbook.common.entity.Visibility.SHARED OR c.owner.id = :userId)
    """)
    fun findByCoupleIdAndTypeAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("type") type: CategoryType,
        @Param("userId") userId: UUID
    ): List<Category>

    @Query("""
        SELECT c FROM Category c
        WHERE c.couple.id = :coupleId
        AND c.group.id = :groupId
        AND (c.visibility = com.budgetbook.common.entity.Visibility.SHARED OR c.owner.id = :userId)
    """)
    fun findByCoupleIdAndGroupIdAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("groupId") groupId: UUID,
        @Param("userId") userId: UUID
    ): List<Category>

    @Query("""
        SELECT c FROM Category c
        WHERE c.couple.id = :coupleId
        AND c.group IS NULL
        AND (c.visibility = com.budgetbook.common.entity.Visibility.SHARED OR c.owner.id = :userId)
    """)
    fun findByCoupleIdAndGroupIsNullAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<Category>

    // Keep original methods for internal use (seeding, migrations, etc.)
    fun findByCoupleId(coupleId: UUID): List<Category>

    fun findByCoupleIdAndType(coupleId: UUID, type: CategoryType): List<Category>

    fun findByCoupleIdAndGroupId(coupleId: UUID, groupId: UUID): List<Category>

    fun findByCoupleIdAndGroupIsNull(coupleId: UUID): List<Category>

    fun findByCoupleIdAndNameIn(coupleId: UUID, names: List<String>): List<Category>
}
