package com.budgetbook.feedback.controller

import com.budgetbook.admin.dto.PagedResponse
import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackStatus
import com.budgetbook.feedback.dto.ChangeStatusRequest
import com.budgetbook.feedback.dto.CreateCommentRequest
import com.budgetbook.feedback.dto.FeedbackCommentResponse
import com.budgetbook.feedback.dto.FeedbackPostResponse
import com.budgetbook.feedback.dto.FeedbackStatsResponse
import com.budgetbook.feedback.dto.UpdateAdminNoteRequest
import com.budgetbook.feedback.service.FeedbackService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class AdminFeedbackControllerTest : FunSpec({

    val feedbackService = mockk<FeedbackService>()
    val controller = AdminFeedbackController(feedbackService)
    val adminUserId = UUID.randomUUID()

    fun samplePostResponse(status: FeedbackStatus = FeedbackStatus.SUBMITTED) = FeedbackPostResponse(
        id = UUID.randomUUID(),
        userId = UUID.randomUUID(),
        userNickname = "User",
        category = FeedbackCategory.BUG,
        title = "Test Bug",
        content = "Description",
        status = status,
        adminNote = null,
        resolvedReleaseId = null,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    test("listAllFeedbacks returns paginated results") {
        val pagedResponse = PagedResponse(
            content = listOf(samplePostResponse()),
            page = 0,
            size = 20,
            totalElements = 1,
            totalPages = 1
        )
        every { feedbackService.getAllFeedbacks(null, null, 0, 20) } returns pagedResponse

        val result = controller.listAllFeedbacks(null, null, 0, 20)

        result.success shouldBe true
        result.data!!.content.size shouldBe 1
        result.data!!.totalElements shouldBe 1
    }

    test("listAllFeedbacks with status filter") {
        val pagedResponse = PagedResponse(
            content = listOf(samplePostResponse(FeedbackStatus.IN_PROGRESS)),
            page = 0,
            size = 20,
            totalElements = 1,
            totalPages = 1
        )
        every {
            feedbackService.getAllFeedbacks(FeedbackStatus.IN_PROGRESS, null, 0, 20)
        } returns pagedResponse

        val result = controller.listAllFeedbacks(FeedbackStatus.IN_PROGRESS, null, 0, 20)

        result.success shouldBe true
        result.data!!.content[0].status shouldBe FeedbackStatus.IN_PROGRESS
    }

    test("changeStatus updates feedback status") {
        val feedbackId = UUID.randomUUID()
        val request = ChangeStatusRequest(FeedbackStatus.REVIEWING)
        every { feedbackService.changeStatus(feedbackId, request) } returns samplePostResponse(FeedbackStatus.REVIEWING)

        val result = controller.changeStatus(feedbackId, request)

        result.success shouldBe true
        result.data!!.status shouldBe FeedbackStatus.REVIEWING
    }

    test("addAdminComment returns CREATED status") {
        val feedbackId = UUID.randomUUID()
        val request = CreateCommentRequest("Admin reply")
        val commentResponse = FeedbackCommentResponse(
            id = UUID.randomUUID(),
            authorId = adminUserId,
            authorNickname = "Admin",
            content = "Admin reply",
            isAdminReply = true,
            createdAt = Instant.now()
        )
        every { feedbackService.addAdminComment(adminUserId, feedbackId, request) } returns commentResponse

        val result = controller.addAdminComment(adminUserId, feedbackId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.isAdminReply shouldBe true
    }

    test("updateAdminNote updates the note") {
        val feedbackId = UUID.randomUUID()
        val request = UpdateAdminNoteRequest("Internal note")
        every { feedbackService.updateAdminNote(feedbackId, "Internal note") } returns
            samplePostResponse().copy(adminNote = "Internal note")

        val result = controller.updateAdminNote(feedbackId, request)

        result.success shouldBe true
        result.data!!.adminNote shouldBe "Internal note"
    }

    test("getFeedbackStats returns statistics") {
        val stats = FeedbackStatsResponse(
            byCategory = mapOf(FeedbackCategory.BUG to 5L, FeedbackCategory.FEATURE to 3L),
            byStatus = mapOf(FeedbackStatus.SUBMITTED to 4L, FeedbackStatus.RESOLVED to 4L),
            total = 8L
        )
        every { feedbackService.getFeedbackStats() } returns stats

        val result = controller.getFeedbackStats()

        result.success shouldBe true
        result.data!!.total shouldBe 8L
        result.data!!.byCategory[FeedbackCategory.BUG] shouldBe 5L
    }
})
