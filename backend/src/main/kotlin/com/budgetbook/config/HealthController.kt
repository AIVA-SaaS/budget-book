package com.budgetbook.config

import com.budgetbook.common.dto.ApiResponse
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RestController

@RestController
class HealthController {

    @GetMapping("/api/v1/health")
    fun health(): ApiResponse<Map<String, String>> {
        return ApiResponse.ok(
            mapOf(
                "status" to "UP",
                "service" to "budget-book-api"
            )
        )
    }
}
