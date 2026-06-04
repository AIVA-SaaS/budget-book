package com.budgetbook.couple.service

import com.budgetbook.auth.domain.hasRealEmail
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
import com.budgetbook.couple.dto.InvitationStatusResponse
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.couple.repository.CoupleDataMigrationRepository
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
    private val redisCacheService: RedisCacheService,
    private val coupleDataMigrationRepository: CoupleDataMigrationRepository
) {

    private val log = LoggerFactory.getLogger(javaClass)

    // L1 Caffeine cache: userId -> coupleId
    private val coupleCaffeineCache = Caffeine.newBuilder()
        .maximumSize(1000)
        .expireAfterWrite(5, TimeUnit.MINUTES)
        .build<UUID, UUID>()

    /**
     * Creates a self-couple for a user (solo mode).
     * Called during user registration. Idempotent - skips if already exists.
     */
    @Transactional
    fun createSelfCouple(userId: UUID): Couple {
        val existing = coupleRepository.findActiveSelfCouple(userId)
        if (existing != null) {
            log.debug("Self-couple already exists for userId={}", userId)
            return existing
        }

        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val selfCouple = Couple(
            user1 = user,
            user2 = null,
            status = CoupleStatus.ACTIVE,
            isSelf = true
        )
        val saved = coupleRepository.save(selfCouple)

        // Seed default data for the self-couple
        categoryService.seedDefaultCategories(saved)
        categoryGroupService.seedDefaultCategoryGroups(saved)
        paymentMethodService.seedDefaultPaymentMethods(saved)

        // Seed private category groups and categories for the user
        val privateGroup = categoryGroupService.seedPrivateCategoryGroup(saved, user)
        categoryService.seedPrivateCategories(saved, user, privateGroup)

        log.info("Created self-couple id={} for userId={}", saved.id, userId)
        return saved
    }

    @Transactional
    fun createInvitation(userId: UUID): InvitationResponse {
        // Only block if user is in a real (non-self) couple
        val realCouple = coupleRepository.findRealCoupleByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        if (realCouple != null) {
            throw ConflictException("COUPLE_ALREADY_EXISTS", "User is already in an active couple.")
        }

        // Email gate: inviter must have a real email before linking a partner
        val inviter = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
        if (!inviter.hasRealEmail()) {
            throw BusinessException(
                "EMAIL_REQUIRED_FOR_COUPLE",
                "Email registration is required before linking a partner."
            )
        }

        // Cancel any existing pending invitations from this user
        coupleInvitationRepository.updateStatusByInviterIdAndStatus(
            userId, InvitationStatus.PENDING, InvitationStatus.CANCELLED
        )

        val code = generateInvitationCode()
        val expiresAt = Instant.now().plusSeconds(24 * 60 * 60) // 24 hours

        val invitation = CoupleInvitation(
            inviter = inviter,
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

        // Email gate: accepting user must have a real email before linking a partner
        if (!acceptingUser.hasRealEmail()) {
            throw BusinessException(
                "EMAIL_REQUIRED_FOR_COUPLE",
                "Email registration is required before linking a partner."
            )
        }

        // Check if accepting user is already in a real couple
        val activeCouple = coupleRepository.findRealCoupleByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
        if (activeCouple != null) {
            throw ConflictException("COUPLE_ALREADY_EXISTS", "User is already in an active couple.")
        }

        // Check if inviter is already in a real couple
        val inviterCouple = coupleRepository.findRealCoupleByUserIdAndStatus(invitation.inviter.id, CoupleStatus.ACTIVE)
        if (inviterCouple != null) {
            invitation.status = InvitationStatus.CANCELLED
            coupleInvitationRepository.save(invitation)
            throw ConflictException("COUPLE_ALREADY_EXISTS", "The inviter is already in an active couple.")
        }

        // Mark invitation as accepted
        invitation.status = InvitationStatus.ACCEPTED
        coupleInvitationRepository.save(invitation)

        // Find self-couples for both users (to migrate their data)
        val inviterSelfCouple = coupleRepository.findActiveSelfCouple(invitation.inviter.id)
        val acceptorSelfCouple = coupleRepository.findActiveSelfCouple(userId)

        // Use inviter's self-couple as the real couple base (promote it)
        // or create a new couple if inviter has no self-couple
        val couple: Couple
        if (inviterSelfCouple != null) {
            // Promote inviter's self-couple to a real couple
            inviterSelfCouple.user2 = acceptingUser
            inviterSelfCouple.isSelf = false
            couple = coupleRepository.save(inviterSelfCouple)
            // Data already belongs to this couple, no migration needed for inviter
        } else {
            // Create a new couple (shouldn't happen in normal flow, but handle gracefully)
            couple = Couple(
                user1 = invitation.inviter,
                user2 = acceptingUser,
                status = CoupleStatus.ACTIVE,
                isSelf = false
            )
            coupleRepository.save(couple)

            // Seed default data for the new couple
            categoryService.seedDefaultCategories(couple)
            categoryGroupService.seedDefaultCategoryGroups(couple)
            paymentMethodService.seedDefaultPaymentMethods(couple)

            // Seed PRIVATE data for inviter
            val inviterPrivateGroup = categoryGroupService.seedPrivateCategoryGroup(couple, invitation.inviter)
            categoryService.seedPrivateCategories(couple, invitation.inviter, inviterPrivateGroup)
        }

        // Migrate acceptor's data from self-couple to the real couple
        if (acceptorSelfCouple != null) {
            coupleDataMigrationRepository.migrateAllData(acceptorSelfCouple.id, couple.id)
            // Dissolve the acceptor's self-couple
            acceptorSelfCouple.status = CoupleStatus.DISSOLVED
            acceptorSelfCouple.dissolvedAt = Instant.now()
            coupleRepository.save(acceptorSelfCouple)
        } else {
            // No self-couple data to migrate, seed private data for acceptor
            val acceptorPrivateGroup = categoryGroupService.seedPrivateCategoryGroup(couple, acceptingUser)
            categoryService.seedPrivateCategories(couple, acceptingUser, acceptorPrivateGroup)
        }

        // Evict caches
        evictCoupleCache(invitation.inviter.id)
        evictCoupleCache(userId)

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

    @Transactional
    fun getMyInvitation(userId: UUID): InvitationStatusResponse {
        val invitation = coupleInvitationRepository.findTopByInviterIdOrderByCreatedAtDesc(userId)
            ?: throw NotFoundException("INVITATION_NOT_FOUND", "No invitation found for the user.")

        // If PENDING but expired, update to EXPIRED
        if (invitation.status == InvitationStatus.PENDING && invitation.expiresAt.isBefore(Instant.now())) {
            invitation.status = InvitationStatus.EXPIRED
            coupleInvitationRepository.save(invitation)
        }

        return InvitationStatusResponse(
            code = invitation.invitationCode,
            expiresAt = invitation.expiresAt,
            status = invitation.status.name
        )
    }

    @Transactional(readOnly = true)
    fun getMyCouple(userId: UUID): CoupleResponse {
        val couple = coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
            ?: throw NotFoundException("COUPLE_NOT_FOUND", "User is not currently in a couple.")

        // For self-couples, partner is null
        val partner = if (couple.isSelf) {
            null
        } else {
            val partnerUser = if (couple.user1.id == userId) couple.user2!! else couple.user1
            UserSummary(
                id = partnerUser.id,
                nickname = partnerUser.nickname,
                profileImageUrl = partnerUser.profileImageUrl
            )
        }

        return CoupleResponse(
            id = couple.id,
            partner = partner,
            isSelf = couple.isSelf,
            status = couple.status.name,
            createdAt = couple.createdAt,
            dissolvedAt = couple.dissolvedAt
        )
    }

    @Transactional
    fun dissolveCouple(userId: UUID) {
        // Only dissolve real couples, not self-couples
        val couple = coupleRepository.findRealCoupleByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
            ?: throw NotFoundException("COUPLE_NOT_FOUND", "User is not currently in an active couple.")

        val user2 = couple.user2

        // Create self-couples for both users FIRST (before splitting data)
        val user1SelfCouple = createSelfCouple(couple.user1.id)
        val user2SelfCouple = user2?.let { createSelfCouple(it.id) }

        // Split data: move user2's owned data to their new self-couple
        if (user2 != null && user2SelfCouple != null) {
            coupleDataMigrationRepository.splitDataByOwner(couple.id, user2SelfCouple.id, user2.id)
        }

        // Move remaining data (user1's + shared) to user1's self-couple
        coupleDataMigrationRepository.migrateAllData(couple.id, user1SelfCouple.id)

        // Delete couple_preferences for the dissolved couple
        coupleDataMigrationRepository.deleteCouplePreferences(couple.id)

        // Now dissolve the couple
        couple.status = CoupleStatus.DISSOLVED
        couple.dissolvedAt = Instant.now()
        coupleRepository.save(couple)

        // Evict couple cache for both users
        evictCoupleCache(couple.user1.id)
        user2?.let { evictCoupleCache(it.id) }
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
