package com.budgetbook.smart.service

import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.smart.domain.CategoryPattern
import com.budgetbook.smart.dto.ClassifySuggestion
import com.budgetbook.smart.repository.CategoryPatternRepository
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime
import java.util.UUID

@Service
class PatternLearningService(
    private val categoryPatternRepository: CategoryPatternRepository,
    private val categoryRepository: CategoryRepository
) {

    private val log = LoggerFactory.getLogger(javaClass)

    @Transactional
    fun learn(coupleId: UUID, description: String, categoryId: UUID) {
        val keywords = extractKeywords(description)
        if (keywords.isEmpty()) return

        keywords.forEach { keyword ->
            val existing = categoryPatternRepository.findByCoupleIdAndKeywordAndCategoryId(
                coupleId, keyword, categoryId
            )
            if (existing != null) {
                existing.frequency += 1
                existing.lastUsedAt = LocalDateTime.now()
                categoryPatternRepository.save(existing)
            } else {
                categoryPatternRepository.save(
                    CategoryPattern(
                        coupleId = coupleId,
                        keyword = keyword,
                        categoryId = categoryId
                    )
                )
            }
        }
    }

    @Transactional(readOnly = true)
    fun suggest(coupleId: UUID, description: String): List<ClassifySuggestion> {
        val keywords = extractKeywords(description)
        if (keywords.isEmpty()) return emptyList()

        val patterns = categoryPatternRepository.findByCoupleIdAndKeywordIn(coupleId, keywords)
        if (patterns.isEmpty()) return emptyList()

        // Group by categoryId, sum frequencies
        val grouped = patterns.groupBy { it.categoryId }
            .mapValues { (_, pats) -> pats.sumOf { it.frequency } }
            .entries
            .sortedByDescending { it.value }
            .take(5)

        val totalFrequency = grouped.sumOf { it.value }.toDouble()
        val categoryIds = grouped.map { it.key }.toSet()

        // Batch-fetch categories for name/group info
        val categories = categoryRepository.findAllById(categoryIds).associateBy { it.id }

        return grouped.mapNotNull { (categoryId, frequency) ->
            val category = categories[categoryId] ?: return@mapNotNull null
            ClassifySuggestion(
                categoryId = categoryId,
                categoryName = category.name,
                groupName = category.group?.name,
                confidence = (frequency / totalFrequency).coerceAtMost(1.0),
                source = "PATTERN"
            )
        }
    }

    internal fun extractKeywords(description: String): List<String> =
        description.split("\\s+".toRegex())
            .map { it.trim() }
            .filter { it.length >= 2 }
            .distinct()
}
