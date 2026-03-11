package com.budgetbook.category.repository

import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface CategoryRepository : JpaRepository<Category, UUID> {

    fun findByCoupleId(coupleId: UUID): List<Category>

    fun findByCoupleIdAndType(coupleId: UUID, type: CategoryType): List<Category>

    fun findByCoupleIdAndGroupId(coupleId: UUID, groupId: UUID): List<Category>

    fun findByCoupleIdAndGroupIsNull(coupleId: UUID): List<Category>

    fun findByCoupleIdAndNameIn(coupleId: UUID, names: List<String>): List<Category>
}
