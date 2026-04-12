package com.budgetbook.feedback.repository

import com.budgetbook.feedback.domain.FeedbackVote
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface FeedbackVoteRepository : JpaRepository<FeedbackVote, UUID> {

    fun findByPostIdAndUserId(postId: UUID, userId: UUID): FeedbackVote?

    fun countByPostId(postId: UUID): Long

    fun existsByPostIdAndUserId(postId: UUID, userId: UUID): Boolean
}
