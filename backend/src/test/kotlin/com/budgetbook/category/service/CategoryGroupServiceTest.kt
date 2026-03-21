package com.budgetbook.category.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.category.domain.BudgetType
import com.budgetbook.common.entity.Visibility
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryGroup
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.dto.CreateCategoryGroupRequest
import com.budgetbook.category.dto.UpdateCategoryGroupRequest
import com.budgetbook.category.repository.CategoryGroupRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.common.cache.RedisCacheService
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
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
import java.util.UUID

class CategoryGroupServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val categoryGroupRepository = mockk<CategoryGroupRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val redisCacheService = mockk<RedisCacheService>(relaxed = true)
    val userRepository = mockk<com.budgetbook.auth.repository.UserRepository>()
    val transactionRepository = mockk<com.budgetbook.transaction.repository.TransactionRepository>(relaxed = true)
    val categoryService = CategoryService(categoryRepository, categoryGroupRepository, coupleResolver, syncEventPublisher, redisCacheService, userRepository, transactionRepository)
    val categoryGroupService = CategoryGroupService(
        categoryGroupRepository, categoryRepository, categoryService, coupleResolver, syncEventPublisher, userRepository, transactionRepository
    )

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

    // --- listCategoryGroups ---

    Given("a user in an active couple with category groups") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group1 = CategoryGroup(
            couple = couple, name = "생활비", icon = "wallet", color = "#4CAF50",
            budgetType = BudgetType.WEEKLY, displayOrder = 1, isDefault = true
        )
        val group2 = CategoryGroup(
            couple = couple, name = "고정지출", icon = "receipt", color = "#2196F3",
            budgetType = BudgetType.MONTHLY, displayOrder = 2, isDefault = true
        )

        val category1 = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, group = group1)
        val category2 = Category(couple = couple, name = "교통비", type = CategoryType.EXPENSE, group = group1)
        val uncategorizedCategory = Category(couple = couple, name = "Custom", type = CategoryType.EXPENSE)

        val privateGroup = CategoryGroup(
            couple = couple, name = "개인 항목", icon = "person", color = "#607D8B",
            budgetType = BudgetType.NONE, displayOrder = 100, isDefault = false,
            visibility = Visibility.PRIVATE, owner = user1
        )

        every { categoryGroupRepository.findByCoupleIdAndUserIdOrderByDisplayOrder(couple.id, any()) } returns listOf(group1, group2, privateGroup)
        every { categoryRepository.findByCoupleIdAndGroupIdAndUserId(couple.id, group1.id, any()) } returns listOf(category1, category2)
        every { categoryRepository.findByCoupleIdAndGroupIdAndUserId(couple.id, group2.id, any()) } returns emptyList()
        every { categoryRepository.findByCoupleIdAndGroupIdAndUserId(couple.id, privateGroup.id, any()) } returns emptyList()
        every { categoryRepository.findByCoupleIdAndGroupIsNullAndUserId(couple.id, any()) } returns listOf(uncategorizedCategory)

        When("listCategoryGroups is called") {
            val result = categoryGroupService.listCategoryGroups(user1.id)

            Then("returns groups with their categories plus uncategorized") {
                result shouldHaveSize 4
                result[0].name shouldBe "생활비"
                result[0].categories shouldHaveSize 2
                result[1].name shouldBe "고정지출"
                result[1].categories shouldHaveSize 0
                result[2].name shouldBe "개인 항목"
                result[2].categories shouldHaveSize 0
                result[3].name shouldBe "미분류"
                result[3].categories shouldHaveSize 1
            }
        }
    }

    Given("a user with no uncategorized categories") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group = CategoryGroup(couple = couple, name = "생활비", displayOrder = 1, isDefault = true)
        val privateGroup = CategoryGroup(
            couple = couple, name = "개인 항목", icon = "person", color = "#607D8B",
            budgetType = BudgetType.NONE, displayOrder = 100, isDefault = false,
            visibility = Visibility.PRIVATE, owner = user1
        )
        every { categoryGroupRepository.findByCoupleIdAndUserIdOrderByDisplayOrder(couple.id, any()) } returns listOf(group, privateGroup)
        every { categoryRepository.findByCoupleIdAndGroupIdAndUserId(couple.id, group.id, any()) } returns emptyList()
        every { categoryRepository.findByCoupleIdAndGroupIdAndUserId(couple.id, privateGroup.id, any()) } returns emptyList()
        every { categoryRepository.findByCoupleIdAndGroupIsNullAndUserId(couple.id, any()) } returns emptyList()

        When("listCategoryGroups is called") {
            val result = categoryGroupService.listCategoryGroups(user1.id)

            Then("does not include uncategorized group") {
                result shouldHaveSize 2
                result[0].name shouldBe "생활비"
                result[1].name shouldBe "개인 항목"
            }
        }
    }

    Given("a user not in a couple") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("listCategoryGroups is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    categoryGroupService.listCategoryGroups(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    // --- createCategoryGroup ---

    Given("a user in a couple creating a category group") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val groupSlot = slot<CategoryGroup>()
        every { categoryGroupRepository.save(capture(groupSlot)) } answers { groupSlot.captured }

        When("createCategoryGroup is called with valid request") {
            val request = CreateCategoryGroupRequest(name = "투자", icon = "trending_up", color = "#FF9800", budgetType = "MONTHLY")
            val result = categoryGroupService.createCategoryGroup(user1.id, request)

            Then("creates and returns the new group") {
                result.name shouldBe "투자"
                result.icon shouldBe "trending_up"
                result.color shouldBe "#FF9800"
                result.budgetType shouldBe "MONTHLY"
                result.isDefault shouldBe false
                result.categories shouldHaveSize 0
            }
        }

        When("createCategoryGroup is called with invalid budget type") {
            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    categoryGroupService.createCategoryGroup(
                        user1.id,
                        CreateCategoryGroupRequest(name = "Test", budgetType = "INVALID")
                    )
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- updateCategoryGroup ---

    Given("a category group owned by the user's couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group = CategoryGroup(
            couple = couple, name = "생활비", icon = "wallet", color = "#4CAF50",
            budgetType = BudgetType.WEEKLY, displayOrder = 1, isDefault = true
        )
        every { categoryGroupRepository.findByIdAndCoupleId(group.id, couple.id) } returns group
        every { categoryGroupRepository.save(group) } returns group
        every { categoryRepository.findByCoupleIdAndGroupIdAndUserId(couple.id, group.id, any()) } returns emptyList()

        When("updateCategoryGroup is called") {
            val request = UpdateCategoryGroupRequest(name = "생활비/변동비", budgetType = "MONTHLY", displayOrder = 5)
            val result = categoryGroupService.updateCategoryGroup(user1.id, group.id, request)

            Then("updates the specified fields") {
                result.name shouldBe "생활비/변동비"
                result.budgetType shouldBe "MONTHLY"
                result.displayOrder shouldBe 5
                result.color shouldBe "#4CAF50" // unchanged
            }
        }
    }

    Given("a non-existent category group") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val fakeId = UUID.randomUUID()
        every { categoryGroupRepository.findByIdAndCoupleId(fakeId, couple.id) } returns null

        When("updateCategoryGroup is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    categoryGroupService.updateCategoryGroup(user1.id, fakeId, UpdateCategoryGroupRequest(name = "X"))
                }
                ex.code shouldBe "GROUP_NOT_FOUND"
            }
        }
    }

    // --- deleteCategoryGroup ---

    Given("a custom (non-default) category group") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group = CategoryGroup(couple = couple, name = "Custom Group", isDefault = false)
        every { categoryGroupRepository.findByIdAndCoupleId(group.id, couple.id) } returns group
        every { categoryRepository.findByCoupleIdAndGroupId(couple.id, group.id) } returns emptyList()
        every { categoryRepository.saveAll(emptyList<Category>()) } returns emptyList()
        every { categoryGroupRepository.delete(group) } returns Unit

        When("deleteCategoryGroup is called") {
            categoryGroupService.deleteCategoryGroup(user1.id, group.id)

            Then("deletes the group") {
                verify(exactly = 1) { categoryGroupRepository.delete(group) }
            }
        }
    }

    Given("a custom group with categories assigned") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group = CategoryGroup(couple = couple, name = "Custom Group", isDefault = false)
        val category = Category(couple = couple, name = "Test Cat", type = CategoryType.EXPENSE, group = group)
        every { categoryGroupRepository.findByIdAndCoupleId(group.id, couple.id) } returns group
        every { categoryRepository.findByCoupleIdAndGroupId(couple.id, group.id) } returns listOf(category)
        every { categoryRepository.saveAll(listOf(category)) } returns listOf(category)
        every { categoryGroupRepository.delete(group) } returns Unit

        When("deleteCategoryGroup is called") {
            categoryGroupService.deleteCategoryGroup(user1.id, group.id)

            Then("unassigns categories and deletes the group") {
                category.group shouldBe null
                verify(exactly = 1) { categoryRepository.saveAll(listOf(category)) }
                verify(exactly = 1) { categoryGroupRepository.delete(group) }
            }
        }
    }

    Given("a default category group") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group = CategoryGroup(couple = couple, name = "생활비", isDefault = true)
        every { categoryGroupRepository.findByIdAndCoupleId(group.id, couple.id) } returns group
        every { categoryRepository.findByCoupleIdAndGroupId(couple.id, group.id) } returns emptyList()
        every { categoryRepository.saveAll(emptyList<Category>()) } returns emptyList()
        every { categoryGroupRepository.delete(group) } returns Unit

        When("deleteCategoryGroup is called") {
            categoryGroupService.deleteCategoryGroup(user1.id, group.id)

            Then("deletes the default group successfully") {
                verify(exactly = 1) { categoryGroupRepository.delete(group) }
            }
        }
    }

    // --- reorderGroups ---

    Given("a user with multiple category groups for reordering") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group1 = CategoryGroup(couple = couple, name = "생활비", displayOrder = 0, isDefault = true)
        val group2 = CategoryGroup(couple = couple, name = "고정지출", displayOrder = 1, isDefault = true)
        val group3 = CategoryGroup(couple = couple, name = "기타", displayOrder = 2, isDefault = false)

        every { categoryGroupRepository.findByCoupleIdOrderByDisplayOrder(couple.id) } returns listOf(group1, group2, group3)
        every { categoryGroupRepository.saveAll(any<List<CategoryGroup>>()) } answers { firstArg() }
        every { categoryRepository.findByCoupleIdAndGroupIdAndUserId(couple.id, any(), any()) } returns emptyList()

        When("reorderGroups is called with reversed order") {
            val orderedIds = listOf(group3.id, group2.id, group1.id)
            val result = categoryGroupService.reorderGroups(user1.id, orderedIds)

            Then("updates display order correctly") {
                group3.displayOrder shouldBe 0
                group2.displayOrder shouldBe 1
                group1.displayOrder shouldBe 2
                result shouldHaveSize 3
                result[0].name shouldBe "기타"
                result[1].name shouldBe "고정지출"
                result[2].name shouldBe "생활비"
            }
        }
    }

    Given("a user attempting to reorder with an invalid group ID") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val group1 = CategoryGroup(couple = couple, name = "생활비", displayOrder = 0, isDefault = true)
        every { categoryGroupRepository.findByCoupleIdOrderByDisplayOrder(couple.id) } returns listOf(group1)

        When("reorderGroups is called with a non-existent group ID") {
            val fakeId = UUID.randomUUID()
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    categoryGroupService.reorderGroups(user1.id, listOf(fakeId))
                }
                ex.code shouldBe "GROUP_NOT_FOUND"
            }
        }
    }

    // --- seedDefaultCategoryGroups ---

    Given("a newly created couple with existing default categories") {
        val savedGroupsList = mutableListOf<CategoryGroup>()
        every { categoryGroupRepository.saveAll(any<List<CategoryGroup>>()) } answers {
            val groups = firstArg<List<CategoryGroup>>()
            savedGroupsList.addAll(groups)
            groups
        }

        val category1 = Category(couple = couple, name = "식비", type = CategoryType.EXPENSE, isDefault = true)
        val category2 = Category(couple = couple, name = "교통비", type = CategoryType.EXPENSE, isDefault = true)
        val category3 = Category(couple = couple, name = "쇼핑", type = CategoryType.EXPENSE, isDefault = true)
        val category4 = Category(couple = couple, name = "기타", type = CategoryType.EXPENSE, isDefault = true)
        val category5 = Category(couple = couple, name = "의료/건강", type = CategoryType.EXPENSE, isDefault = true)
        val category6 = Category(couple = couple, name = "문화/여가", type = CategoryType.EXPENSE, isDefault = true)

        every { categoryRepository.findByCoupleIdAndNameIn(couple.id, listOf("식비", "교통비", "쇼핑")) } returns listOf(category1, category2, category3)
        every { categoryRepository.findByCoupleIdAndNameIn(couple.id, listOf("기타", "의료/건강", "문화/여가")) } returns listOf(category4, category5, category6)

        every { categoryRepository.saveAll(any<List<Category>>()) } answers { firstArg() }

        When("seedDefaultCategoryGroups is called") {
            categoryGroupService.seedDefaultCategoryGroups(couple)

            Then("creates 3 default groups") {
                savedGroupsList shouldHaveSize 3
                savedGroupsList.map { it.name } shouldBe listOf("생활비", "고정지출", "기타")
                savedGroupsList.all { it.isDefault } shouldBe true
                savedGroupsList.all { it.couple == couple } shouldBe true
            }

            Then("assigns categories to the correct groups") {
                category1.group?.name shouldBe "생활비"
                category2.group?.name shouldBe "생활비"
                category3.group?.name shouldBe "생활비"
                category4.group?.name shouldBe "기타"
                category5.group?.name shouldBe "기타"
                category6.group?.name shouldBe "기타"
            }
        }
    }
})
