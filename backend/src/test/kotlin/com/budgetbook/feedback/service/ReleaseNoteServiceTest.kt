package com.budgetbook.feedback.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.domain.UserRole
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.feedback.domain.FeedbackCategory
import com.budgetbook.feedback.domain.FeedbackPost
import com.budgetbook.feedback.domain.ReleaseNote
import com.budgetbook.feedback.dto.CreateReleaseNoteRequest
import com.budgetbook.feedback.dto.LinkFeedbackRequest
import com.budgetbook.feedback.dto.PublishRequest
import com.budgetbook.feedback.dto.UpdateReleaseNoteRequest
import com.budgetbook.feedback.repository.FeedbackPostRepository
import com.budgetbook.feedback.repository.ReleaseNoteRepository
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
import java.time.Instant
import java.util.Optional
import java.util.UUID

class ReleaseNoteServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val releaseNoteRepository = mockk<ReleaseNoteRepository>()
    val feedbackPostRepository = mockk<FeedbackPostRepository>()
    val userRepository = mockk<UserRepository>()

    val service = ReleaseNoteService(releaseNoteRepository, feedbackPostRepository, userRepository)

    val adminUser = User(
        email = "admin@test.com",
        nickname = "Admin",
        provider = AuthProvider.GOOGLE,
        providerId = "g1",
        role = UserRole.ADMIN
    )
    val regularUser = User(
        email = "user@test.com",
        nickname = "User",
        provider = AuthProvider.GOOGLE,
        providerId = "g2"
    )

    // --- createReleaseNote ---

    Given("an admin wants to create a release note") {
        every { userRepository.findById(adminUser.id) } returns Optional.of(adminUser)

        When("version is unique") {
            every { releaseNoteRepository.existsByVersion("1.0.0") } returns false
            val noteSlot = slot<ReleaseNote>()
            every { releaseNoteRepository.save(capture(noteSlot)) } answers { noteSlot.captured }

            val result = service.createReleaseNote(
                adminUser.id,
                CreateReleaseNoteRequest("1.0.0", "First Release", "Initial release content")
            )

            Then("release note is created") {
                result.version shouldBe "1.0.0"
                result.title shouldBe "First Release"
                result.isPublished shouldBe false
                result.createdBy shouldBe adminUser.id
            }
        }

        When("version already exists") {
            every { releaseNoteRepository.existsByVersion("1.0.0") } returns true

            Then("ConflictException is thrown") {
                shouldThrow<ConflictException> {
                    service.createReleaseNote(
                        adminUser.id,
                        CreateReleaseNoteRequest("1.0.0", "Duplicate", "content")
                    )
                }
            }
        }
    }

    // --- updateReleaseNote ---

    Given("an admin wants to update a release note") {
        val note = ReleaseNote(
            version = "1.0.0",
            title = "Old Title",
            content = "Old content",
            createdBy = adminUser
        )
        every { releaseNoteRepository.findById(note.id) } returns Optional.of(note)
        every { releaseNoteRepository.save(any()) } answers { firstArg() }

        When("updating title only") {
            val result = service.updateReleaseNote(note.id, UpdateReleaseNoteRequest(title = "New Title"))

            Then("title is updated") {
                result.title shouldBe "New Title"
                result.version shouldBe "1.0.0"
            }
        }

        When("updating version to a new unique version") {
            every { releaseNoteRepository.existsByVersion("2.0.0") } returns false
            val result = service.updateReleaseNote(note.id, UpdateReleaseNoteRequest(version = "2.0.0"))

            Then("version is updated") {
                result.version shouldBe "2.0.0"
            }
        }

        When("updating version to an existing version") {
            every { releaseNoteRepository.existsByVersion("3.0.0") } returns true

            Then("ConflictException is thrown") {
                shouldThrow<ConflictException> {
                    service.updateReleaseNote(note.id, UpdateReleaseNoteRequest(version = "3.0.0"))
                }
            }
        }
    }

    // --- deleteReleaseNote ---

    Given("an admin wants to delete a release note") {
        val noteId = UUID.randomUUID()

        When("release note exists") {
            every { releaseNoteRepository.existsById(noteId) } returns true
            every { releaseNoteRepository.deleteById(noteId) } returns Unit

            service.deleteReleaseNote(noteId)

            Then("it is deleted") {
                verify { releaseNoteRepository.deleteById(noteId) }
            }
        }

        When("release note does not exist") {
            every { releaseNoteRepository.existsById(noteId) } returns false

            Then("NotFoundException is thrown") {
                shouldThrow<NotFoundException> {
                    service.deleteReleaseNote(noteId)
                }
            }
        }
    }

    // --- togglePublish ---

    Given("an admin wants to publish a release note") {
        val note = ReleaseNote(
            version = "1.0.0",
            title = "Release",
            content = "Content",
            createdBy = adminUser
        )
        every { releaseNoteRepository.findById(note.id) } returns Optional.of(note)
        every { releaseNoteRepository.save(any()) } answers { firstArg() }

        When("publishing") {
            val result = service.togglePublish(note.id, PublishRequest(publish = true))

            Then("note is published with timestamp") {
                result.isPublished shouldBe true
                result.publishedAt shouldNotBe null
            }
        }

        When("unpublishing") {
            note.isPublished = true
            note.publishedAt = Instant.now()

            val result = service.togglePublish(note.id, PublishRequest(publish = false))

            Then("note is unpublished") {
                result.isPublished shouldBe false
                result.publishedAt shouldBe null
            }
        }
    }

    // --- getPublishedReleaseNotes ---

    Given("there are published release notes") {
        val note1 = ReleaseNote(version = "1.0.0", title = "V1", content = "c1", createdBy = adminUser, isPublished = true)
        val note2 = ReleaseNote(version = "2.0.0", title = "V2", content = "c2", createdBy = adminUser, isPublished = true)
        every { releaseNoteRepository.findByIsPublishedTrueOrderByPublishedAtDesc() } returns listOf(note2, note1)

        When("user requests published notes") {
            val result = service.getPublishedReleaseNotes()

            Then("returns published notes sorted by publishedAt DESC") {
                result shouldHaveSize 2
                result[0].version shouldBe "2.0.0"
                result[1].version shouldBe "1.0.0"
            }
        }
    }

    // --- getLatestReleaseNote ---

    Given("there is a latest published release note") {
        val note = ReleaseNote(version = "2.0.0", title = "Latest", content = "c", createdBy = adminUser, isPublished = true)
        every { releaseNoteRepository.findFirstByIsPublishedTrueOrderByPublishedAtDesc() } returns note

        When("user requests latest") {
            val result = service.getLatestReleaseNote()

            Then("returns the latest note") {
                result shouldNotBe null
                result!!.version shouldBe "2.0.0"
            }
        }
    }

    Given("there are no published release notes") {
        every { releaseNoteRepository.findFirstByIsPublishedTrueOrderByPublishedAtDesc() } returns null

        When("user requests latest") {
            val result = service.getLatestReleaseNote()

            Then("returns null") {
                result shouldBe null
            }
        }
    }

    // --- linkFeedbacks ---

    Given("an admin wants to link feedbacks to a release note") {
        val note = ReleaseNote(version = "1.0.0", title = "Release", content = "c", createdBy = adminUser)
        val fb1 = FeedbackPost(user = regularUser, category = FeedbackCategory.BUG, title = "Bug1", content = "d1")
        val fb2 = FeedbackPost(user = regularUser, category = FeedbackCategory.FEATURE, title = "Feat1", content = "d2")

        every { releaseNoteRepository.findById(note.id) } returns Optional.of(note)
        every { releaseNoteRepository.save(any()) } answers { firstArg() }

        When("all feedback IDs are valid") {
            every { feedbackPostRepository.findAllById(listOf(fb1.id, fb2.id)) } returns listOf(fb1, fb2)
            every { feedbackPostRepository.saveAll(any<List<FeedbackPost>>()) } answers { firstArg() }

            val result = service.linkFeedbacks(note.id, LinkFeedbackRequest(listOf(fb1.id, fb2.id)))

            Then("feedbacks are linked") {
                result.linkedFeedbacks shouldHaveSize 2
                fb1.resolvedReleaseId shouldBe note.id
                fb2.resolvedReleaseId shouldBe note.id
            }
        }

        When("some feedback IDs are invalid") {
            val invalidId = UUID.randomUUID()
            every { feedbackPostRepository.findAllById(listOf(fb1.id, invalidId)) } returns listOf(fb1)

            Then("NotFoundException is thrown") {
                shouldThrow<NotFoundException> {
                    service.linkFeedbacks(note.id, LinkFeedbackRequest(listOf(fb1.id, invalidId)))
                }
            }
        }
    }
})
