package com.budgetbook.feedback.controller

import com.budgetbook.feedback.dto.ReleaseNoteDetailResponse
import com.budgetbook.feedback.dto.ReleaseNoteResponse
import com.budgetbook.feedback.service.ReleaseNoteService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.time.Instant
import java.util.UUID

class ReleaseNoteControllerTest : FunSpec({

    val releaseNoteService = mockk<ReleaseNoteService>()
    val controller = ReleaseNoteController(releaseNoteService)

    fun sampleResponse(version: String = "1.0.0") = ReleaseNoteResponse(
        id = UUID.randomUUID(),
        version = version,
        title = "Release $version",
        content = "Content for $version",
        isPublished = true,
        publishedAt = Instant.now(),
        createdBy = UUID.randomUUID(),
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    fun sampleDetailResponse() = ReleaseNoteDetailResponse(
        id = UUID.randomUUID(),
        version = "1.0.0",
        title = "Release 1.0.0",
        content = "Content",
        isPublished = true,
        publishedAt = Instant.now(),
        createdBy = UUID.randomUUID(),
        linkedFeedbacks = emptyList(),
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("getPublishedReleaseNotes returns list") {
        val notes = listOf(sampleResponse("2.0.0"), sampleResponse("1.0.0"))
        every { releaseNoteService.getPublishedReleaseNotes() } returns notes

        val result = controller.getPublishedReleaseNotes()

        result.success shouldBe true
        result.data!!.size shouldBe 2
        result.data!![0].version shouldBe "2.0.0"
    }

    test("getReleaseNoteDetail returns detail with linked feedbacks") {
        val releaseId = UUID.randomUUID()
        every { releaseNoteService.getReleaseNoteDetail(releaseId) } returns sampleDetailResponse()

        val result = controller.getReleaseNoteDetail(releaseId)

        result.success shouldBe true
        result.data!!.version shouldBe "1.0.0"
        result.data!!.linkedFeedbacks shouldBe emptyList()
    }

    test("getLatestReleaseNote returns latest when exists") {
        every { releaseNoteService.getLatestReleaseNote() } returns sampleResponse("2.0.0")

        val result = controller.getLatestReleaseNote()

        result.success shouldBe true
        result.data!!.version shouldBe "2.0.0"
    }

    test("getLatestReleaseNote returns null data when no published notes") {
        every { releaseNoteService.getLatestReleaseNote() } returns null

        val result = controller.getLatestReleaseNote()

        result.success shouldBe true
        result.data shouldBe null
    }
})
