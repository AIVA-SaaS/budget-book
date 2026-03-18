package com.budgetbook.pocket.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.pocket.dto.CreatePocketRequest
import com.budgetbook.pocket.dto.DistributionRatioResponse
import com.budgetbook.pocket.dto.PocketResponse
import com.budgetbook.pocket.dto.SaveDistributionRatiosRequest
import com.budgetbook.pocket.dto.UpdatePocketRequest
import com.budgetbook.pocket.service.DistributionRatioService
import com.budgetbook.pocket.service.MoneyPocketService
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/pockets")
class MoneyPocketController(
    private val moneyPocketService: MoneyPocketService,
    private val distributionRatioService: DistributionRatioService
) {

    @GetMapping
    fun listPockets(@AuthUser userId: UUID): ApiResponse<List<PocketResponse>> {
        return ApiResponse.ok(moneyPocketService.getPockets(userId))
    }

    @PostMapping
    fun createPocket(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreatePocketRequest
    ): ResponseEntity<ApiResponse<PocketResponse>> {
        val result = moneyPocketService.createPocket(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/{id}")
    fun updatePocket(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdatePocketRequest
    ): ApiResponse<PocketResponse> {
        return ApiResponse.ok(moneyPocketService.updatePocket(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deletePocket(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        moneyPocketService.deletePocket(userId, id)
        return ResponseEntity.noContent().build()
    }

    @GetMapping("/distribution-ratios")
    fun getDistributionRatios(@AuthUser userId: UUID): ApiResponse<List<DistributionRatioResponse>> {
        return ApiResponse.ok(distributionRatioService.getRatios(userId))
    }

    @PutMapping("/distribution-ratios")
    fun saveDistributionRatios(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: SaveDistributionRatiosRequest
    ): ApiResponse<List<DistributionRatioResponse>> {
        return ApiResponse.ok(distributionRatioService.saveRatios(userId, request))
    }
}
