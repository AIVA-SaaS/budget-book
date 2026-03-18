package com.budgetbook.category.controller

import com.budgetbook.category.dto.CategoryGroupResponse
import com.budgetbook.category.dto.CreateCategoryGroupRequest
import com.budgetbook.category.dto.UpdateCategoryGroupRequest
import com.budgetbook.category.service.CategoryGroupService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class CategoryGroupControllerTest : FunSpec({

    val categoryGroupService = mockk<CategoryGroupService>()
    val controller = CategoryGroupController(categoryGroupService)

    val testUserId = UUID.randomUUID()

    test("listCategoryGroups returns all groups with categories") {

        val groups = listOf(
            CategoryGroupResponse(
                UUID.randomUUID(), "생활비", "wallet", "#4CAF50", "WEEKLY",
                1, true, emptyList(), Instant.now()
            ),
            CategoryGroupResponse(
                UUID.randomUUID(), "고정지출", "receipt", "#2196F3", "MONTHLY",
                2, true, emptyList(), Instant.now()
            )
        )
        every { categoryGroupService.listCategoryGroups(testUserId) } returns groups

        val result = controller.listCategoryGroups(testUserId)

        result.success shouldBe true
        result.data!!.size shouldBe 2
        result.data!![0].name shouldBe "생활비"
    }

    test("createCategoryGroup returns 201 with created group") {

        val request = CreateCategoryGroupRequest(name = "투자", icon = "trending_up", color = "#FF9800", budgetType = "MONTHLY")
        val response = CategoryGroupResponse(
            UUID.randomUUID(), "투자", "trending_up", "#FF9800", "MONTHLY",
            0, false, emptyList(), Instant.now()
        )
        every { categoryGroupService.createCategoryGroup(testUserId, request) } returns response

        val result = controller.createCategoryGroup(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.data!!.name shouldBe "투자"
    }

    test("updateCategoryGroup returns updated group") {

        val groupId = UUID.randomUUID()
        val request = UpdateCategoryGroupRequest(name = "생활비/변동비")
        val response = CategoryGroupResponse(
            groupId, "생활비/변동비", "wallet", "#4CAF50", "WEEKLY",
            1, true, emptyList(), Instant.now()
        )
        every { categoryGroupService.updateCategoryGroup(testUserId, groupId, request) } returns response

        val result = controller.updateCategoryGroup(testUserId, groupId, request)

        result.success shouldBe true
        result.data!!.name shouldBe "생활비/변동비"
    }

    test("deleteCategoryGroup returns 204 No Content") {

        val groupId = UUID.randomUUID()
        justRun { categoryGroupService.deleteCategoryGroup(testUserId, groupId) }

        val result = controller.deleteCategoryGroup(testUserId, groupId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { categoryGroupService.deleteCategoryGroup(testUserId, groupId) }
    }
})
