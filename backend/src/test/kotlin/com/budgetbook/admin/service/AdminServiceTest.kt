package com.budgetbook.admin.service

import com.budgetbook.admin.domain.Announcement
import com.budgetbook.admin.dto.CreateAnnouncementRequest
import com.budgetbook.admin.dto.UpdateAnnouncementRequest
import com.budgetbook.admin.repository.AnnouncementRepository
import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.domain.UserRole
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import jakarta.persistence.EntityManager
import jakarta.persistence.Query
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.PageRequest
import java.time.Instant
import java.util.Optional
import java.util.UUID

class AdminServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val userRepository = mockk<UserRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val transactionRepository = mockk<TransactionRepository>()
    val announcementRepository = mockk<AnnouncementRepository>()
    val entityManager = mockk<EntityManager>(relaxed = true)

    val adminService = AdminService(userRepository, coupleRepository, transactionRepository, announcementRepository, entityManager)

    val adminUser = User(
        email = "admin@example.com",
        nickname = "Admin",
        provider = AuthProvider.GOOGLE,
        providerId = "google-admin",
        role = UserRole.ADMIN
    )

    val regularUser = User(
        email = "user@example.com",
        nickname = "TestUser",
        provider = AuthProvider.GOOGLE,
        providerId = "google-1"
    )

    val regularUser2 = User(
        email = "user2@example.com",
        nickname = "TestUser2",
        provider = AuthProvider.KAKAO,
        providerId = "kakao-2"
    )

    // --- listUsers ---

    Given("admin requests user list") {
        val users = listOf(regularUser, regularUser2)
        val page = PageImpl(users, PageRequest.of(0, 20), 2)

        When("without search query") {
            every { userRepository.findAllWithSearch(null, any()) } returns page

            val result = adminService.listUsers(0, 20, null)

            Then("returns all users") {
                result.content.size shouldBe 2
                result.totalElements shouldBe 2
                result.page shouldBe 0
            }
        }

        When("with search query") {
            val filtered = PageImpl(listOf(regularUser), PageRequest.of(0, 20), 1)
            every { userRepository.findAllWithSearch("user@", any()) } returns filtered

            val result = adminService.listUsers(0, 20, "user@")

            Then("returns filtered users") {
                result.content.size shouldBe 1
                result.content[0].email shouldBe "user@example.com"
            }
        }

        When("with blank search query") {
            every { userRepository.findAllWithSearch(null, any()) } returns page

            val result = adminService.listUsers(0, 20, "  ")

            Then("treats blank as null search") {
                result.content.size shouldBe 2
            }
        }
    }

    // --- getUserDetail ---

    Given("admin requests user detail") {
        val couple = Couple(user1 = regularUser, user2 = regularUser2, status = CoupleStatus.ACTIVE)

        When("user exists with couple") {
            every { userRepository.findById(regularUser.id) } returns Optional.of(regularUser)
            every { coupleRepository.findByUserIdAndStatus(regularUser.id, CoupleStatus.ACTIVE) } returns couple
            every { transactionRepository.countByCoupleId(couple.id) } returns 42L

            val result = adminService.getUserDetail(regularUser.id)

            Then("returns detail with couple info") {
                result.email shouldBe "user@example.com"
                result.coupleId shouldBe couple.id
                result.partnerNickname shouldBe "TestUser2"
                result.transactionCount shouldBe 42L
            }
        }

        When("user exists without couple") {
            every { userRepository.findById(regularUser.id) } returns Optional.of(regularUser)
            every { coupleRepository.findByUserIdAndStatus(regularUser.id, CoupleStatus.ACTIVE) } returns null

            val result = adminService.getUserDetail(regularUser.id)

            Then("returns detail without couple info") {
                result.coupleId shouldBe null
                result.partnerNickname shouldBe null
                result.transactionCount shouldBe 0L
            }
        }

        When("user does not exist") {
            val unknownId = UUID.randomUUID()
            every { userRepository.findById(unknownId) } returns Optional.empty()

            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    adminService.getUserDetail(unknownId)
                }
            }
        }
    }

    // --- deactivateUser ---

    Given("admin deactivates a user") {
        When("user is active") {
            val savedSlot = slot<User>()
            every { userRepository.findById(regularUser.id) } returns Optional.of(regularUser)
            every { userRepository.save(capture(savedSlot)) } answers { savedSlot.captured }

            val result = adminService.deactivateUser(regularUser.id)

            Then("user isActive becomes false") {
                result.isActive shouldBe false
                savedSlot.captured.isActive shouldBe false
            }
        }

        When("user is already inactive") {
            val inactiveUser = User(
                email = "inactive@example.com",
                nickname = "Inactive",
                provider = AuthProvider.GOOGLE,
                providerId = "google-inactive",
                isActive = false
            )
            every { userRepository.findById(inactiveUser.id) } returns Optional.of(inactiveUser)

            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    adminService.deactivateUser(inactiveUser.id)
                }.code shouldBe "USER_ALREADY_INACTIVE"
            }
        }

        When("user not found") {
            val unknownId = UUID.randomUUID()
            every { userRepository.findById(unknownId) } returns Optional.empty()

            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    adminService.deactivateUser(unknownId)
                }
            }
        }
    }

    // --- activateUser ---

    Given("admin activates a user") {
        When("user is inactive") {
            val inactiveUser = User(
                email = "inactive@example.com",
                nickname = "Inactive",
                provider = AuthProvider.GOOGLE,
                providerId = "google-inactive",
                isActive = false
            )
            val savedSlot = slot<User>()
            every { userRepository.findById(inactiveUser.id) } returns Optional.of(inactiveUser)
            every { userRepository.save(capture(savedSlot)) } answers { savedSlot.captured }

            val result = adminService.activateUser(inactiveUser.id)

            Then("user isActive becomes true") {
                result.isActive shouldBe true
                savedSlot.captured.isActive shouldBe true
            }
        }

        When("user is already active") {
            every { userRepository.findById(regularUser.id) } returns Optional.of(regularUser)

            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    adminService.activateUser(regularUser.id)
                }.code shouldBe "USER_ALREADY_ACTIVE"
            }
        }
    }

    // --- getSystemStats ---

    Given("admin requests system statistics") {
        When("data is available") {
            every { userRepository.count() } returns 100L
            every { coupleRepository.count() } returns 40L
            every { transactionRepository.count() } returns 5000L
            every { userRepository.countCreatedSince(any()) } returnsMany listOf(15L, 25L)
            every { transactionRepository.countDistinctAuthorsSince(any()) } returns 60L

            val result = adminService.getSystemStats()

            Then("returns correct stats") {
                result.totalUsers shouldBe 100L
                result.totalCouples shouldBe 40L
                result.totalTransactions shouldBe 5000L
                result.newUsersThisMonth shouldBe 15L
                result.newUsersLastMonth shouldBe 10L // 25 - 15
                result.activeUsersLast30Days shouldBe 60L
            }
        }
    }

    // --- Announcement CRUD ---

    Given("admin manages announcements") {
        val announcement = Announcement(
            title = "Test Announcement",
            content = "Test content",
            isActive = true,
            createdBy = adminUser
        )

        When("creating an announcement") {
            val savedSlot = slot<Announcement>()
            every { userRepository.findById(adminUser.id) } returns Optional.of(adminUser)
            every { announcementRepository.save(capture(savedSlot)) } answers { savedSlot.captured }

            val request = CreateAnnouncementRequest(title = "New Post", content = "Content here")
            val result = adminService.createAnnouncement(adminUser.id, request)

            Then("announcement is created") {
                result.title shouldBe "New Post"
                result.content shouldBe "Content here"
                result.isActive shouldBe true
            }
        }

        When("updating an announcement") {
            val savedSlot = slot<Announcement>()
            every { announcementRepository.findById(announcement.id) } returns Optional.of(announcement)
            every { announcementRepository.save(capture(savedSlot)) } answers { savedSlot.captured }

            val request = UpdateAnnouncementRequest(title = "Updated Title", isActive = false)
            val result = adminService.updateAnnouncement(announcement.id, request)

            Then("announcement is updated") {
                result.title shouldBe "Updated Title"
                result.isActive shouldBe false
            }
        }

        When("deleting an announcement") {
            every { announcementRepository.existsById(announcement.id) } returns true
            every { announcementRepository.deleteById(announcement.id) } returns Unit

            adminService.deleteAnnouncement(announcement.id)

            Then("delete is called") {
                verify { announcementRepository.deleteById(announcement.id) }
            }
        }

        When("deleting a non-existent announcement") {
            val unknownId = UUID.randomUUID()
            every { announcementRepository.existsById(unknownId) } returns false

            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    adminService.deleteAnnouncement(unknownId)
                }
            }
        }

        When("listing active announcements") {
            every { announcementRepository.findByIsActiveTrueOrderByCreatedAtDesc() } returns listOf(announcement)

            val result = adminService.getActiveAnnouncements()

            Then("returns active announcements") {
                result.size shouldBe 1
                result[0].isActive shouldBe true
            }
        }

        When("listing all announcements paginated") {
            val page = PageImpl(listOf(announcement), PageRequest.of(0, 20), 1)
            every { announcementRepository.findAllByOrderByCreatedAtDesc(any()) } returns page

            val result = adminService.listAnnouncements(0, 20)

            Then("returns paged announcements") {
                result.content.size shouldBe 1
                result.totalElements shouldBe 1
            }
        }

        When("getting a single announcement") {
            every { announcementRepository.findById(announcement.id) } returns Optional.of(announcement)

            val result = adminService.getAnnouncement(announcement.id)

            Then("returns the announcement") {
                result.id shouldBe announcement.id
                result.title shouldBe "Test Announcement"
            }
        }

        When("getting a non-existent announcement") {
            val unknownId = UUID.randomUUID()
            every { announcementRepository.findById(unknownId) } returns Optional.empty()

            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    adminService.getAnnouncement(unknownId)
                }
            }
        }
    }

    // --- deleteUserByEmail ---

    Given("admin requests hard delete of a user by email") {
        val nativeQuery = mockk<jakarta.persistence.Query>(relaxed = true)
        every { entityManager.createNativeQuery(any()) } returns nativeQuery
        every { nativeQuery.setParameter(any<String>(), any()) } returns nativeQuery
        every { nativeQuery.executeUpdate() } returns 0

        When("confirm is false") {
            Then("throws BusinessException DELETE_NOT_CONFIRMED") {
                shouldThrow<BusinessException> {
                    adminService.deleteUserByEmail(adminUser.id, "target@example.com", confirm = false)
                }.code shouldBe "DELETE_NOT_CONFIRMED"
            }
        }

        When("email does not exist") {
            every { userRepository.findByEmail("notfound@example.com") } returns null

            Then("throws NotFoundException USER_NOT_FOUND") {
                shouldThrow<NotFoundException> {
                    adminService.deleteUserByEmail(adminUser.id, "notfound@example.com", confirm = true)
                }.code shouldBe "USER_NOT_FOUND"
            }
        }

        When("target user has SYSTEM provider") {
            val systemUser = User(
                email = "system@internal",
                nickname = "System",
                provider = AuthProvider.SYSTEM,
                providerId = "system"
            )
            every { userRepository.findByEmail(systemUser.email) } returns systemUser

            Then("throws BusinessException CANNOT_DELETE_SYSTEM_ACCOUNT") {
                shouldThrow<BusinessException> {
                    adminService.deleteUserByEmail(adminUser.id, systemUser.email, confirm = true)
                }.code shouldBe "CANNOT_DELETE_SYSTEM_ACCOUNT"
            }
        }

        When("admin tries to delete their own account") {
            every { userRepository.findByEmail(adminUser.email) } returns adminUser

            Then("throws BusinessException CANNOT_DELETE_SELF") {
                shouldThrow<BusinessException> {
                    adminService.deleteUserByEmail(adminUser.id, adminUser.email, confirm = true)
                }.code shouldBe "CANNOT_DELETE_SELF"
            }
        }

        When("target user is another ADMIN account") {
            val anotherAdmin = User(
                email = "admin2@example.com",
                nickname = "Admin2",
                provider = AuthProvider.GOOGLE,
                providerId = "google-admin2",
                role = UserRole.ADMIN
            )
            every { userRepository.findByEmail(anotherAdmin.email) } returns anotherAdmin

            Then("throws BusinessException CANNOT_DELETE_ADMIN") {
                shouldThrow<BusinessException> {
                    adminService.deleteUserByEmail(adminUser.id, anotherAdmin.email, confirm = true)
                }.code shouldBe "CANNOT_DELETE_ADMIN"
            }
        }

        When("target user has a real partner in a ACTIVE couple") {
            val partner = User(
                email = "partner@example.com",
                nickname = "Partner",
                provider = AuthProvider.GOOGLE,
                providerId = "google-partner"
            )
            val realCouple = Couple(user1 = regularUser, user2 = partner, status = CoupleStatus.ACTIVE, isSelf = false)
            every { userRepository.findByEmail(regularUser.email) } returns regularUser
            every { coupleRepository.findAllByUserId(regularUser.id) } returns listOf(realCouple)

            Then("throws BusinessException COUPLE_HAS_PARTNER") {
                shouldThrow<BusinessException> {
                    adminService.deleteUserByEmail(adminUser.id, regularUser.email, confirm = true)
                }.code shouldBe "COUPLE_HAS_PARTNER"
            }
        }

        When("target user has a DISSOLVED couple with a real partner") {
            val partner = User(
                email = "partner@example.com",
                nickname = "Partner",
                provider = AuthProvider.GOOGLE,
                providerId = "google-partner"
            )
            val dissolvedCouple = Couple(
                user1 = regularUser,
                user2 = partner,
                status = CoupleStatus.DISSOLVED,
                isSelf = false
            )
            every { userRepository.findByEmail(regularUser.email) } returns regularUser
            every { coupleRepository.findAllByUserId(regularUser.id) } returns listOf(dissolvedCouple)

            Then("throws BusinessException COUPLE_HAS_PARTNER (shared-data safety guard)") {
                shouldThrow<BusinessException> {
                    adminService.deleteUserByEmail(adminUser.id, regularUser.email, confirm = true)
                }.code shouldBe "COUPLE_HAS_PARTNER"
            }
        }

        When("target user has only a self-couple (no partner)") {
            val selfCouple = Couple(user1 = regularUser, user2 = null, status = CoupleStatus.ACTIVE, isSelf = true)
            every { userRepository.findByEmail(regularUser.email) } returns regularUser
            every { coupleRepository.findAllByUserId(regularUser.id) } returns listOf(selfCouple)

            val result = adminService.deleteUserByEmail(adminUser.id, regularUser.email, confirm = true)

            Then("returns DeleteUserResult with correct fields") {
                result.deletedUserId shouldBe regularUser.id
                result.email shouldBe regularUser.email
                result.deletedCoupleIds shouldBe listOf(selfCouple.id)
                result.deletedAt shouldNotBe null
            }

            Then("entityManager native queries are executed") {
                verify(atLeast = 1) { entityManager.createNativeQuery(any()) }
                verify { entityManager.flush() }
                verify { entityManager.clear() }
            }
        }
    }
})
