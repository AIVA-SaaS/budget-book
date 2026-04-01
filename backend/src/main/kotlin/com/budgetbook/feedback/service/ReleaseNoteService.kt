package com.budgetbook.feedback.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.feedback.domain.ReleaseNote
import com.budgetbook.feedback.dto.CreateReleaseNoteRequest
import com.budgetbook.feedback.dto.LinkFeedbackRequest
import com.budgetbook.feedback.dto.PublishRequest
import com.budgetbook.feedback.dto.ReleaseNoteDetailResponse
import com.budgetbook.feedback.dto.ReleaseNoteResponse
import com.budgetbook.feedback.dto.UpdateReleaseNoteRequest
import com.budgetbook.feedback.repository.FeedbackPostRepository
import com.budgetbook.feedback.repository.ReleaseNoteRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant
import java.util.UUID

@Service
class ReleaseNoteService(
    private val releaseNoteRepository: ReleaseNoteRepository,
    private val feedbackPostRepository: FeedbackPostRepository,
    private val userRepository: UserRepository
) {

    // --- User Operations ---

    @Transactional(readOnly = true)
    fun getPublishedReleaseNotes(): List<ReleaseNoteResponse> {
        return releaseNoteRepository.findByIsPublishedTrueOrderByPublishedAtDesc()
            .map { ReleaseNoteResponse.from(it) }
    }

    @Transactional(readOnly = true)
    fun getReleaseNoteDetail(releaseId: UUID): ReleaseNoteDetailResponse {
        val note = releaseNoteRepository.findById(releaseId)
            .orElseThrow { NotFoundException("RELEASE_NOTE_NOT_FOUND", "Release note not found: $releaseId") }

        return ReleaseNoteDetailResponse.from(note)
    }

    @Transactional(readOnly = true)
    fun getLatestReleaseNote(): ReleaseNoteResponse? {
        return releaseNoteRepository.findFirstByIsPublishedTrueOrderByPublishedAtDesc()
            ?.let { ReleaseNoteResponse.from(it) }
    }

    // --- Admin Operations ---

    @Transactional
    fun createReleaseNote(adminUserId: UUID, request: CreateReleaseNoteRequest): ReleaseNoteResponse {
        if (releaseNoteRepository.existsByVersion(request.version)) {
            throw ConflictException("VERSION_ALREADY_EXISTS", "Release note with version '${request.version}' already exists.")
        }

        val admin = userRepository.findById(adminUserId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "Admin user not found: $adminUserId") }

        val note = ReleaseNote(
            version = request.version,
            title = request.title,
            content = request.content,
            createdBy = admin
        )

        return ReleaseNoteResponse.from(releaseNoteRepository.save(note))
    }

    @Transactional
    fun updateReleaseNote(releaseId: UUID, request: UpdateReleaseNoteRequest): ReleaseNoteResponse {
        val note = releaseNoteRepository.findById(releaseId)
            .orElseThrow { NotFoundException("RELEASE_NOTE_NOT_FOUND", "Release note not found: $releaseId") }

        request.version?.let { newVersion ->
            if (newVersion != note.version && releaseNoteRepository.existsByVersion(newVersion)) {
                throw ConflictException("VERSION_ALREADY_EXISTS", "Release note with version '$newVersion' already exists.")
            }
            note.version = newVersion
        }
        request.title?.let { note.title = it }
        request.content?.let { note.content = it }

        return ReleaseNoteResponse.from(releaseNoteRepository.save(note))
    }

    @Transactional
    fun deleteReleaseNote(releaseId: UUID) {
        if (!releaseNoteRepository.existsById(releaseId)) {
            throw NotFoundException("RELEASE_NOTE_NOT_FOUND", "Release note not found: $releaseId")
        }
        releaseNoteRepository.deleteById(releaseId)
    }

    @Transactional
    fun togglePublish(releaseId: UUID, request: PublishRequest): ReleaseNoteResponse {
        val note = releaseNoteRepository.findById(releaseId)
            .orElseThrow { NotFoundException("RELEASE_NOTE_NOT_FOUND", "Release note not found: $releaseId") }

        note.isPublished = request.publish
        note.publishedAt = if (request.publish) Instant.now() else null

        return ReleaseNoteResponse.from(releaseNoteRepository.save(note))
    }

    @Transactional
    fun linkFeedbacks(releaseId: UUID, request: LinkFeedbackRequest): ReleaseNoteDetailResponse {
        val note = releaseNoteRepository.findById(releaseId)
            .orElseThrow { NotFoundException("RELEASE_NOTE_NOT_FOUND", "Release note not found: $releaseId") }

        val feedbackPosts = feedbackPostRepository.findAllById(request.feedbackPostIds)
        if (feedbackPosts.size != request.feedbackPostIds.size) {
            val foundIds = feedbackPosts.map { it.id }.toSet()
            val missingIds = request.feedbackPostIds.filter { it !in foundIds }
            throw NotFoundException("FEEDBACK_NOT_FOUND", "Feedback posts not found: $missingIds")
        }

        note.linkedFeedbacks.clear()
        note.linkedFeedbacks.addAll(feedbackPosts)

        // Update resolved_release_id on linked feedbacks
        feedbackPosts.forEach { it.resolvedReleaseId = note.id }
        feedbackPostRepository.saveAll(feedbackPosts)

        return ReleaseNoteDetailResponse.from(releaseNoteRepository.save(note))
    }
}
