package com.budgetbook.feedback.controller

import com.budgetbook.feedback.dto.CreateReleaseNoteRequest
import com.budgetbook.feedback.dto.LinkFeedbackRequest
import com.budgetbook.feedback.dto.PublishRequest
import com.budgetbook.feedback.dto.ReleaseNoteDetailResponse
import com.budgetbook.feedback.dto.ReleaseNoteResponse
import com.budgetbook.feedback.dto.UpdateReleaseNoteRequest
import com.budgetbook.feedback.service.ReleaseNoteService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class AdminReleaseNoteControllerTest : FunSpec({

    val releaseNoteService = mockk<ReleaseNoteService>()
    val controller = AdminReleaseNoteController(releaseNoteService)
    val adminUserId = UUID.randomUUID()

    fun sampleResponse(version: String = "1.0.0", published: Boolean = false) = ReleaseNoteResponse(
        id = UUID.randomUUID(),
        version = version,
        title = "Release $version",
        content = "Content",
        isPublished = published,
        publishedAt = if (published) Instant.now() else null,
        createdBy = adminUserId,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    fun sampleDetailResponse() = ReleaseNoteDetailResponse(
        id = UUID.randomUUID(),
        version = "1.0.0",
        title = "Release",
        content = "Content",
        isPublished = false,
        publishedAt = null,
        createdBy = adminUserId,
        linkedFeedbacks = emptyList(),
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("createReleaseNote returns CREATED status") {
        val request = CreateReleaseNoteRequest("1.0.0", "First Release", "Content")
        every { releaseNoteService.createReleaseNote(adminUserId, request) } returns sampleResponse()

        val result = controller.createReleaseNote(adminUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.version shouldBe "1.0.0"
    }

    test("updateReleaseNote returns updated note") {
        val releaseId = UUID.randomUUID()
        val request = UpdateReleaseNoteRequest(title = "Updated Title")
        every { releaseNoteService.updateReleaseNote(releaseId, request) } returns
            sampleResponse().copy(title = "Updated Title")

        val result = controller.updateReleaseNote(releaseId, request)

        result.success shouldBe true
        result.data!!.title shouldBe "Updated Title"
    }

    test("deleteReleaseNote returns ok") {
        val releaseId = UUID.randomUUID()
        justRun { releaseNoteService.deleteReleaseNote(releaseId) }

        val result = controller.deleteReleaseNote(releaseId)

        result.success shouldBe true
        verify { releaseNoteService.deleteReleaseNote(releaseId) }
    }

    test("togglePublish publishes a release note") {
        val releaseId = UUID.randomUUID()
        val request = PublishRequest(publish = true)
        every { releaseNoteService.togglePublish(releaseId, request) } returns sampleResponse(published = true)

        val result = controller.togglePublish(releaseId, request)

        result.success shouldBe true
        result.data!!.isPublished shouldBe true
    }

    test("linkFeedbacks links feedbacks to release note") {
        val releaseId = UUID.randomUUID()
        val request = LinkFeedbackRequest(listOf(UUID.randomUUID(), UUID.randomUUID()))
        every { releaseNoteService.linkFeedbacks(releaseId, request) } returns sampleDetailResponse()

        val result = controller.linkFeedbacks(releaseId, request)

        result.success shouldBe true
    }
})
