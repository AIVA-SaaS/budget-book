package com.budgetbook.admin.controller

import com.budgetbook.admin.dto.AnnouncementResponse
import com.budgetbook.admin.service.AdminService
import com.budgetbook.common.dto.ApiResponse
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/announcements")
class AnnouncementController(
    private val adminService: AdminService
) {

    @GetMapping("/active")
    fun getActiveAnnouncements(): ApiResponse<List<AnnouncementResponse>> {
        val result = adminService.getActiveAnnouncements()
        return ApiResponse.ok(result)
    }
}
