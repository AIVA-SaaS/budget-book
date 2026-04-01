package com.budgetbook.feedback.domain

import com.budgetbook.auth.domain.User
import com.budgetbook.common.entity.BaseTimeEntity
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.JoinTable
import jakarta.persistence.ManyToMany
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.time.Instant
import java.util.UUID

@Entity
@Table(name = "release_notes")
class ReleaseNote(
    @Id
    val id: UUID = UUID.randomUUID(),

    @Column(nullable = false, length = 20)
    var version: String,

    @Column(nullable = false, length = 200)
    var title: String,

    @Column(nullable = false, columnDefinition = "TEXT")
    var content: String,

    @Column(name = "is_published", nullable = false)
    var isPublished: Boolean = false,

    @Column(name = "published_at")
    var publishedAt: Instant? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by", nullable = false)
    val createdBy: User,

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
        name = "release_note_feedbacks",
        joinColumns = [JoinColumn(name = "release_note_id")],
        inverseJoinColumns = [JoinColumn(name = "feedback_post_id")]
    )
    val linkedFeedbacks: MutableSet<FeedbackPost> = mutableSetOf()
) : BaseTimeEntity()
