package com.budgetbook.admin.dto

import com.budgetbook.admin.domain.Announcement
import com.budgetbook.auth.domain.User
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant
import java.util.UUID

// --- User Management DTOs ---

data class AdminUserResponse(
    val id: UUID,
    val email: String,
    val nickname: String,
    val profileImageUrl: String?,
    val provider: String,
    val role: String,
    val isActive: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant
) {
    companion object {
        fun from(user: User): AdminUserResponse = AdminUserResponse(
            id = user.id,
            email = user.email,
            nickname = user.nickname,
            profileImageUrl = user.profileImageUrl,
            provider = user.provider.name,
            role = user.role.name,
            isActive = user.isActive,
            createdAt = user.createdAt,
            updatedAt = user.updatedAt
        )
    }
}

data class AdminUserDetailResponse(
    val id: UUID,
    val email: String,
    val nickname: String,
    val profileImageUrl: String?,
    val provider: String,
    val role: String,
    val isActive: Boolean,
    val coupleId: UUID?,
    val partnerNickname: String?,
    val transactionCount: Long,
    val createdAt: Instant,
    val updatedAt: Instant
)

data class PagedResponse<T>(
    val content: List<T>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int
)

// --- System Statistics DTOs ---

data class SystemStatsResponse(
    val totalUsers: Long,
    val totalCouples: Long,
    val totalTransactions: Long,
    val newUsersThisMonth: Long,
    val newUsersLastMonth: Long,
    val activeUsersLast30Days: Long
)

// --- Announcement DTOs ---

data class CreateAnnouncementRequest(
    @field:NotBlank(message = "Title is required")
    @field:Size(max = 200, message = "Title must be 200 characters or less")
    val title: String,

    @field:NotBlank(message = "Content is required")
    val content: String,

    val isActive: Boolean = true
)

data class UpdateAnnouncementRequest(
    @field:Size(max = 200, message = "Title must be 200 characters or less")
    val title: String? = null,

    val content: String? = null,

    val isActive: Boolean? = null
)

data class AnnouncementResponse(
    val id: UUID,
    val title: String,
    val content: String,
    val isActive: Boolean,
    val createdBy: UUID?,
    val createdAt: Instant,
    val updatedAt: Instant
) {
    companion object {
        fun from(announcement: Announcement): AnnouncementResponse = AnnouncementResponse(
            id = announcement.id,
            title = announcement.title,
            content = announcement.content,
            isActive = announcement.isActive,
            createdBy = announcement.createdBy?.id,
            createdAt = announcement.createdAt,
            updatedAt = announcement.updatedAt
        )
    }
}
