package com.budgetbook.feedback.service

import com.budgetbook.admin.dto.PagedResponse
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackComment
import com.budgetbook.feedback.domain.FeedbackPost
import com.budgetbook.feedback.domain.FeedbackStatus
import com.budgetbook.feedback.domain.FeedbackVote
import com.budgetbook.feedback.dto.ChangeStatusRequest
import com.budgetbook.feedback.dto.CreateCommentRequest
import com.budgetbook.feedback.dto.CreateFeedbackRequest
import com.budgetbook.feedback.dto.FeedbackCommentResponse
import com.budgetbook.feedback.dto.FeedbackDetailResponse
import com.budgetbook.feedback.dto.FeedbackPostResponse
import com.budgetbook.feedback.dto.FeedbackStatsResponse
import com.budgetbook.feedback.dto.PublicFeedbackResponse
import com.budgetbook.feedback.dto.VoteResponse
import com.budgetbook.feedback.repository.FeedbackCommentRepository
import com.budgetbook.feedback.repository.FeedbackPostRepository
import com.budgetbook.feedback.repository.FeedbackVoteRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class FeedbackService(
    private val feedbackPostRepository: FeedbackPostRepository,
    private val feedbackCommentRepository: FeedbackCommentRepository,
    private val feedbackVoteRepository: FeedbackVoteRepository,
    private val userRepository: UserRepository
) {

    // --- User Operations ---

    @Transactional(readOnly = true)
    fun getMyFeedbacks(userId: UUID): List<FeedbackPostResponse> {
        return feedbackPostRepository.findByUserIdOrderByCreatedAtDesc(userId)
            .map { FeedbackPostResponse.from(it) }
    }

    @Transactional
    fun createFeedback(userId: UUID, request: CreateFeedbackRequest): FeedbackPostResponse {
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found: $userId") }

        val post = FeedbackPost(
            user = user,
            category = request.category,
            title = request.title,
            content = request.content
        )

        return FeedbackPostResponse.from(feedbackPostRepository.save(post))
    }

    @Transactional(readOnly = true)
    fun getFeedbackDetail(userId: UUID, feedbackId: UUID): FeedbackDetailResponse {
        val post = feedbackPostRepository.findById(feedbackId)
            .orElseThrow { NotFoundException("FEEDBACK_NOT_FOUND", "Feedback not found: $feedbackId") }

        // Users can only view their own feedback; admins use the admin endpoint
        if (post.user.id != userId) {
            throw ForbiddenException("FEEDBACK_ACCESS_DENIED", "You can only view your own feedback.")
        }

        return FeedbackDetailResponse.from(post)
    }

    @Transactional
    fun addComment(userId: UUID, feedbackId: UUID, request: CreateCommentRequest): FeedbackCommentResponse {
        val post = feedbackPostRepository.findById(feedbackId)
            .orElseThrow { NotFoundException("FEEDBACK_NOT_FOUND", "Feedback not found: $feedbackId") }

        if (post.user.id != userId) {
            throw ForbiddenException("FEEDBACK_ACCESS_DENIED", "You can only comment on your own feedback.")
        }

        val author = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found: $userId") }

        val comment = FeedbackComment(
            post = post,
            author = author,
            content = request.content,
            isAdminReply = false
        )

        post.comments.add(comment)
        feedbackPostRepository.save(post)

        return FeedbackCommentResponse.from(comment)
    }

    // --- Vote & Public Board Operations ---

    @Transactional
    fun toggleVote(postId: UUID, userId: UUID): VoteResponse {
        val post = feedbackPostRepository.findById(postId)
            .orElseThrow { NotFoundException("FEEDBACK_NOT_FOUND", "Feedback not found: $postId") }

        val existing = feedbackVoteRepository.findByPostIdAndUserId(postId, userId)
        if (existing != null) {
            feedbackVoteRepository.delete(existing)
            post.voteCount = maxOf(0, post.voteCount - 1)
            feedbackPostRepository.save(post)
            return VoteResponse(voted = false, voteCount = post.voteCount)
        } else {
            feedbackVoteRepository.save(FeedbackVote(post = post, userId = userId))
            post.voteCount += 1
            feedbackPostRepository.save(post)
            return VoteResponse(voted = true, voteCount = post.voteCount)
        }
    }

    @Transactional(readOnly = true)
    fun getPublicFeedbacks(
        userId: UUID,
        sort: String,
        category: String?,
        status: String?,
        page: Int,
        size: Int
    ): Page<PublicFeedbackResponse> {
        val pageable = PageRequest.of(page, size)
        val categoryEnum = category?.let { FeedbackCategory.valueOf(it.uppercase()) }
        val statusEnum = status?.let { FeedbackStatus.valueOf(it.uppercase()) }

        val postsPage = if (sort == "popular") {
            feedbackPostRepository.findPublicByPopular(statusEnum, categoryEnum, pageable)
        } else {
            feedbackPostRepository.findPublicByLatest(statusEnum, categoryEnum, pageable)
        }

        val postIds = postsPage.content.map { it.id }.toSet()
        val votedPostIds = if (postIds.isNotEmpty()) {
            postIds.filter { feedbackVoteRepository.existsByPostIdAndUserId(it, userId) }.toSet()
        } else {
            emptySet()
        }

        val responses = postsPage.content.map { post ->
            PublicFeedbackResponse.from(post, votedPostIds.contains(post.id))
        }

        return PageImpl(responses, pageable, postsPage.totalElements)
    }

    @Transactional(readOnly = true)
    fun getTopFeedbacks(userId: UUID): List<PublicFeedbackResponse> {
        val posts = feedbackPostRepository.findTop10ByVoteCount()
        val postIds = posts.map { it.id }.toSet()
        val votedPostIds = if (postIds.isNotEmpty()) {
            postIds.filter { feedbackVoteRepository.existsByPostIdAndUserId(it, userId) }.toSet()
        } else {
            emptySet()
        }
        return posts.map { post ->
            PublicFeedbackResponse.from(post, votedPostIds.contains(post.id))
        }
    }

    // --- Admin Operations ---

    @Transactional(readOnly = true)
    fun getAllFeedbacks(
        status: FeedbackStatus?,
        category: FeedbackCategory?,
        page: Int,
        size: Int
    ): PagedResponse<FeedbackPostResponse> {
        val pageable = PageRequest.of(page, size)
        val result = feedbackPostRepository.findAllWithFilters(status, category, pageable)

        return PagedResponse(
            content = result.content.map { FeedbackPostResponse.from(it) },
            page = result.number,
            size = result.size,
            totalElements = result.totalElements,
            totalPages = result.totalPages
        )
    }

    @Transactional
    fun changeStatus(feedbackId: UUID, request: ChangeStatusRequest): FeedbackPostResponse {
        val post = feedbackPostRepository.findById(feedbackId)
            .orElseThrow { NotFoundException("FEEDBACK_NOT_FOUND", "Feedback not found: $feedbackId") }

        post.status = request.status

        // If rejected, store reason in admin note
        if (request.status == FeedbackStatus.REJECTED && !request.reason.isNullOrBlank()) {
            post.adminNote = request.reason
        }

        return FeedbackPostResponse.from(feedbackPostRepository.save(post))
    }

    @Transactional
    fun addAdminComment(
        adminUserId: UUID,
        feedbackId: UUID,
        request: CreateCommentRequest
    ): FeedbackCommentResponse {
        val post = feedbackPostRepository.findById(feedbackId)
            .orElseThrow { NotFoundException("FEEDBACK_NOT_FOUND", "Feedback not found: $feedbackId") }

        val admin = userRepository.findById(adminUserId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "Admin user not found: $adminUserId") }

        val comment = FeedbackComment(
            post = post,
            author = admin,
            content = request.content,
            isAdminReply = true
        )

        post.comments.add(comment)
        feedbackPostRepository.save(post)

        return FeedbackCommentResponse.from(comment)
    }

    @Transactional
    fun updateAdminNote(feedbackId: UUID, note: String?): FeedbackPostResponse {
        val post = feedbackPostRepository.findById(feedbackId)
            .orElseThrow { NotFoundException("FEEDBACK_NOT_FOUND", "Feedback not found: $feedbackId") }

        post.adminNote = note

        return FeedbackPostResponse.from(feedbackPostRepository.save(post))
    }

    @Transactional(readOnly = true)
    fun getFeedbackStats(): FeedbackStatsResponse {
        val byCategory = FeedbackCategory.entries.associateWith { feedbackPostRepository.countByCategory(it) }
        val byStatus = FeedbackStatus.entries.associateWith { feedbackPostRepository.countByStatus(it) }
        val total = feedbackPostRepository.count()

        return FeedbackStatsResponse(
            byCategory = byCategory,
            byStatus = byStatus,
            total = total
        )
    }

    // Used by admin detail endpoint
    @Transactional(readOnly = true)
    fun getAdminFeedbackDetail(feedbackId: UUID): FeedbackDetailResponse {
        val post = feedbackPostRepository.findById(feedbackId)
            .orElseThrow { NotFoundException("FEEDBACK_NOT_FOUND", "Feedback not found: $feedbackId") }
        return FeedbackDetailResponse.from(post)
    }
}
