package com.budgetbook.feedback.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.security.AuthUser
import com.budgetbook.feedback.dto.CreateCommentRequest
import com.budgetbook.feedback.dto.CreateFeedbackRequest
import com.budgetbook.feedback.dto.FeedbackCommentResponse
import com.budgetbook.feedback.dto.FeedbackDetailResponse
import com.budgetbook.feedback.dto.FeedbackPostResponse
import com.budgetbook.feedback.dto.PublicFeedbackResponse
import com.budgetbook.feedback.dto.VoteResponse
import com.budgetbook.feedback.service.FeedbackService
import jakarta.validation.Valid
import org.springframework.data.domain.Page
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/feedback")
class FeedbackController(
    private val feedbackService: FeedbackService
) {

    @GetMapping
    fun getMyFeedbacks(
        @AuthUser userId: UUID
    ): ApiResponse<List<FeedbackPostResponse>> {
        return ApiResponse.ok(feedbackService.getMyFeedbacks(userId))
    }

    @RateLimit(maxRequests = 5, windowSeconds = 60)
    @PostMapping
    fun createFeedback(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateFeedbackRequest
    ): ResponseEntity<ApiResponse<FeedbackPostResponse>> {
        val result = feedbackService.createFeedback(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @GetMapping("/{id}")
    fun getFeedbackDetail(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<FeedbackDetailResponse> {
        return ApiResponse.ok(feedbackService.getFeedbackDetail(userId, id))
    }

    @RateLimit(maxRequests = 10, windowSeconds = 60)
    @PostMapping("/{id}/comments")
    fun addComment(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: CreateCommentRequest
    ): ResponseEntity<ApiResponse<FeedbackCommentResponse>> {
        val result = feedbackService.addComment(userId, id, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @RateLimit(maxRequests = 5, windowSeconds = 60)
    @PostMapping("/{id}/vote")
    fun toggleVote(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<VoteResponse> {
        return ApiResponse.ok(feedbackService.toggleVote(id, userId))
    }

    @GetMapping("/public")
    fun getPublicFeedbacks(
        @AuthUser userId: UUID,
        @RequestParam(defaultValue = "latest") sort: String,
        @RequestParam(required = false) category: String?,
        @RequestParam(required = false) status: String?,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): ApiResponse<Page<PublicFeedbackResponse>> {
        return ApiResponse.ok(feedbackService.getPublicFeedbacks(userId, sort, category, status, page, size))
    }

    @GetMapping("/public/top")
    fun getTopFeedbacks(
        @AuthUser userId: UUID
    ): ApiResponse<List<PublicFeedbackResponse>> {
        return ApiResponse.ok(feedbackService.getTopFeedbacks(userId))
    }
}
