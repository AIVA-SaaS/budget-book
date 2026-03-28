package com.budgetbook.preference.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.preference.dto.FavoriteToggleRequest
import com.budgetbook.preference.dto.FavoritesRequest
import com.budgetbook.preference.dto.FavoritesResponse
import com.budgetbook.preference.service.PreferenceService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/preferences")
class PreferenceController(
    private val preferenceService: PreferenceService
) {

    @GetMapping("/favorites")
    fun getFavorites(@AuthUser userId: UUID): ApiResponse<FavoritesResponse> {
        return ApiResponse.ok(preferenceService.getFavorites(userId))
    }

    @PutMapping("/favorites")
    fun updateFavorites(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: FavoritesRequest
    ): ApiResponse<FavoritesResponse> {
        return ApiResponse.ok(preferenceService.updateFavorites(userId, request))
    }

    @PostMapping("/favorites/toggle")
    fun toggleFavorite(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: FavoriteToggleRequest
    ): ApiResponse<FavoritesResponse> {
        return ApiResponse.ok(preferenceService.toggleFavorite(userId, request))
    }
}
