package com.budgetbook.feedback.controller

import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackStatus
import com.budgetbook.feedback.dto.CreateCommentRequest
import com.budgetbook.feedback.dto.CreateFeedbackRequest
import com.budgetbook.feedback.dto.FeedbackCommentResponse
import com.budgetbook.feedback.dto.FeedbackDetailResponse
import com.budgetbook.feedback.dto.FeedbackPostResponse
import com.budgetbook.feedback.service.FeedbackService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class FeedbackControllerTest : FunSpec({

    val feedbackService = mockk<FeedbackService>()
    val controller = FeedbackController(feedbackService)
    val testUserId = UUID.randomUUID()

    fun samplePostResponse(title: String = "Test Bug") = FeedbackPostResponse(
        id = UUID.randomUUID(),
        userId = testUserId,
        userNickname = "TestUser",
        category = FeedbackCategory.BUG,
        title = title,
        content = "Bug description",
        status = FeedbackStatus.SUBMITTED,
        adminNote = null,
        resolvedReleaseId = null,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    fun sampleDetailResponse() = FeedbackDetailResponse(
        id = UUID.randomUUID(),
        userId = testUserId,
        userNickname = "TestUser",
        category = FeedbackCategory.BUG,
        title = "Test Bug",
        content = "Bug description",
        status = FeedbackStatus.SUBMITTED,
        adminNote = null,
        resolvedReleaseId = null,
        comments = emptyList(),
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    fun sampleCommentResponse() = FeedbackCommentResponse(
        id = UUID.randomUUID(),
        authorId = testUserId,
        authorNickname = "TestUser",
        content = "Additional info",
        isAdminReply = false,
        createdAt = Instant.now()
    )

    test("getMyFeedbacks returns user feedbacks") {
        val feedbacks = listOf(samplePostResponse("Bug 1"), samplePostResponse("Bug 2"))
        every { feedbackService.getMyFeedbacks(testUserId) } returns feedbacks

        val result = controller.getMyFeedbacks(testUserId)

        result.success shouldBe true
        result.data!!.size shouldBe 2
    }

    test("createFeedback returns CREATED status") {
        val request = CreateFeedbackRequest("Bug", "Description", FeedbackCategory.BUG)
        every { feedbackService.createFeedback(testUserId, request) } returns samplePostResponse()

        val result = controller.createFeedback(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.category shouldBe FeedbackCategory.BUG
    }

    test("getFeedbackDetail returns detail with comments") {
        val feedbackId = UUID.randomUUID()
        every { feedbackService.getFeedbackDetail(testUserId, feedbackId) } returns sampleDetailResponse()

        val result = controller.getFeedbackDetail(testUserId, feedbackId)

        result.success shouldBe true
        result.data!!.title shouldBe "Test Bug"
    }

    test("addComment returns CREATED status") {
        val feedbackId = UUID.randomUUID()
        val request = CreateCommentRequest("Additional info")
        every { feedbackService.addComment(testUserId, feedbackId, request) } returns sampleCommentResponse()

        val result = controller.addComment(testUserId, feedbackId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.content shouldBe "Additional info"
    }
})
