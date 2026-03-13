package com.budgetbook.couple.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.service.CategoryGroupService
import com.budgetbook.category.service.CategoryService
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.paymentmethod.service.PaymentMethodService
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.GoneException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleInvitation
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.domain.InvitationStatus
import com.budgetbook.couple.dto.CoupleResponse
import com.budgetbook.couple.dto.InvitationResponse
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.couple.repository.CoupleInvitationRepository
import com.budgetbook.couple.repository.CoupleRepository
import com.github.benmanes.caffeine.cache.Caffeine
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Instant
import java.util.UUID
import java.util.concurrent.TimeUnit

@Service
class CoupleService(
    private val coupleRepository: CoupleRepository,
    private val coupleInvitationRepository: CoupleInvitationRepository,
    private val userRepository: UserRepository,
    private val categoryService: CategoryService,
    private val categoryGroupService: CategoryGroupService,
    private val paymentMethodService: PaymentMethodService,
    private val redisCacheService: RedisCacheService
) {

    private val log = LoggerFactory.getLogger(javaClass)

    // L1 Caffeine cache: userId -> coupleId
    private val coupleCaffeineCache = Caffeine.newBuilder()
        .maximumSize(1000)
        .expireAfterWrite(5, TimeUnit.MINUTES)
        .build<UUID, UUID>()

    @Transactional
    fun createInvitation(userId: UUID): InvitationResponse {
        val activeCouple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        if (activeCouple != null) {
            throw ConflictException("COUPLE_ALREADY_EXISTS", "User is already in an active couple.")
        }

        // Cancel any existing pending invitations from this user
        coupleInvitationRepository.updateStatusByInviterIdAndStatus(
            userId, InvitationStatus.PENDING, InvitationStatus.CANCELLED
        )

        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val code = generateInvitationCode()
        val expiresAt = Instant.now().plusSeconds(24 * 60 * 60) // 24 hours

        val invitation = CoupleInvitation(
            inviter = user,
            invitationCode = code,
            expiresAt = expiresAt
        )
        coupleInvitationRepository.save(invitation)

        return InvitationResponse(code = code, expiresAt = expiresAt)
    }

    @Transactional
    fun acceptInvitation(userId: UUID, code: String): CoupleResponse {
        val invitation = coupleInvitationRepository.findByInvitationCode(code)
            ?: throw NotFoundException("INVITATION_NOT_FOUND", "Invitation code does not exist.")

        if (invitation.status != InvitationStatus.PENDING) {
            throw NotFoundException("INVITATION_NOT_FOUND", "Invitation code does not exist.")
        }

        if (invitation.expiresAt.isBefore(Instant.now())) {
            invitation.status = InvitationStatus.EXPIRED
            coupleInvitationRepository.save(invitation)
            throw GoneException("INVITATION_EXPIRED", "Invitation code has expired.")
        }

        if (invitation.inviter.id == userId) {
            throw BusinessException("SELF_INVITATION", "User cannot accept their own invitation.")
        }

        val acceptingUser = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        // Check if accepting user is already in a couple
        val activeCouple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        if (activeCouple != null) {
            throw ConflictException("COUPLE_ALREADY_EXISTS", "User is already in an active couple.")
        }

        // Check if inviter is already in a couple (may have paired with someone else)
        val inviterCouple = coupleRepository.findByUserIdAndStatus(invitation.inviter.id, CoupleStatus.ACTIVE)
        if (inviterCouple != null) {
            invitation.status = InvitationStatus.CANCELLED
            coupleInvitationRepository.save(invitation)
            throw ConflictException("COUPLE_ALREADY_EXISTS", "The inviter is already in an active couple.")
        }

        // Mark invitation as accepted
        invitation.status = InvitationStatus.ACCEPTED
        coupleInvitationRepository.save(invitation)

        // Create the couple
        val couple = Couple(
            user1 = invitation.inviter,
            user2 = acceptingUser,
            status = CoupleStatus.ACTIVE
        )
        coupleRepository.save(couple)

        // Seed default data for the new couple (order matters: categories first, then groups that reference them)
        categoryService.seedDefaultCategories(couple)
        categoryGroupService.seedDefaultCategoryGroups(couple)
        paymentMethodService.seedDefaultPaymentMethods(couple)

        val partner = invitation.inviter
        return CoupleResponse(
            id = couple.id,
            partner = UserSummary(
                id = partner.id,
                nickname = partner.nickname,
                profileImageUrl = partner.profileImageUrl
            ),
            status = couple.status.name,
            createdAt = couple.createdAt,
            dissolvedAt = couple.dissolvedAt
        )
    }

    @Transactional(readOnly = true)
    fun getMyCouple(userId: UUID): CoupleResponse {
        val couple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
            ?: throw NotFoundException("COUPLE_NOT_FOUND", "User is not currently in a couple.")

        val partner = if (couple.user1.id == userId) couple.user2!! else couple.user1
        return CoupleResponse(
            id = couple.id,
            partner = UserSummary(
                id = partner.id,
                nickname = partner.nickname,
                profileImageUrl = partner.profileImageUrl
            ),
            status = couple.status.name,
            createdAt = couple.createdAt,
            dissolvedAt = couple.dissolvedAt
        )
    }

    @Transactional
    fun dissolveCouple(userId: UUID) {
        val couple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
            ?: throw NotFoundException("COUPLE_NOT_FOUND", "User is not currently in an active couple.")

        couple.status = CoupleStatus.DISSOLVED
        couple.dissolvedAt = Instant.now()
        coupleRepository.save(couple)

        // Evict couple cache for both users
        evictCoupleCache(couple.user1.id)
        couple.user2?.let { evictCoupleCache(it.id) }
    }

    fun evictCoupleCache(userId: UUID) {
        coupleCaffeineCache.invalidate(userId)
        redisCacheService.evict("couple:$userId")
        log.debug("Evicted couple cache for userId={}", userId)
    }

    private fun generateInvitationCode(): String {
        val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return (1..8).map { chars.random() }.joinToString("")
    }
}
