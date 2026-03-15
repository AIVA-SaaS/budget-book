package com.budgetbook.admin.service

import com.budgetbook.admin.domain.Announcement
import com.budgetbook.admin.dto.AdminUserDetailResponse
import com.budgetbook.admin.dto.AdminUserResponse
import com.budgetbook.admin.dto.AnnouncementResponse
import com.budgetbook.admin.dto.CreateAnnouncementRequest
import com.budgetbook.admin.dto.PagedResponse
import com.budgetbook.admin.dto.SystemStatsResponse
import com.budgetbook.admin.dto.UpdateAnnouncementRequest
import com.budgetbook.admin.repository.AnnouncementRepository
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant
import java.time.YearMonth
import java.time.ZoneOffset
import java.util.UUID

@Service
class AdminService(
    private val userRepository: UserRepository,
    private val coupleRepository: CoupleRepository,
    private val transactionRepository: TransactionRepository,
    private val announcementRepository: AnnouncementRepository
) {

    // --- User Management ---

    @Transactional(readOnly = true)
    fun listUsers(page: Int, size: Int, search: String?): PagedResponse<AdminUserResponse> {
        val pageable = PageRequest.of(page, size)
        val searchTerm = if (search.isNullOrBlank()) null else search
        val result = userRepository.findAllWithSearch(searchTerm, pageable)

        return PagedResponse(
            content = result.content.map { AdminUserResponse.from(it) },
            page = result.number,
            size = result.size,
            totalElements = result.totalElements,
            totalPages = result.totalPages
        )
    }

    @Transactional(readOnly = true)
    fun getUserDetail(userId: UUID): AdminUserDetailResponse {
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found: $userId") }

        val couple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        val partnerNickname = couple?.let {
            if (it.user1.id == userId) it.user2?.nickname else it.user1.nickname
        }
        val transactionCount = if (couple != null) {
            transactionRepository.countByCoupleId(couple.id)
        } else {
            0L
        }

        return AdminUserDetailResponse(
            id = user.id,
            email = user.email,
            nickname = user.nickname,
            profileImageUrl = user.profileImageUrl,
            provider = user.provider.name,
            role = user.role.name,
            isActive = user.isActive,
            coupleId = couple?.id,
            partnerNickname = partnerNickname,
            transactionCount = transactionCount,
            createdAt = user.createdAt,
            updatedAt = user.updatedAt
        )
    }

    @Transactional
    fun deactivateUser(userId: UUID): AdminUserResponse {
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found: $userId") }

        if (!user.isActive) {
            throw BusinessException("USER_ALREADY_INACTIVE", "User is already inactive")
        }

        user.isActive = false
        return AdminUserResponse.from(userRepository.save(user))
    }

    @Transactional
    fun activateUser(userId: UUID): AdminUserResponse {
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found: $userId") }

        if (user.isActive) {
            throw BusinessException("USER_ALREADY_ACTIVE", "User is already active")
        }

        user.isActive = true
        return AdminUserResponse.from(userRepository.save(user))
    }

    // --- System Statistics ---

    @Transactional(readOnly = true)
    fun getSystemStats(): SystemStatsResponse {
        val now = YearMonth.now()
        val thisMonthStart = now.atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC)
        val lastMonthStart = now.minusMonths(1).atDay(1).atStartOfDay().toInstant(ZoneOffset.UTC)
        val thirtyDaysAgo = Instant.now().minusSeconds(30L * 24 * 60 * 60)

        val totalUsers = userRepository.count()
        val totalCouples = coupleRepository.count()
        val totalTransactions = transactionRepository.count()
        val newUsersThisMonth = userRepository.countCreatedSince(thisMonthStart)
        val newUsersLastMonth = userRepository.countCreatedSince(lastMonthStart) - newUsersThisMonth
        val activeUsersLast30Days = transactionRepository.countDistinctAuthorsSince(thirtyDaysAgo)

        return SystemStatsResponse(
            totalUsers = totalUsers,
            totalCouples = totalCouples,
            totalTransactions = totalTransactions,
            newUsersThisMonth = newUsersThisMonth,
            newUsersLastMonth = newUsersLastMonth,
            activeUsersLast30Days = activeUsersLast30Days
        )
    }

    // --- Announcements ---

    @Transactional(readOnly = true)
    fun listAnnouncements(page: Int, size: Int): PagedResponse<AnnouncementResponse> {
        val pageable = PageRequest.of(page, size)
        val result = announcementRepository.findAllByOrderByCreatedAtDesc(pageable)

        return PagedResponse(
            content = result.content.map { AnnouncementResponse.from(it) },
            page = result.number,
            size = result.size,
            totalElements = result.totalElements,
            totalPages = result.totalPages
        )
    }

    @Transactional(readOnly = true)
    fun getActiveAnnouncements(): List<AnnouncementResponse> {
        return announcementRepository.findByIsActiveTrueOrderByCreatedAtDesc()
            .map { AnnouncementResponse.from(it) }
    }

    @Transactional
    fun createAnnouncement(adminUserId: UUID, request: CreateAnnouncementRequest): AnnouncementResponse {
        val admin = userRepository.findById(adminUserId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "Admin user not found: $adminUserId") }

        val announcement = Announcement(
            title = request.title,
            content = request.content,
            isActive = request.isActive,
            createdBy = admin
        )

        return AnnouncementResponse.from(announcementRepository.save(announcement))
    }

    @Transactional
    fun updateAnnouncement(announcementId: UUID, request: UpdateAnnouncementRequest): AnnouncementResponse {
        val announcement = announcementRepository.findById(announcementId)
            .orElseThrow { NotFoundException("ANNOUNCEMENT_NOT_FOUND", "Announcement not found: $announcementId") }

        request.title?.let { announcement.title = it }
        request.content?.let { announcement.content = it }
        request.isActive?.let { announcement.isActive = it }

        return AnnouncementResponse.from(announcementRepository.save(announcement))
    }

    @Transactional
    fun deleteAnnouncement(announcementId: UUID) {
        if (!announcementRepository.existsById(announcementId)) {
            throw NotFoundException("ANNOUNCEMENT_NOT_FOUND", "Announcement not found: $announcementId")
        }
        announcementRepository.deleteById(announcementId)
    }

    @Transactional(readOnly = true)
    fun getAnnouncement(announcementId: UUID): AnnouncementResponse {
        val announcement = announcementRepository.findById(announcementId)
            .orElseThrow { NotFoundException("ANNOUNCEMENT_NOT_FOUND", "Announcement not found: $announcementId") }
        return AnnouncementResponse.from(announcement)
    }
}
