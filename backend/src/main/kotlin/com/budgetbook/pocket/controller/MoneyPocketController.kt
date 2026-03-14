package com.budgetbook.pocket.controller

import com.budgetbook.common.dto.ApiResponse
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
import org.springframework.security.core.Authentication
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
    fun listPockets(authentication: Authentication): ApiResponse<List<PocketResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(moneyPocketService.getPockets(userId))
    }

    @PostMapping
    fun createPocket(
        authentication: Authentication,
        @Valid @RequestBody request: CreatePocketRequest
    ): ResponseEntity<ApiResponse<PocketResponse>> {
        val userId = authentication.principal as UUID
        val result = moneyPocketService.createPocket(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/{id}")
    fun updatePocket(
        authentication: Authentication,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdatePocketRequest
    ): ApiResponse<PocketResponse> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(moneyPocketService.updatePocket(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deletePocket(
        authentication: Authentication,
        @PathVariable id: UUID
    ): ResponseEntity<Void> {
        val userId = authentication.principal as UUID
        moneyPocketService.deletePocket(userId, id)
        return ResponseEntity.noContent().build()
    }

    @GetMapping("/distribution-ratios")
    fun getDistributionRatios(
        authentication: Authentication
    ): ApiResponse<List<DistributionRatioResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(distributionRatioService.getRatios(userId))
    }

    @PutMapping("/distribution-ratios")
    fun saveDistributionRatios(
        authentication: Authentication,
        @Valid @RequestBody request: SaveDistributionRatiosRequest
    ): ApiResponse<List<DistributionRatioResponse>> {
        val userId = authentication.principal as UUID
        return ApiResponse.ok(distributionRatioService.saveRatios(userId, request))
    }
}
