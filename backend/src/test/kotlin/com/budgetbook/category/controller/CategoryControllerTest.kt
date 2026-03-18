package com.budgetbook.category.controller

import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.dto.CategoryResponse
import com.budgetbook.category.dto.CreateCategoryRequest
import com.budgetbook.category.dto.UpdateCategoryRequest
import com.budgetbook.category.service.CategoryService
import com.budgetbook.common.exception.BusinessException
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class CategoryControllerTest : FunSpec({

    val categoryService = mockk<CategoryService>()
    val controller = CategoryController(categoryService)

    val testUserId = UUID.randomUUID()

    test("listCategories returns all categories") {

        val categories = listOf(
            CategoryResponse(UUID.randomUUID(), "식비", "EXPENSE", "restaurant", "#FF5733", null, true, 1, Instant.now()),
            CategoryResponse(UUID.randomUUID(), "급여", "INCOME", "payments", "#4CAF50", null, true, 1, Instant.now())
        )
        every { categoryService.listCategories(testUserId, null) } returns categories

        val result = controller.listCategories(testUserId, null)

        result.success shouldBe true
        result.data!!.size shouldBe 2
    }

    test("listCategories with type filter returns filtered categories") {

        val categories = listOf(
            CategoryResponse(UUID.randomUUID(), "식비", "EXPENSE", "restaurant", "#FF5733", null, true, 1, Instant.now())
        )
        every { categoryService.listCategories(testUserId, CategoryType.EXPENSE) } returns categories

        val result = controller.listCategories(testUserId, "EXPENSE")

        result.success shouldBe true
        result.data!!.size shouldBe 1
    }

    test("listCategories with invalid type throws BusinessException") {


        val ex = shouldThrow<BusinessException> {
            controller.listCategories(testUserId, "FOOBAR")
        }
        ex.code shouldBe "VALIDATION_ERROR"
    }

    test("createCategory returns 201 with created category") {

        val request = CreateCategoryRequest(name = "반려동물", type = "EXPENSE", icon = "pets", color = "#9C27B0")
        val response = CategoryResponse(UUID.randomUUID(), "반려동물", "EXPENSE", "pets", "#9C27B0", null, false, 0, Instant.now())
        every { categoryService.createCategory(testUserId, request) } returns response

        val result = controller.createCategory(testUserId, request)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.data!!.name shouldBe "반려동물"
    }

    test("updateCategory returns updated category") {

        val categoryId = UUID.randomUUID()
        val request = UpdateCategoryRequest(name = "식비/외식")
        val response = CategoryResponse(categoryId, "식비/외식", "EXPENSE", "restaurant", "#FF5733", null, true, 1, Instant.now())
        every { categoryService.updateCategory(testUserId, categoryId, request) } returns response

        val result = controller.updateCategory(testUserId, categoryId, request)

        result.success shouldBe true
        result.data!!.name shouldBe "식비/외식"
    }

    test("deleteCategory returns 204 No Content") {

        val categoryId = UUID.randomUUID()
        justRun { categoryService.deleteCategory(testUserId, categoryId) }

        val result = controller.deleteCategory(testUserId, categoryId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { categoryService.deleteCategory(testUserId, categoryId) }
    }
})
