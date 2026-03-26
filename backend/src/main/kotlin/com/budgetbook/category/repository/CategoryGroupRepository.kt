package com.budgetbook.category.repository

import com.budgetbook.category.domain.CategoryGroup
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface CategoryGroupRepository : JpaRepository<CategoryGroup, UUID> {
    fun findByCoupleId(coupleId: UUID): List<CategoryGroup>
    fun findByCoupleIdOrderByDisplayOrder(coupleId: UUID): List<CategoryGroup>
    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): CategoryGroup?

    @Query("""
        SELECT g FROM CategoryGroup g
        WHERE g.couple.id = :coupleId
        AND (g.visibility = com.budgetbook.common.entity.Visibility.SHARED OR g.owner.id = :userId)
        ORDER BY g.displayOrder
    """)
    fun findByCoupleIdAndUserIdOrderByDisplayOrder(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<CategoryGroup>
}
