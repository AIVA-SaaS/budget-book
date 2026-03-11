package com.budgetbook.category.repository

import com.budgetbook.category.domain.CategoryGroup
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface CategoryGroupRepository : JpaRepository<CategoryGroup, UUID> {
    fun findByCoupleId(coupleId: UUID): List<CategoryGroup>
    fun findByCoupleIdOrderByDisplayOrder(coupleId: UUID): List<CategoryGroup>
    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): CategoryGroup?
}
