package com.budgetbook.admin.service

import com.budgetbook.admin.domain.Announcement
import com.budgetbook.admin.dto.AdminUserDetailResponse
import com.budgetbook.admin.dto.AdminUserResponse
import com.budgetbook.admin.dto.AnnouncementResponse
import com.budgetbook.admin.dto.CreateAnnouncementRequest
import com.budgetbook.admin.dto.DeleteUserResult
import com.budgetbook.admin.dto.PagedResponse
import com.budgetbook.admin.dto.SystemStatsResponse
import com.budgetbook.admin.dto.UpdateAnnouncementRequest
import com.budgetbook.admin.repository.AnnouncementRepository
import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.domain.UserRole
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.transaction.repository.TransactionRepository
import jakarta.persistence.EntityManager
import org.slf4j.LoggerFactory
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
    private val announcementRepository: AnnouncementRepository,
    private val entityManager: EntityManager
) {

    private val logger = LoggerFactory.getLogger(AdminService::class.java)

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

    // --- User Hard Delete ---

    @Transactional
    fun deleteUserByEmail(requestAdminId: UUID, email: String, confirm: Boolean): DeleteUserResult {
        if (!confirm) throw BusinessException("DELETE_NOT_CONFIRMED", "Deletion must be explicitly confirmed (confirm=true)")

        // email 은 저장 시 lowercase 정규화를 하지 않으므로 trim 만 적용
        val normalizedEmail = email.trim()
        val user = userRepository.findByEmail(normalizedEmail)
            ?: throw NotFoundException("USER_NOT_FOUND", "User not found: $normalizedEmail")
        if (user.provider == AuthProvider.SYSTEM)
            throw BusinessException("CANNOT_DELETE_SYSTEM_ACCOUNT", "System account cannot be deleted")
        if (user.id == requestAdminId)
            throw BusinessException("CANNOT_DELETE_SELF", "Admin cannot delete their own account")
        // ADMIN 계정은 이 엔드포인트로 hard-delete 불가 (별도 절차 필요)
        if (user.role == UserRole.ADMIN)
            throw BusinessException("CANNOT_DELETE_ADMIN", "Admin accounts cannot be hard-deleted via this endpoint")

        // findAllByUserId 는 status 필터 없이 ACTIVE/DISSOLVED 모두 반환.
        // DISSOLVED 커플이라도 user2 가 타인이면 과거 공유 데이터가 남아 있어 단순 삭제 불가.
        val couples = coupleRepository.findAllByUserId(user.id)
        val hasPartner = couples.any { c ->
            val partnerId = if (c.user1.id == user.id) c.user2?.id else c.user1.id
            partnerId != null && partnerId != user.id
        }
        if (hasPartner)
            throw BusinessException(
                "COUPLE_HAS_PARTNER",
                "User has or had a partner (active or dissolved); shared-data deletion requires manual review"
            )

        val uid = user.id
        val coupleIds = couples.map { it.id }

        // 1) users 직접참조 NO ACTION 자식 선삭제 (couple CASCADE로 안 지워지는 것)
        execUid("DELETE FROM spending_plan_status_history WHERE changed_by = :uid", uid)
        execUid("DELETE FROM feedback_comments WHERE author_id = :uid", uid)
        execUid("DELETE FROM feedback_posts WHERE user_id = :uid", uid)
        execUid("UPDATE announcements SET created_by = NULL WHERE created_by = :uid", uid) // nullable: 공지 보존
        execUid("DELETE FROM release_notes WHERE created_by = :uid", uid)

        // 2) couple_id NO ACTION 자식 선삭제 후 couples 삭제 (CASCADE로 나머지 자동삭제)
        if (coupleIds.isNotEmpty()) {
            // 외부 입력 절대 금지 — 코드 상수만 사용. SQL injection 방지.
            COUPLE_SCOPED_NO_ACTION_TABLES.forEach { t ->
                entityManager.createNativeQuery("DELETE FROM $t WHERE couple_id IN (:cids)")
                    .setParameter("cids", coupleIds).executeUpdate()
            }
            entityManager.createNativeQuery("DELETE FROM couples WHERE id IN (:cids)")
                .setParameter("cids", coupleIds).executeUpdate()
        }

        // 3) users 삭제. 누락된 NO ACTION 자식이 있으면 여기서 FK 위반 → 트랜잭션 롤백(안전망)
        entityManager.createNativeQuery("DELETE FROM users WHERE id = :uid").setParameter("uid", uid).executeUpdate()
        entityManager.flush()
        // native DELETE 후 1차 캐시(persistence context)를 비워 stale 엔티티가 조회되는 것을 방지
        entityManager.clear()

        logger.warn("ADMIN_USER_DELETE admin={} deletedUser={} email={} couples={}", requestAdminId, uid, normalizedEmail, coupleIds)
        return DeleteUserResult(deletedUserId = uid, email = normalizedEmail, deletedCoupleIds = coupleIds, deletedAt = Instant.now())
    }

    private fun execUid(sql: String, uid: UUID) =
        entityManager.createNativeQuery(sql).setParameter("uid", uid).executeUpdate()

    companion object {
        // couple_id 참조에 ON DELETE NO ACTION 이 걸린 테이블 목록.
        // couples 삭제 전 반드시 이 순서대로 선삭제해야 FK 위반이 발생하지 않는다.
        // 외부 입력 절대 금지 — 코드 상수만.
        private val COUPLE_SCOPED_NO_ACTION_TABLES = listOf(
            "weekly_budget_settlements",
            "transfers",
            "spending_plans",
            "insurances",
            "couple_preferences"
        )
    }
}
