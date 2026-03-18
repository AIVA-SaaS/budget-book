package com.budgetbook.admin.controller

import com.budgetbook.admin.dto.AdminUserDetailResponse
import com.budgetbook.admin.dto.AdminUserResponse
import com.budgetbook.admin.dto.AnnouncementResponse
import com.budgetbook.admin.dto.CreateAnnouncementRequest
import com.budgetbook.admin.dto.PagedResponse
import com.budgetbook.admin.dto.SystemStatsResponse
import com.budgetbook.admin.dto.UpdateAnnouncementRequest
import com.budgetbook.admin.service.AdminService
import com.budgetbook.common.exception.NotFoundException
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class AdminControllerTest : FunSpec({

    val adminService = mockk<AdminService>()
    val controller = AdminController(adminService)

    val adminUserId = UUID.randomUUID()

    // --- User Management ---

    test("listUsers returns paginated users") {
        val users = listOf(
            AdminUserResponse(UUID.randomUUID(), "user@test.com", "User", null, "GOOGLE", "USER", true, Instant.now(), Instant.now())
        )
        val paged = PagedResponse(users, 0, 20, 1, 1)
        every { adminService.listUsers(0, 20, null) } returns paged

        val result = controller.listUsers(0, 20, null)

        result.success shouldBe true
        result.data!!.content.size shouldBe 1
        result.data!!.totalElements shouldBe 1
    }

    test("listUsers with search returns filtered users") {
        val paged = PagedResponse<AdminUserResponse>(emptyList(), 0, 20, 0, 0)
        every { adminService.listUsers(0, 20, "search") } returns paged

        val result = controller.listUsers(0, 20, "search")

        result.success shouldBe true
        result.data!!.content.size shouldBe 0
    }

    test("getUserDetail returns user with couple info") {
        val userId = UUID.randomUUID()
        val detail = AdminUserDetailResponse(
            id = userId,
            email = "user@test.com",
            nickname = "User",
            profileImageUrl = null,
            provider = "GOOGLE",
            role = "USER",
            isActive = true,
            coupleId = UUID.randomUUID(),
            partnerNickname = "Partner",
            transactionCount = 10,
            createdAt = Instant.now(),
            updatedAt = Instant.now()
        )
        every { adminService.getUserDetail(userId) } returns detail

        val result = controller.getUserDetail(userId)

        result.success shouldBe true
        result.data!!.transactionCount shouldBe 10
        result.data!!.partnerNickname shouldBe "Partner"
    }

    test("deactivateUser returns updated user") {
        val userId = UUID.randomUUID()
        val response = AdminUserResponse(userId, "user@test.com", "User", null, "GOOGLE", "USER", false, Instant.now(), Instant.now())
        every { adminService.deactivateUser(userId) } returns response

        val result = controller.deactivateUser(userId)

        result.success shouldBe true
        result.data!!.isActive shouldBe false
    }

    test("activateUser returns updated user") {
        val userId = UUID.randomUUID()
        val response = AdminUserResponse(userId, "user@test.com", "User", null, "GOOGLE", "USER", true, Instant.now(), Instant.now())
        every { adminService.activateUser(userId) } returns response

        val result = controller.activateUser(userId)

        result.success shouldBe true
        result.data!!.isActive shouldBe true
    }

    // --- System Statistics ---

    test("getSystemStats returns all statistics") {
        val stats = SystemStatsResponse(
            totalUsers = 100,
            totalCouples = 40,
            totalTransactions = 5000,
            newUsersThisMonth = 15,
            newUsersLastMonth = 10,
            activeUsersLast30Days = 60
        )
        every { adminService.getSystemStats() } returns stats

        val result = controller.getSystemStats()

        result.success shouldBe true
        result.data!!.totalUsers shouldBe 100
        result.data!!.activeUsersLast30Days shouldBe 60
    }

    // --- Announcements ---

    test("listAnnouncements returns paginated announcements") {
        val announcements = listOf(
            AnnouncementResponse(UUID.randomUUID(), "Title", "Content", true, adminUserId, Instant.now(), Instant.now())
        )
        val paged = PagedResponse(announcements, 0, 20, 1, 1)
        every { adminService.listAnnouncements(0, 20) } returns paged

        val result = controller.listAnnouncements(0, 20)

        result.success shouldBe true
        result.data!!.content.size shouldBe 1
    }

    test("getAnnouncement returns single announcement") {
        val announcementId = UUID.randomUUID()
        val response = AnnouncementResponse(announcementId, "Title", "Content", true, adminUserId, Instant.now(), Instant.now())
        every { adminService.getAnnouncement(announcementId) } returns response

        val result = controller.getAnnouncement(announcementId)

        result.success shouldBe true
        result.data!!.title shouldBe "Title"
    }

    test("createAnnouncement returns 201 with created announcement") {
        val request = CreateAnnouncementRequest(title = "New", content = "Body")
        val response = AnnouncementResponse(UUID.randomUUID(), "New", "Body", true, adminUserId, Instant.now(), Instant.now())
        every { adminService.createAnnouncement(adminUserId, request) } returns response

        val result = controller.createAnnouncement(adminUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.data!!.title shouldBe "New"
    }

    test("updateAnnouncement returns updated announcement") {
        val announcementId = UUID.randomUUID()
        val request = UpdateAnnouncementRequest(title = "Updated")
        val response = AnnouncementResponse(announcementId, "Updated", "Content", true, adminUserId, Instant.now(), Instant.now())
        every { adminService.updateAnnouncement(announcementId, request) } returns response

        val result = controller.updateAnnouncement(announcementId, request)

        result.success shouldBe true
        result.data!!.title shouldBe "Updated"
    }

    test("deleteAnnouncement returns success") {
        val announcementId = UUID.randomUUID()
        justRun { adminService.deleteAnnouncement(announcementId) }

        val result = controller.deleteAnnouncement(announcementId)

        result.success shouldBe true
        verify { adminService.deleteAnnouncement(announcementId) }
    }
})
