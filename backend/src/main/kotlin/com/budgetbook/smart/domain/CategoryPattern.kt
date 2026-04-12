package com.budgetbook.smart.domain

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.Id
import jakarta.persistence.Table
import java.time.LocalDateTime
import java.util.UUID

@Entity
@Table(name = "category_patterns")
class CategoryPattern(
    @Id
    val id: UUID = UUID.randomUUID(),

    @Column(name = "couple_id", nullable = false)
    val coupleId: UUID,

    @Column(nullable = false, length = 100)
    val keyword: String,

    @Column(name = "category_id", nullable = false)
    val categoryId: UUID,

    @Column(nullable = false)
    var frequency: Int = 1,

    @Column(name = "last_used_at", nullable = false)
    var lastUsedAt: LocalDateTime = LocalDateTime.now(),

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: LocalDateTime = LocalDateTime.now()
)
