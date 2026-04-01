package com.budgetbook.feedback.service

import com.budgetbook.admin.dto.PagedResponse
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackComment
import com.budgetbook.feedback.domain.FeedbackPost
import com.budgetbook.feedback.domain.FeedbackStatus
import com.budgetbook.feedback.dto.ChangeStatusRequest
import com.budgetbook.feedback.dto.CreateCommentRequest
import com.budgetbook.feedback.dto.CreateFeedbackRequest
import com.budgetbook.feedback.dto.FeedbackCommentResponse
import com.budgetbook.feedback.dto.FeedbackDetailResponse
import com.budgetbook.feedback.dto.FeedbackPostResponse
import com.budgetbook.feedback.dto.FeedbackStatsResponse
import com.budgetbook.feedback.repository.FeedbackCommentRepository
import com.budgetbook.feedback.repository.FeedbackPostRepository
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class FeedbackService(
    private val feedbackPostRepository: FeedbackPostRepository,
    private val feedbackCommentRepository: FeedbackCommentRepository,
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
