package com.budgetbook.insurance.controller

import com.budgetbook.common.dto.ApiResponse
import com.budgetbook.common.security.AuthUser
import com.budgetbook.insurance.dto.CreateInsuranceRequest
import com.budgetbook.insurance.dto.InsuranceResponse
import com.budgetbook.insurance.dto.InsuranceSummaryResponse
import com.budgetbook.insurance.dto.UpdateInsuranceRequest
import com.budgetbook.insurance.service.InsuranceService
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
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1/insurances")
class InsuranceController(
    private val insuranceService: InsuranceService
) {

    @GetMapping
    fun listInsurances(
        @AuthUser userId: UUID,
        @RequestParam(required = false) active: Boolean?
    ): ApiResponse<List<InsuranceResponse>> {
        return ApiResponse.ok(insuranceService.listInsurances(userId, active))
    }

    @PostMapping
    fun createInsurance(
        @AuthUser userId: UUID,
        @Valid @RequestBody request: CreateInsuranceRequest
    ): ResponseEntity<ApiResponse<InsuranceResponse>> {
        val result = insuranceService.createInsurance(userId, request)
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok(result))
    }

    @PutMapping("/{id}")
    fun updateInsurance(
        @AuthUser userId: UUID,
        @PathVariable id: UUID,
        @Valid @RequestBody request: UpdateInsuranceRequest
    ): ApiResponse<InsuranceResponse> {
        return ApiResponse.ok(insuranceService.updateInsurance(userId, id, request))
    }

    @DeleteMapping("/{id}")
    fun deleteInsurance(
        @AuthUser userId: UUID,
        @PathVariable id: UUID
    ): ApiResponse<Unit> {
        insuranceService.deleteInsurance(userId, id)
        return ApiResponse.ok()
    }

    @GetMapping("/summary")
    fun getInsuranceSummary(
        @AuthUser userId: UUID,
        @RequestParam year: Int,
        @RequestParam month: Int
    ): ApiResponse<InsuranceSummaryResponse> {
        return ApiResponse.ok(insuranceService.getInsuranceSummary(userId, year, month))
    }
}
