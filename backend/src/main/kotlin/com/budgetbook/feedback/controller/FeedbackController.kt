package com.budgetbook.feedback.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.ratelimit.RateLimit
import com.budgetbook.common.security.AuthUser
import com.budgetbook.feedback.dto.CreateCommentRequest
import com.budgetbook.feedback.dto.CreateFeedbackRequest
import com.budgetbook.feedback.dto.FeedbackCommentResponse
import com.budgetbook.feedback.dto.FeedbackDetailResponse
import com.budgetbook.feedback.dto.FeedbackPostResponse
import com.budgetbook.feedback.service.FeedbackService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
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
}
