package com.budgetbook.smart.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryGroup
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.smart.domain.CategoryPattern
import com.budgetbook.smart.repository.CategoryPatternRepository
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.util.UUID

class PatternLearningServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val categoryPatternRepository = mockk<CategoryPatternRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val service = PatternLearningService(categoryPatternRepository, categoryRepository)

    // Default: save returns whatever is passed in
    every { categoryPatternRepository.save(any<CategoryPattern>()) } answers { firstArg() }

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    val group = CategoryGroup(couple = couple, name = "생활비")
    val category = Category(
        couple = couple, name = "식비", type = CategoryType.EXPENSE,
        icon = "restaurant", color = "#FF5733", group = group
    )

    // --- extractKeywords ---

    Given("keyword extraction") {
        When("description has multiple words") {
            val keywords = service.extractKeywords("스타벅스 아메리카노 주문")
            Then("returns words with length >= 2") {
                keywords shouldHaveSize 3
                keywords shouldBe listOf("스타벅스", "아메리카노", "주문")
            }
        }

        When("description has single character words") {
            val keywords = service.extractKeywords("A 스타벅스 B")
            Then("filters out words shorter than 2 chars") {
                keywords shouldHaveSize 1
                keywords shouldBe listOf("스타벅스")
            }
        }

        When("description is empty") {
            val keywords = service.extractKeywords("")
            Then("returns empty list") {
                keywords.shouldBeEmpty()
            }
        }

        When("description has duplicate words") {
            val keywords = service.extractKeywords("스타벅스 아메리카노 스타벅스")
            Then("returns distinct keywords") {
                keywords shouldHaveSize 2
                keywords shouldBe listOf("스타벅스", "아메리카노")
            }
        }
    }

    // --- learn ---

    Given("pattern learning") {
        When("learning a new pattern") {
            every {
                categoryPatternRepository.findByCoupleIdAndKeywordAndCategoryId(
                    couple.id, "스타벅스", category.id
                )
            } returns null
            every {
                categoryPatternRepository.findByCoupleIdAndKeywordAndCategoryId(
                    couple.id, "아메리카노", category.id
                )
            } returns null

            service.learn(couple.id, "스타벅스 아메리카노", category.id)

            Then("saves new patterns for each keyword") {
                verify(exactly = 2) { categoryPatternRepository.save(any()) }
            }
        }

        When("learning an existing pattern") {
            val existingPattern = CategoryPattern(
                coupleId = couple.id,
                keyword = "스타벅스",
                categoryId = category.id,
                frequency = 3
            )
            every {
                categoryPatternRepository.findByCoupleIdAndKeywordAndCategoryId(
                    couple.id, "스타벅스", category.id
                )
            } returns existingPattern

            service.learn(couple.id, "스타벅스", category.id)

            Then("increments frequency") {
                existingPattern.frequency shouldBe 4
                verify(exactly = 1) { categoryPatternRepository.save(existingPattern) }
            }
        }

        When("description has no valid keywords") {
            service.learn(couple.id, "A B", category.id)

            Then("does not save any pattern") {
                verify(exactly = 0) { categoryPatternRepository.save(any()) }
            }
        }
    }

    // --- suggest ---

    Given("pattern suggestion") {
        When("patterns exist for keywords") {
            val catId1 = category.id
            val catId2 = UUID.randomUUID()
            val category2 = Category(
                id = catId2, couple = couple, name = "카페", type = CategoryType.EXPENSE,
                icon = "coffee", color = "#795548", group = group
            )

            every {
                categoryPatternRepository.findByCoupleIdAndKeywordIn(couple.id, listOf("스타벅스", "아메리카노"))
            } returns listOf(
                CategoryPattern(coupleId = couple.id, keyword = "스타벅스", categoryId = catId1, frequency = 5),
                CategoryPattern(coupleId = couple.id, keyword = "아메리카노", categoryId = catId1, frequency = 3),
                CategoryPattern(coupleId = couple.id, keyword = "스타벅스", categoryId = catId2, frequency = 2)
            )

            every { categoryRepository.findAllById(setOf(catId1, catId2)) } returns listOf(category, category2)

            val suggestions = service.suggest(couple.id, "스타벅스 아메리카노")

            Then("returns suggestions sorted by frequency") {
                suggestions shouldHaveSize 2
                suggestions[0].categoryId shouldBe catId1
                suggestions[0].categoryName shouldBe "식비"
                suggestions[0].groupName shouldBe "생활비"
                suggestions[0].source shouldBe "PATTERN"
                suggestions[1].categoryId shouldBe catId2
                suggestions[1].categoryName shouldBe "카페"
            }
        }

        When("no patterns exist") {
            every {
                categoryPatternRepository.findByCoupleIdAndKeywordIn(couple.id, listOf("존재하지않는키워드"))
            } returns emptyList()

            val suggestions = service.suggest(couple.id, "존재하지않는키워드")

            Then("returns empty list") {
                suggestions.shouldBeEmpty()
            }
        }

        When("description has no valid keywords") {
            val suggestions = service.suggest(couple.id, "A")

            Then("returns empty list") {
                suggestions.shouldBeEmpty()
            }
        }
    }
})
