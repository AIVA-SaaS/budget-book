package com.budgetbook.smart.repository

import com.budgetbook.smart.domain.CategoryPattern
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface CategoryPatternRepository : JpaRepository<CategoryPattern, UUID> {

    fun findByCoupleIdAndKeywordIn(coupleId: UUID, keywords: List<String>): List<CategoryPattern>

    fun findByCoupleIdAndKeywordAndCategoryId(coupleId: UUID, keyword: String, categoryId: UUID): CategoryPattern?

    fun findByCoupleIdAndKeyword(coupleId: UUID, keyword: String, pageable: Pageable): List<CategoryPattern>
}
