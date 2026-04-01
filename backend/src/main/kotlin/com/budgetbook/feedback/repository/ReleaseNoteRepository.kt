package com.budgetbook.feedback.repository

import com.budgetbook.feedback.domain.ReleaseNote
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface ReleaseNoteRepository : JpaRepository<ReleaseNote, UUID> {

    fun findByIsPublishedTrueOrderByPublishedAtDesc(): List<ReleaseNote>

    fun findFirstByIsPublishedTrueOrderByPublishedAtDesc(): ReleaseNote?

    fun existsByVersion(version: String): Boolean
}
