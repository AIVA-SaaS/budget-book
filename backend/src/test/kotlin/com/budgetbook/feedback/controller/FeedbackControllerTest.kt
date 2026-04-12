package com.budgetbook.feedback.controller

import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackStatus
import com.budgetbook.feedback.dto.CreateCommentRequest
import com.budgetbook.feedback.dto.CreateFeedbackRequest
import com.budgetbook.feedback.dto.FeedbackCommentResponse
import com.budgetbook.feedback.dto.FeedbackDetailResponse
import com.budgetbook.feedback.dto.FeedbackPostResponse
import com.budgetbook.feedback.dto.PublicFeedbackResponse
import com.budgetbook.feedback.dto.VoteResponse
import com.budgetbook.feedback.service.FeedbackService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.PageRequest
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

    test("toggleVote returns vote result") {
        val feedbackId = UUID.randomUUID()
        every { feedbackService.toggleVote(feedbackId, testUserId) } returns VoteResponse(voted = true, voteCount = 1)

        val result = controller.toggleVote(testUserId, feedbackId)

        result.success shouldBe true
        result.data!!.voted shouldBe true
        result.data!!.voteCount shouldBe 1
    }

    test("toggleVote unvote returns updated result") {
        val feedbackId = UUID.randomUUID()
        every { feedbackService.toggleVote(feedbackId, testUserId) } returns VoteResponse(voted = false, voteCount = 0)

        val result = controller.toggleVote(testUserId, feedbackId)

        result.success shouldBe true
        result.data!!.voted shouldBe false
        result.data!!.voteCount shouldBe 0
    }

    test("getPublicFeedbacks returns paged results") {
        val publicFeedback = PublicFeedbackResponse(
            id = UUID.randomUUID(),
            category = FeedbackCategory.BUG,
            title = "Public Bug",
            contentPreview = "Bug description preview",
            status = FeedbackStatus.SUBMITTED,
            voteCount = 5,
            hasVoted = true,
            commentCount = 2,
            authorName = "TestUser",
            createdAt = Instant.now()
        )
        val page = PageImpl(listOf(publicFeedback), PageRequest.of(0, 20), 1L)
        every { feedbackService.getPublicFeedbacks(testUserId, "popular", null, null, 0, 20) } returns page

        val result = controller.getPublicFeedbacks(testUserId, "popular", null, null, 0, 20)

        result.success shouldBe true
        result.data!!.content.size shouldBe 1
        result.data!!.content[0].title shouldBe "Public Bug"
        result.data!!.content[0].hasVoted shouldBe true
    }

    test("getTopFeedbacks returns top voted feedbacks") {
        val topFeedback = PublicFeedbackResponse(
            id = UUID.randomUUID(),
            category = FeedbackCategory.FEATURE,
            title = "Top Feature",
            contentPreview = "Feature description",
            status = FeedbackStatus.SUBMITTED,
            voteCount = 20,
            hasVoted = false,
            commentCount = 0,
            authorName = "TestUser",
            createdAt = Instant.now()
        )
        every { feedbackService.getTopFeedbacks(testUserId) } returns listOf(topFeedback)

        val result = controller.getTopFeedbacks(testUserId)

        result.success shouldBe true
        result.data!!.size shouldBe 1
        result.data!![0].voteCount shouldBe 20
        result.data!![0].title shouldBe "Top Feature"
    }
})
