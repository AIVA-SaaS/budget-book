package com.budgetbook.feedback.controller

import com.budgetbook.admin.dto.PagedResponse
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackStatus
import com.budgetbook.feedback.dto.ChangeStatusRequest
import com.budgetbook.feedback.dto.CreateCommentRequest
import com.budgetbook.feedback.dto.FeedbackCommentResponse
import com.budgetbook.feedback.dto.FeedbackPostResponse
import com.budgetbook.feedback.dto.FeedbackStatsResponse
import com.budgetbook.feedback.dto.UpdateAdminNoteRequest
import com.budgetbook.feedback.service.FeedbackService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/admin/feedback")
class AdminFeedbackController(
    private val feedbackService: FeedbackService
) {

    @GetMapping
    fun listAllFeedbacks(
        @RequestParam(required = false) status: FeedbackStatus?,
        @RequestParam(required = false) category: FeedbackCategory?,
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): ApiResponse<PagedResponse<FeedbackPostResponse>> {
        return ApiResponse.ok(feedbackService.getAllFeedbacks(status, category, page, size))
    }

    @PatchMapping("/{id}/status")
    fun changeStatus(
        @PathVariable id: UUID,
        @Valid @RequestBody request: ChangeStatusRequest
    ): ApiResponse<FeedbackPostResponse> {
        return ApiResponse.ok(feedbackService.changeStatus(id, request))
    }

    @PostMapping("/{id}/comments")
    fun addAdminComment(
        @AuthUser adminUserId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: CreateCommentRequest
    ): ResponseEntity<ApiResponse<FeedbackCommentResponse>> {
        val result = feedbackService.addAdminComment(adminUserId, id, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PatchMapping("/{id}/note")
    fun updateAdminNote(
        @PathVariable id: UUID,
        @RequestBody request: UpdateAdminNoteRequest
    ): ApiResponse<FeedbackPostResponse> {
        return ApiResponse.ok(feedbackService.updateAdminNote(id, request.note))
    }

    @GetMapping("/stats")
    fun getFeedbackStats(): ApiResponse<FeedbackStatsResponse> {
        return ApiResponse.ok(feedbackService.getFeedbackStats())
    }
}
