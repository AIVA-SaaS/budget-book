package com.budgetbook.feedback.domain

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import jakarta.persistence.UniqueConstraint
import org.springframework.data.annotation.CreatedDate
import java.time.Instant
import java.util.UUID

@Entity
@Table(
    name = "feedback_votes",
    uniqueConstraints = [UniqueConstraint(columnNames = ["post_id", "user_id"])]
)
class FeedbackVote(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "post_id", nullable = false)
    val post: FeedbackPost,

    @Column(name = "user_id", nullable = false)
    val userId: UUID,

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now()
)
