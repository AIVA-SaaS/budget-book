package com.budgetbook.feedback.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.feedback.dto.CreateReleaseNoteRequest
import com.budgetbook.feedback.dto.LinkFeedbackRequest
import com.budgetbook.feedback.dto.PublishRequest
import com.budgetbook.feedback.dto.ReleaseNoteDetailResponse
import com.budgetbook.feedback.dto.ReleaseNoteResponse
import com.budgetbook.feedback.dto.UpdateReleaseNoteRequest
import com.budgetbook.feedback.service.ReleaseNoteService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/admin/releases")
class AdminReleaseNoteController(
    private val releaseNoteService: ReleaseNoteService
) {

    @PostMapping
    fun createReleaseNote(
        @AuthUser adminUserId: UUID,
        @Valid @RequestBody request: CreateReleaseNoteRequest
    ): ResponseEntity<ApiResponse<ReleaseNoteResponse>> {
        val result = releaseNoteService.createReleaseNote(adminUserId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/{id}")
    fun updateReleaseNote(
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateReleaseNoteRequest
    ): ApiResponse<ReleaseNoteResponse> {
        return ApiResponse.ok(releaseNoteService.updateReleaseNote(id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteReleaseNote(
        @PathVariable id: UUID
    ): ApiResponse<Unit> {
        releaseNoteService.deleteReleaseNote(id)
        return ApiResponse.ok()
    }

    @PatchMapping("/{id}/publish")
    fun togglePublish(
        @PathVariable id: UUID,
        @RequestBody request: PublishRequest
    ): ApiResponse<ReleaseNoteResponse> {
        return ApiResponse.ok(releaseNoteService.togglePublish(id, request))
    }

    @PostMapping("/{id}/link-feedback")
    fun linkFeedbacks(
        @PathVariable id: UUID,
        @RequestBody request: LinkFeedbackRequest
    ): ApiResponse<ReleaseNoteDetailResponse> {
        return ApiResponse.ok(releaseNoteService.linkFeedbacks(id, request))
    }
}
