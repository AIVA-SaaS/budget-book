package com.budgetbook.admin.controller

import com.budgetbook.admin.dto.AdminUserDetailResponse
import com.budgetbook.admin.dto.AdminUserResponse
import com.budgetbook.admin.dto.AnnouncementResponse
import com.budgetbook.admin.dto.CreateAnnouncementRequest
import com.budgetbook.admin.dto.PagedResponse
import com.budgetbook.admin.dto.SystemStatsResponse
import com.budgetbook.admin.dto.UpdateAnnouncementRequest
import com.budgetbook.admin.service.AdminService
import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PatchMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/admin")
class AdminController(
    private val adminService: AdminService
) {

    // --- User Management ---

    @GetMapping("/users")
    fun listUsers(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
        @RequestParam(required = false) search: String?
    ): ApiResponse<PagedResponse<AdminUserResponse>> {
        val result = adminService.listUsers(page, size, search)
        return ApiResponse.ok(result)
    }

    @GetMapping("/users/{userId}")
    fun getUserDetail(
        @PathVariable userId: UUID
    ): ApiResponse<AdminUserDetailResponse> {
        val result = adminService.getUserDetail(userId)
        return ApiResponse.ok(result)
    }

    @PatchMapping("/users/{userId}/deactivate")
    fun deactivateUser(
        @PathVariable userId: UUID
    ): ApiResponse<AdminUserResponse> {
        val result = adminService.deactivateUser(userId)
        return ApiResponse.ok(result)
    }

    @PatchMapping("/users/{userId}/activate")
    fun activateUser(
        @PathVariable userId: UUID
    ): ApiResponse<AdminUserResponse> {
        val result = adminService.activateUser(userId)
        return ApiResponse.ok(result)
    }

    // --- System Statistics ---

    @GetMapping("/stats")
    fun getSystemStats(): ApiResponse<SystemStatsResponse> {
        val result = adminService.getSystemStats()
        return ApiResponse.ok(result)
    }

    // --- Announcements ---

    @GetMapping("/announcements")
    fun listAnnouncements(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): ApiResponse<PagedResponse<AnnouncementResponse>> {
        val result = adminService.listAnnouncements(page, size)
        return ApiResponse.ok(result)
    }

    @GetMapping("/announcements/{announcementId}")
    fun getAnnouncement(
        @PathVariable announcementId: UUID
    ): ApiResponse<AnnouncementResponse> {
        val result = adminService.getAnnouncement(announcementId)
        return ApiResponse.ok(result)
    }

    @PostMapping("/announcements")
    fun createAnnouncement(
        @AuthUser adminUserId: UUID,
        @Valid @RequestBody request: CreateAnnouncementRequest
    ): ResponseEntity<ApiResponse<AnnouncementResponse>> {
        val result = adminService.createAnnouncement(adminUserId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/announcements/{announcementId}")
    fun updateAnnouncement(
        @PathVariable announcementId: UUID,
        @Valid @RequestBody request: UpdateAnnouncementRequest
    ): ApiResponse<AnnouncementResponse> {
        val result = adminService.updateAnnouncement(announcementId, request)
        return ApiResponse.ok(result)
    }

    @DeleteMapping("/announcements/{announcementId}")
    fun deleteAnnouncement(
        @PathVariable announcementId: UUID
    ): ApiResponse<Unit> {
        adminService.deleteAnnouncement(announcementId)
        return ApiResponse.ok()
    }
}
