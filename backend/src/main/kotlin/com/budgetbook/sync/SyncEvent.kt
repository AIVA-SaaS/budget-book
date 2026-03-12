package com.budgetbook.sync

import java.time.Instant
import java.util.UUID

data class SyncEvent(
    val type: String,
    val entityType: String,
    val entityId: UUID,
    val coupleId: UUID,
    val authorId: UUID,
    val timestamp: Instant = Instant.now()
)
