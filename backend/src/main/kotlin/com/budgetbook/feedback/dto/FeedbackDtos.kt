package com.budgetbook.feedback.dto

import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackComment
import com.budgetbook.feedback.domain.FeedbackPost
import com.budgetbook.feedback.domain.FeedbackStatus
import com.budgetbook.feedback.domain.ReleaseNote
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.time.Instant
import java.util.UUID

// === Feedback Request DTOs ===

data class CreateFeedbackRequest(
    @field:NotBlank(message = "Title is required")
    @field:Size(max = 200, message = "Title must be 200 characters or less")
    val title: String,

    @field:NotBlank(message = "Content is required")
    val content: String,

    @field:NotNull(message = "Category is required")
    val category: FeedbackCategory
)

data class CreateCommentRequest(
    @field:NotBlank(message = "Content is required")
    val content: String
)

data class ChangeStatusRequest(
    @field:NotNull(message = "Status is required")
    val status: FeedbackStatus,

    val reason: String? = null
)

data class UpdateAdminNoteRequest(
    val note: String?
)

// === Feedback Response DTOs ===

data class FeedbackPostResponse(
    val id: UUID,
    val userId: UUID,
    val userNickname: String,
    val category: FeedbackCategory,
    val title: String,
    val content: String,
    val status: FeedbackStatus,
    val adminNote: String?,
    val resolvedReleaseId: UUID?,
    val createdAt: Instant,
    val updatedAt: Instant
) {
    companion object {
        fun from(post: FeedbackPost): FeedbackPostResponse = FeedbackPostResponse(
            id = post.id,
            userId = post.user.id,
            userNickname = post.user.nickname,
            category = post.category,
            title = post.title,
            content = post.content,
            status = post.status,
            adminNote = post.adminNote,
            resolvedReleaseId = post.resolvedReleaseId,
            createdAt = post.createdAt,
            updatedAt = post.updatedAt
        )
    }
}

data class FeedbackDetailResponse(
    val id: UUID,
    val userId: UUID,
    val userNickname: String,
    val category: FeedbackCategory,
    val title: String,
    val content: String,
    val status: FeedbackStatus,
    val adminNote: String?,
    val resolvedReleaseId: UUID?,
    val comments: List<FeedbackCommentResponse>,
    val createdAt: Instant,
    val updatedAt: Instant
) {
    companion object {
        fun from(post: FeedbackPost): FeedbackDetailResponse = FeedbackDetailResponse(
            id = post.id,
            userId = post.user.id,
            userNickname = post.user.nickname,
            category = post.category,
            title = post.title,
            content = post.content,
            status = post.status,
            adminNote = post.adminNote,
            resolvedReleaseId = post.resolvedReleaseId,
            comments = post.comments.map { FeedbackCommentResponse.from(it) },
            createdAt = post.createdAt,
            updatedAt = post.updatedAt
        )
    }
}

data class FeedbackCommentResponse(
    val id: UUID,
    val authorId: UUID,
    val authorNickname: String,
    val content: String,
    val isAdminReply: Boolean,
    val createdAt: Instant
) {
    companion object {
        fun from(comment: FeedbackComment): FeedbackCommentResponse = FeedbackCommentResponse(
            id = comment.id,
            authorId = comment.author.id,
            authorNickname = comment.author.nickname,
            content = comment.content,
            isAdminReply = comment.isAdminReply,
            createdAt = comment.createdAt
        )
    }
}

data class FeedbackStatsResponse(
    val byCategory: Map<FeedbackCategory, Long>,
    val byStatus: Map<FeedbackStatus, Long>,
    val total: Long
)

// === Vote DTOs ===

data class VoteResponse(
    val voted: Boolean,
    val voteCount: Int
)

data class PublicFeedbackResponse(
    val id: UUID,
    val category: FeedbackCategory,
    val title: String,
    val contentPreview: String,
    val status: FeedbackStatus,
    val voteCount: Int,
    val hasVoted: Boolean,
    val commentCount: Int,
    val authorName: String,
    val createdAt: Instant
) {
    companion object {
        fun from(post: FeedbackPost, hasVoted: Boolean): PublicFeedbackResponse = PublicFeedbackResponse(
            id = post.id,
            category = post.category,
            title = post.title,
            contentPreview = post.content.take(100),
            status = post.status,
            voteCount = post.voteCount,
            hasVoted = hasVoted,
            commentCount = post.comments.size,
            authorName = post.user.nickname,
            createdAt = post.createdAt
        )
    }
}

// === Release Note Request DTOs ===

data class CreateReleaseNoteRequest(
    @field:NotBlank(message = "Version is required")
    @field:Size(max = 20, message = "Version must be 20 characters or less")
    val version: String,

    @field:NotBlank(message = "Title is required")
    @field:Size(max = 200, message = "Title must be 200 characters or less")
    val title: String,

    @field:NotBlank(message = "Content is required")
    val content: String
)

data class UpdateReleaseNoteRequest(
    @field:Size(max = 20, message = "Version must be 20 characters or less")
    val version: String? = null,

    @field:Size(max = 200, message = "Title must be 200 characters or less")
    val title: String? = null,

    val content: String? = null
)

data class PublishRequest(
    val publish: Boolean
)

data class LinkFeedbackRequest(
    val feedbackPostIds: List<UUID>
)

// === Release Note Response DTOs ===

data class ReleaseNoteResponse(
    val id: UUID,
    val version: String,
    val title: String,
    val content: String,
    val isPublished: Boolean,
    val publishedAt: Instant?,
    val createdBy: UUID,
    val createdAt: Instant,
    val updatedAt: Instant
) {
    companion object {
        fun from(note: ReleaseNote): ReleaseNoteResponse = ReleaseNoteResponse(
            id = note.id,
            version = note.version,
            title = note.title,
            content = note.content,
            isPublished = note.isPublished,
            publishedAt = note.publishedAt,
            createdBy = note.createdBy.id,
            createdAt = note.createdAt,
            updatedAt = note.updatedAt
        )
    }
}

data class ReleaseNoteDetailResponse(
    val id: UUID,
    val version: String,
    val title: String,
    val content: String,
    val isPublished: Boolean,
    val publishedAt: Instant?,
    val createdBy: UUID,
    val linkedFeedbacks: List<FeedbackPostResponse>,
    val createdAt: Instant,
    val updatedAt: Instant
) {
    companion object {
        fun from(note: ReleaseNote): ReleaseNoteDetailResponse = ReleaseNoteDetailResponse(
            id = note.id,
            version = note.version,
            title = note.title,
            content = note.content,
            isPublished = note.isPublished,
            publishedAt = note.publishedAt,
            createdBy = note.createdBy.id,
            linkedFeedbacks = note.linkedFeedbacks.map { FeedbackPostResponse.from(it) },
            createdAt = note.createdAt,
            updatedAt = note.updatedAt
        )
    }
}
