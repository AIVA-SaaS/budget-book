package com.budgetbook.spendingplan.controller

import com.budgetbook.spendingplan.domain.SpendingPlanFrequency
import com.budgetbook.spendingplan.domain.SpendingPlanStatus
import com.budgetbook.spendingplan.dto.CompleteSpendingPlanRequest
import com.budgetbook.spendingplan.dto.CreateSpendingPlanRequest
import com.budgetbook.spendingplan.dto.SpendingPlanListResponse
import com.budgetbook.spendingplan.dto.SpendingPlanResponse
import com.budgetbook.spendingplan.dto.SpendingPlanSuggestion
import com.budgetbook.spendingplan.dto.SpendingPlanSummary
import com.budgetbook.spendingplan.dto.UpdateSpendingPlanRequest
import com.budgetbook.spendingplan.service.SpendingPlanService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

class SpendingPlanControllerTest : FunSpec({

    val service = mockk<SpendingPlanService>()
    val controller = SpendingPlanController(service)
    val testUserId = UUID.randomUUID()

    fun samplePlanResponse(name: String = "Test Plan", amount: Long = 100000) = SpendingPlanResponse(
        id = UUID.randomUUID(),
        coupleId = UUID.randomUUID(),
        authorId = testUserId,
        authorNickname = "User",
        name = name,
        amount = amount,
        targetDate = LocalDate.of(2026, 3, 29),
        memo = null,
        category = null,
        paymentMethod = null,
        budgetId = null,
        linkedTransactionId = null,
        status = "PLANNED",
        actualAmount = null,
        completedDate = null,
        variance = null,
        varianceRate = null,
        isRecurring = false,
        frequency = null,
        recurringSourceId = null,
        visibility = "SHARED",
        ownerId = null,
        createdAt = Instant.now(),
        updatedAt = Instant.now()
    )

    fun sampleListResponse() = SpendingPlanListResponse(
        plans = listOf(samplePlanResponse()),
        summary = SpendingPlanSummary(
            totalPlanned = 100000,
            totalCompleted = 0,
            totalSkipped = 0,
            plannedCount = 1,
            completedCount = 0,
            skippedCount = 0,
            overdueCount = 0
        )
    )

    test("listPlans returns plans with summary") {
        every { service.listPlans(testUserId, any(), any(), null) } returns sampleListResponse()

        val result = controller.listPlans(
            testUserId,
            LocalDate.of(2026, 3, 1),
            LocalDate.of(2026, 3, 31),
            null
        )

        result.success shouldBe true
        result.data!!.plans.size shouldBe 1
        result.data!!.summary.plannedCount shouldBe 1
    }

    test("listPlans with status filter") {
        every {
            service.listPlans(testUserId, any(), any(), SpendingPlanStatus.PLANNED)
        } returns sampleListResponse()

        val result = controller.listPlans(
            testUserId,
            LocalDate.of(2026, 3, 1),
            LocalDate.of(2026, 3, 31),
            SpendingPlanStatus.PLANNED
        )

        result.success shouldBe true
    }

    test("createPlan returns 201") {
        val request = CreateSpendingPlanRequest(
            name = "New plan",
            amount = 150000,
            targetDate = LocalDate.of(2026, 3, 29)
        )
        every { service.createPlan(testUserId, request) } returns samplePlanResponse("New plan", 150000)

        val result = controller.createPlan(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.name shouldBe "New plan"
    }

    test("updatePlan returns updated plan") {
        val planId = UUID.randomUUID()
        val request = UpdateSpendingPlanRequest(name = "Updated", amount = 200000)
        every { service.updatePlan(testUserId, planId, request) } returns samplePlanResponse("Updated", 200000)

        val result = controller.updatePlan(testUserId, planId, request)

        result.success shouldBe true
        result.data!!.name shouldBe "Updated"
    }

    test("deletePlan returns ok") {
        val planId = UUID.randomUUID()
        justRun { service.deletePlan(testUserId, planId) }

        val result = controller.deletePlan(testUserId, planId)

        result.success shouldBe true
        verify { service.deletePlan(testUserId, planId) }
    }

    test("completePlan returns completed plan") {
        val planId = UUID.randomUUID()
        val request = CompleteSpendingPlanRequest(actualAmount = 95000)
        val completedResponse = samplePlanResponse().copy(
            status = "COMPLETED",
            actualAmount = 95000,
            completedDate = LocalDate.of(2026, 3, 29)
        )
        every { service.completePlan(testUserId, planId, request) } returns completedResponse

        val result = controller.completePlan(testUserId, planId, request)

        result.success shouldBe true
        result.data!!.status shouldBe "COMPLETED"
        result.data!!.actualAmount shouldBe 95000
    }

    test("skipPlan returns skipped plan") {
        val planId = UUID.randomUUID()
        val skippedResponse = samplePlanResponse().copy(status = "SKIPPED")
        every { service.skipPlan(testUserId, planId) } returns skippedResponse

        val result = controller.skipPlan(testUserId, planId)

        result.success shouldBe true
        result.data!!.status shouldBe "SKIPPED"
    }

    test("getSuggestions returns matching suggestions") {
        val catId = UUID.randomUUID()
        val suggestions = listOf(
            SpendingPlanSuggestion(
                planId = UUID.randomUUID(),
                name = "Costco",
                plannedAmount = 150000,
                matchScore = 0.92,
                matchReasons = listOf("Same category", "Amount diff 3.3%", "Same date")
            )
        )
        every {
            service.getSuggestions(testUserId, catId, 145000, LocalDate.of(2026, 3, 29))
        } returns suggestions

        val result = controller.getSuggestions(testUserId, catId, 145000, LocalDate.of(2026, 3, 29))

        result.success shouldBe true
        result.data!!.size shouldBe 1
        result.data!![0].matchScore shouldBe 0.92
    }

    test("getSuggestions without categoryId returns empty") {
        every {
            service.getSuggestions(testUserId, null, 100000, LocalDate.of(2026, 3, 29))
        } returns emptyList()

        val result = controller.getSuggestions(testUserId, null, 100000, LocalDate.of(2026, 3, 29))

        result.success shouldBe true
        result.data!!.size shouldBe 0
    }
})
