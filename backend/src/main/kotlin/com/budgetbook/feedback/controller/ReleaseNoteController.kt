package com.budgetbook.feedback.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.feedback.dto.ReleaseNoteDetailResponse
import com.budgetbook.feedback.dto.ReleaseNoteResponse
import com.budgetbook.feedback.service.ReleaseNoteService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/releases")
class ReleaseNoteController(
    private val releaseNoteService: ReleaseNoteService
) {

    @GetMapping
    fun getPublishedReleaseNotes(): ApiResponse<List<ReleaseNoteResponse>> {
        return ApiResponse.ok(releaseNoteService.getPublishedReleaseNotes())
    }

    @GetMapping("/{id}")
    fun getReleaseNoteDetail(
        @PathVariable id: UUID
    ): ApiResponse<ReleaseNoteDetailResponse> {
        return ApiResponse.ok(releaseNoteService.getReleaseNoteDetail(id))
    }

    @GetMapping("/latest")
    fun getLatestReleaseNote(): ApiResponse<ReleaseNoteResponse?> {
        return ApiResponse.ok(releaseNoteService.getLatestReleaseNote())
    }
}
