package com.budgetbook.feedback.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.domain.UserRole
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackComment
import com.budgetbook.feedback.domain.FeedbackPost
import com.budgetbook.feedback.domain.FeedbackStatus
import com.budgetbook.feedback.dto.ChangeStatusRequest
import com.budgetbook.feedback.dto.CreateCommentRequest
import com.budgetbook.feedback.dto.CreateFeedbackRequest
import com.budgetbook.feedback.repository.FeedbackCommentRepository
import com.budgetbook.feedback.repository.FeedbackPostRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.PageRequest
import java.util.Optional
import java.util.UUID

class FeedbackServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val feedbackPostRepository = mockk<FeedbackPostRepository>()
    val feedbackCommentRepository = mockk<FeedbackCommentRepository>()
    val userRepository = mockk<UserRepository>()

    val service = FeedbackService(feedbackPostRepository, feedbackCommentRepository, userRepository)

    val user = User(
        email = "user@test.com",
        nickname = "TestUser",
        provider = AuthProvider.GOOGLE,
        providerId = "g1"
    )
    val otherUser = User(
        email = "other@test.com",
        nickname = "OtherUser",
        provider = AuthProvider.KAKAO,
        providerId = "k1"
    )
    val adminUser = User(
        email = "admin@test.com",
        nickname = "Admin",
        provider = AuthProvider.GOOGLE,
        providerId = "g2",
        role = UserRole.ADMIN
    )

    // --- createFeedback ---

    Given("a user wants to create feedback") {
        every { userRepository.findById(user.id) } returns Optional.of(user)

        When("valid request is provided") {
            val request = CreateFeedbackRequest(
                title = "App crashes on login",
                content = "When I tap login, the app crashes",
                category = FeedbackCategory.BUG
            )
            val postSlot = slot<FeedbackPost>()
            every { feedbackPostRepository.save(capture(postSlot)) } answers { postSlot.captured }

            val result = service.createFeedback(user.id, request)

            Then("feedback is created successfully") {
                result.title shouldBe "App crashes on login"
                result.category shouldBe FeedbackCategory.BUG
                result.status shouldBe FeedbackStatus.SUBMITTED
                result.userId shouldBe user.id
                result.userNickname shouldBe "TestUser"
            }
        }

        When("user is not found") {
            val unknownUserId = UUID.randomUUID()
            every { userRepository.findById(unknownUserId) } returns Optional.empty()

            Then("NotFoundException is thrown") {
                shouldThrow<NotFoundException> {
                    service.createFeedback(unknownUserId, CreateFeedbackRequest("t", "c", FeedbackCategory.BUG))
                }
            }
        }
    }

    // --- getMyFeedbacks ---

    Given("a user has submitted feedbacks") {
        val post1 = FeedbackPost(user = user, category = FeedbackCategory.BUG, title = "Bug 1", content = "desc 1")
        val post2 = FeedbackPost(user = user, category = FeedbackCategory.FEATURE, title = "Feature 1", content = "desc 2")
        every { feedbackPostRepository.findByUserIdOrderByCreatedAtDesc(user.id) } returns listOf(post1, post2)

        When("user requests their feedbacks") {
            val result = service.getMyFeedbacks(user.id)

            Then("returns the user's feedbacks") {
                result shouldHaveSize 2
                result[0].title shouldBe "Bug 1"
                result[1].title shouldBe "Feature 1"
            }
        }
    }

    // --- getFeedbackDetail ---

    Given("a feedback post exists") {
        val post = FeedbackPost(user = user, category = FeedbackCategory.BUG, title = "Bug", content = "desc")
        every { feedbackPostRepository.findById(post.id) } returns Optional.of(post)

        When("the owner requests the detail") {
            val result = service.getFeedbackDetail(user.id, post.id)

            Then("returns the detail with comments") {
                result.title shouldBe "Bug"
                result.comments shouldHaveSize 0
            }
        }

        When("a different user requests the detail") {
            Then("ForbiddenException is thrown") {
                shouldThrow<ForbiddenException> {
                    service.getFeedbackDetail(otherUser.id, post.id)
                }
            }
        }
    }

    // --- addComment ---

    Given("a user wants to comment on their feedback") {
        val post = FeedbackPost(user = user, category = FeedbackCategory.BUG, title = "Bug", content = "desc")
        every { feedbackPostRepository.findById(post.id) } returns Optional.of(post)
        every { userRepository.findById(user.id) } returns Optional.of(user)
        every { feedbackPostRepository.save(any()) } answers { firstArg() }

        When("valid comment is provided") {
            val result = service.addComment(user.id, post.id, CreateCommentRequest("Additional info"))

            Then("comment is added") {
                result.content shouldBe "Additional info"
                result.isAdminReply shouldBe false
                result.authorNickname shouldBe "TestUser"
            }
        }

        When("a different user tries to comment") {
            Then("ForbiddenException is thrown") {
                shouldThrow<ForbiddenException> {
                    service.addComment(otherUser.id, post.id, CreateCommentRequest("Hacking attempt"))
                }
            }
        }
    }

    // --- changeStatus (admin) ---

    Given("an admin wants to change feedback status") {
        val post = FeedbackPost(user = user, category = FeedbackCategory.BUG, title = "Bug", content = "desc")
        every { feedbackPostRepository.findById(post.id) } returns Optional.of(post)
        every { feedbackPostRepository.save(any()) } answers { firstArg() }

        When("status is changed to IN_PROGRESS") {
            val result = service.changeStatus(post.id, ChangeStatusRequest(FeedbackStatus.IN_PROGRESS))

            Then("status is updated") {
                result.status shouldBe FeedbackStatus.IN_PROGRESS
            }
        }

        When("status is changed to REJECTED with reason") {
            val result = service.changeStatus(
                post.id,
                ChangeStatusRequest(FeedbackStatus.REJECTED, reason = "Duplicate")
            )

            Then("status and admin note are updated") {
                result.status shouldBe FeedbackStatus.REJECTED
                result.adminNote shouldBe "Duplicate"
            }
        }
    }

    // --- addAdminComment ---

    Given("an admin wants to reply to feedback") {
        val post = FeedbackPost(user = user, category = FeedbackCategory.FEATURE, title = "Feature", content = "desc")
        every { feedbackPostRepository.findById(post.id) } returns Optional.of(post)
        every { userRepository.findById(adminUser.id) } returns Optional.of(adminUser)
        every { feedbackPostRepository.save(any()) } answers { firstArg() }

        When("admin posts a reply") {
            val result = service.addAdminComment(adminUser.id, post.id, CreateCommentRequest("We will look into this."))

            Then("admin reply is created") {
                result.content shouldBe "We will look into this."
                result.isAdminReply shouldBe true
                result.authorNickname shouldBe "Admin"
            }
        }
    }

    // --- updateAdminNote ---

    Given("an admin wants to update internal note") {
        val post = FeedbackPost(user = user, category = FeedbackCategory.BUG, title = "Bug", content = "desc")
        every { feedbackPostRepository.findById(post.id) } returns Optional.of(post)
        every { feedbackPostRepository.save(any()) } answers { firstArg() }

        When("note is updated") {
            val result = service.updateAdminNote(post.id, "Internal: needs investigation")

            Then("admin note is set") {
                result.adminNote shouldBe "Internal: needs investigation"
            }
        }

        When("note is cleared") {
            val result = service.updateAdminNote(post.id, null)

            Then("admin note is null") {
                result.adminNote shouldBe null
            }
        }
    }

    // --- getAllFeedbacks (admin) ---

    Given("admin requests all feedbacks with filters") {
        val post = FeedbackPost(user = user, category = FeedbackCategory.BUG, title = "Bug", content = "desc")
        val page = PageImpl(listOf(post), PageRequest.of(0, 20), 1L)
        every {
            feedbackPostRepository.findAllWithFilters(FeedbackStatus.SUBMITTED, null, any())
        } returns page

        When("filtered by status") {
            val result = service.getAllFeedbacks(FeedbackStatus.SUBMITTED, null, 0, 20)

            Then("returns filtered results") {
                result.content shouldHaveSize 1
                result.totalElements shouldBe 1
            }
        }
    }

    // --- getFeedbackStats ---

    Given("admin requests feedback statistics") {
        FeedbackCategory.entries.forEach { cat ->
            every { feedbackPostRepository.countByCategory(cat) } returns if (cat == FeedbackCategory.BUG) 5L else 0L
        }
        FeedbackStatus.entries.forEach { status ->
            every { feedbackPostRepository.countByStatus(status) } returns if (status == FeedbackStatus.SUBMITTED) 3L else 0L
        }
        every { feedbackPostRepository.count() } returns 5L

        When("stats are requested") {
            val result = service.getFeedbackStats()

            Then("returns correct counts") {
                result.total shouldBe 5L
                result.byCategory[FeedbackCategory.BUG] shouldBe 5L
                result.byStatus[FeedbackStatus.SUBMITTED] shouldBe 3L
            }
        }
    }
})
