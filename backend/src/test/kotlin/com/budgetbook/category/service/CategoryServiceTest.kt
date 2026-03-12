package com.budgetbook.category.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.dto.CreateCategoryRequest
import com.budgetbook.category.dto.UpdateCategoryRequest
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.sync.SyncEventPublisher
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.util.Optional
import java.util.UUID

class CategoryServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val categoryRepository = mockk<CategoryRepository>()
    val categoryGroupRepository = mockk<CategoryGroupRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val redisCacheService = mockk<RedisCacheService>(relaxed = true)
    val categoryService = CategoryService(categoryRepository, categoryGroupRepository, coupleRepository, syncEventPublisher, redisCacheService)

    val user1 = User(
        email = "user1@example.com",
        nickname = "User1",
        provider = AuthProvider.GOOGLE,
        providerId = "google-1"
    )
    val user2 = User(
        email = "user2@example.com",
        nickname = "User2",
        provider = AuthProvider.KAKAO,
        providerId = "kakao-2"
    )
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    // --- listCategories ---

    Given("a user in an active couple with categories") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val category1 = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, isDefault = true)
        val category2 = Category(couple = couple, name = "급여", type = CategoryType.INCOME, isDefault = true)

        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(category1, category2)
        every { categoryRepository.findByCoupleIdAndType(couple.id, CategoryType.EXPENSE) } returns listOf(category1)

        When("listCategories is called without type filter") {
            val result = categoryService.listCategories(user1.id, null)

            Then("returns all categories") {
                result shouldHaveSize 2
            }
        }

        When("listCategories is called with EXPENSE filter") {
            val result = categoryService.listCategories(user1.id, CategoryType.EXPENSE)

            Then("returns only expense categories") {
                result shouldHaveSize 1
                result[0].type shouldBe "EXPENSE"
            }
        }
    }

    Given("a user not in a couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("listCategories is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    categoryService.listCategories(user1.id, null)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    // --- createCategory ---

    Given("a user in a couple creating a category") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val categorySlot = slot<Category>()
        every { categoryRepository.save(capture(categorySlot)) } answers { categorySlot.captured }

        When("createCategory is called with valid request") {
            val request = CreateCategoryRequest(name = "반려동물", type = "EXPENSE", icon = "pets", color = "#9C27B0")
            val result = categoryService.createCategory(user1.id, request)

            Then("creates and returns the new category") {
                result.name shouldBe "반려동물"
                result.type shouldBe "EXPENSE"
                result.icon shouldBe "pets"
                result.color shouldBe "#9C27B0"
                result.isDefault shouldBe false
            }
        }

        When("createCategory is called with invalid type") {
            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    categoryService.createCategory(user1.id, CreateCategoryRequest(name = "Test", type = "INVALID"))
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- updateCategory ---

    Given("a category owned by the user's couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val category = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF5733")
        every { categoryRepository.findById(category.id) } returns Optional.of(category)
        every { categoryRepository.save(category) } returns category

        When("updateCategory is called") {
            val request = UpdateCategoryRequest(name = "식비/외식", icon = "restaurant_menu", displayOrder = 2)
            val result = categoryService.updateCategory(user1.id, category.id, request)

            Then("updates the specified fields") {
                result.name shouldBe "식비/외식"
                result.icon shouldBe "restaurant_menu"
                result.displayOrder shouldBe 2
                result.color shouldBe "#FF5733" // unchanged
            }
        }
    }

    Given("a category owned by a different couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val otherCouple = Couple(user1 = user2, status = CoupleStatus.ACTIVE)
        val category = Category(couple = otherCouple, name = "Other", type = CategoryType.EXPENSE)
        every { categoryRepository.findById(category.id) } returns Optional.of(category)

        When("updateCategory is called") {
            Then("throws ForbiddenException") {
                val ex = shouldThrow<ForbiddenException> {
                    categoryService.updateCategory(user1.id, category.id, UpdateCategoryRequest(name = "Hack"))
                }
                ex.code shouldBe "FORBIDDEN"
            }
        }
    }

    Given("a non-existent category") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val fakeId = UUID.randomUUID()
        every { categoryRepository.findById(fakeId) } returns Optional.empty()

        When("updateCategory is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    categoryService.updateCategory(user1.id, fakeId, UpdateCategoryRequest(name = "X"))
                }
                ex.code shouldBe "CATEGORY_NOT_FOUND"
            }
        }
    }

    // --- deleteCategory ---

    Given("a custom (non-default) category") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val category = Category(couple = couple, name = "Custom", type = CategoryType.EXPENSE, isDefault = false)
        every { categoryRepository.findById(category.id) } returns Optional.of(category)
        every { categoryRepository.delete(category) } returns Unit

        When("deleteCategory is called") {
            categoryService.deleteCategory(user1.id, category.id)

            Then("deletes the category") {
                verify(exactly = 1) { categoryRepository.delete(category) }
            }
        }
    }

    Given("a default category") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val category = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, isDefault = true)
        every { categoryRepository.findById(category.id) } returns Optional.of(category)

        When("deleteCategory is called") {
            Then("throws BusinessException CANNOT_DELETE_DEFAULT_CATEGORY") {
                val ex = shouldThrow<BusinessException> {
                    categoryService.deleteCategory(user1.id, category.id)
                }
                ex.code shouldBe "CANNOT_DELETE_DEFAULT_CATEGORY"
            }
        }
    }

    // --- seedDefaultCategories ---

    Given("a newly created couple") {
        val categoriesSlot = slot<List<Category>>()
        every { categoryRepository.saveAll(capture(categoriesSlot)) } answers { categoriesSlot.captured }

        When("seedDefaultCategories is called") {
            categoryService.seedDefaultCategories(couple)

            Then("creates 8 default categories (2 income + 6 expense)") {
                val saved = categoriesSlot.captured
                saved shouldHaveSize 8
                saved.filter { it.type == CategoryType.INCOME } shouldHaveSize 2
                saved.filter { it.type == CategoryType.EXPENSE } shouldHaveSize 6
                saved.all { it.isDefault } shouldBe true
                saved.all { it.couple == couple } shouldBe true
            }
        }
    }
})
