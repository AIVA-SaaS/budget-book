package com.budgetbook.admin.controller

import com.budgetbook.admin.dto.AnnouncementResponse
import com.budgetbook.admin.service.AdminService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.time.Instant
import java.util.UUID

class AnnouncementControllerTest : FunSpec({

    val adminService = mockk<AdminService>()
    val controller = AnnouncementController(adminService)

    test("getActiveAnnouncements returns active announcements without auth") {
        val announcements = listOf(
            AnnouncementResponse(UUID.randomUUID(), "Active Post", "Content", true, UUID.randomUUID(), Instant.now(), Instant.now())
        )
        every { adminService.getActiveAnnouncements() } returns announcements

        val result = controller.getActiveAnnouncements()

        result.success shouldBe true
        result.data!!.size shouldBe 1
        result.data!![0].title shouldBe "Active Post"
    }

    test("getActiveAnnouncements returns empty list when no active announcements") {
        every { adminService.getActiveAnnouncements() } returns emptyList()

        val result = controller.getActiveAnnouncements()

        result.success shouldBe true
        result.data!!.size shouldBe 0
    }
})
