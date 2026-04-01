package com.budgetbook.feedback.repository

import com.budgetbook.feedback.domain.FeedbackComment
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface FeedbackCommentRepository : JpaRepository<FeedbackComment, UUID>
