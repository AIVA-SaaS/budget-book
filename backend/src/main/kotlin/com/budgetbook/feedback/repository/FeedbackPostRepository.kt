package com.budgetbook.feedback.repository

import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackPost
import com.budgetbook.feedback.domain.FeedbackStatus
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface FeedbackPostRepository : JpaRepository<FeedbackPost, UUID> {

    fun findByUserIdOrderByCreatedAtDesc(userId: UUID): List<FeedbackPost>

    @Query("""
        SELECT fp FROM FeedbackPost fp
        WHERE (:status IS NULL OR fp.status = :status)
        AND (:category IS NULL OR fp.category = :category)
        ORDER BY fp.createdAt DESC
    """)
    fun findAllWithFilters(
        @Param("status") status: FeedbackStatus?,
        @Param("category") category: FeedbackCategory?,
        pageable: Pageable
    ): Page<FeedbackPost>

    @Query("""
        SELECT fp FROM FeedbackPost fp
        LEFT JOIN FETCH fp.user
        WHERE (:status IS NULL OR fp.status = :status)
        AND (:category IS NULL OR fp.category = :category)
        ORDER BY fp.voteCount DESC, fp.createdAt DESC
    """,
    countQuery = """
        SELECT COUNT(fp) FROM FeedbackPost fp
        WHERE (:status IS NULL OR fp.status = :status)
        AND (:category IS NULL OR fp.category = :category)
    """)
    fun findPublicByPopular(
        @Param("status") status: FeedbackStatus?,
        @Param("category") category: FeedbackCategory?,
        pageable: Pageable
    ): Page<FeedbackPost>

    @Query("""
        SELECT fp FROM FeedbackPost fp
        LEFT JOIN FETCH fp.user
        WHERE (:status IS NULL OR fp.status = :status)
        AND (:category IS NULL OR fp.category = :category)
        ORDER BY fp.createdAt DESC
    """,
    countQuery = """
        SELECT COUNT(fp) FROM FeedbackPost fp
        WHERE (:status IS NULL OR fp.status = :status)
        AND (:category IS NULL OR fp.category = :category)
    """)
    fun findPublicByLatest(
        @Param("status") status: FeedbackStatus?,
        @Param("category") category: FeedbackCategory?,
        pageable: Pageable
    ): Page<FeedbackPost>

    @Query("""
        SELECT fp FROM FeedbackPost fp
        LEFT JOIN FETCH fp.user
        ORDER BY fp.voteCount DESC, fp.createdAt DESC
        LIMIT 10
    """)
    fun findTop10ByVoteCount(): List<FeedbackPost>

    fun countByStatus(status: FeedbackStatus): Long

    fun countByCategory(category: FeedbackCategory): Long
}
