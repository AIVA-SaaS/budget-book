package com.budgetbook.pocket.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.pocket.domain.MoneyPocket
import com.budgetbook.pocket.domain.PocketType
import com.budgetbook.pocket.dto.CreatePocketRequest
import com.budgetbook.pocket.dto.UpdatePocketRequest
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.pocket.repository.PocketTransferRepository
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.time.LocalDate

class MoneyPocketServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val moneyPocketRepository = mockk<MoneyPocketRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val pocketTransferRepository = mockk<PocketTransferRepository> {
        every { sumAmountByToPocketId(any()) } returns 0L
        every { sumAmountByFromPocketId(any()) } returns 0L
    }
    val transactionRepository = mockk<TransactionRepository> {
        every { sumExpenseByPocketId(any(), any()) } returns 0L
    }
    val userRepository = mockk<com.budgetbook.auth.repository.UserRepository>()
    val service = MoneyPocketService(moneyPocketRepository, coupleResolver, syncEventPublisher, pocketTransferRepository, transactionRepository, userRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    // --- getPockets ---

    Given("a user in an active couple with pockets") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val pocket1 = MoneyPocket(couple = couple, name = "생활비", type = PocketType.LIVING, allocatedAmount = 500000, displayOrder = 1)
        val pocket2 = MoneyPocket(couple = couple, name = "저축", type = PocketType.SAVINGS, allocatedAmount = 1000000, displayOrder = 2)
        every { moneyPocketRepository.findByCoupleIdAndIsActiveTrueAndUserId(couple.id, user1.id) } returns listOf(pocket1, pocket2)

        When("getPockets is called") {
            val result = service.getPockets(user1.id)

            Then("returns all active pockets") {
                result shouldHaveSize 2
                result[0].name shouldBe "생활비"
                result[0].type shouldBe "LIVING"
                result[0].allocatedAmount shouldBe 500000
                result[0].balance shouldBe 500000
                result[1].name shouldBe "저축"
            }
        }
    }

    // --- createPocket ---

    Given("a user in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { moneyPocketRepository.maxDisplayOrderByCoupleId(couple.id) } returns 2

        When("creating a pocket with valid data") {
            val request = CreatePocketRequest(
                name = "용돈",
                type = "CUSTOM",
                allocatedAmount = 200000,
                icon = "money",
                color = "#00FF00"
            )
            val pocketSlot = slot<MoneyPocket>()
            every { moneyPocketRepository.save(capture(pocketSlot)) } answers { pocketSlot.captured }

            val result = service.createPocket(user1.id, request)

            Then("creates pocket with correct fields") {
                result.name shouldBe "용돈"
                result.type shouldBe "CUSTOM"
                result.allocatedAmount shouldBe 200000
                result.icon shouldBe "money"
                result.color shouldBe "#00FF00"
                result.displayOrder shouldBe 3
                result.isActive shouldBe true
            }

            Then("publishes POCKET_CREATED event") {
                verify(exactly = 1) { syncEventPublisher.publish(match { it.type == "POCKET_CREATED" }) }
            }
        }

        When("creating a pocket with invalid type") {
            val request = CreatePocketRequest(
                name = "Invalid",
                type = "INVALID_TYPE",
                allocatedAmount = 100000
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.createPocket(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- updatePocket ---

    Given("an existing active pocket") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val pocket = MoneyPocket(couple = couple, name = "생활비", type = PocketType.LIVING, allocatedAmount = 500000, displayOrder = 1)
        every { moneyPocketRepository.findByIdAndCoupleId(pocket.id, couple.id) } returns pocket
        every { moneyPocketRepository.save(pocket) } returns pocket

        When("updating name and allocatedAmount") {
            val request = UpdatePocketRequest(name = "생활비(수정)", allocatedAmount = 600000)
            val result = service.updatePocket(user1.id, pocket.id, request)

            Then("updates the fields") {
                result.name shouldBe "생활비(수정)"
                result.allocatedAmount shouldBe 600000
            }

            Then("publishes POCKET_UPDATED event") {
                verify(exactly = 1) { syncEventPublisher.publish(match { it.type == "POCKET_UPDATED" }) }
            }
        }
    }

    Given("a non-existent pocket") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val fakeId = java.util.UUID.randomUUID()
        every { moneyPocketRepository.findByIdAndCoupleId(fakeId, couple.id) } returns null

        When("updatePocket is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.updatePocket(user1.id, fakeId, UpdatePocketRequest(name = "test"))
                }
                ex.code shouldBe "POCKET_NOT_FOUND"
            }
        }
    }

    Given("an inactive pocket") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val pocket = MoneyPocket(couple = couple, name = "삭제됨", type = PocketType.CUSTOM, allocatedAmount = 0, isActive = false)
        every { moneyPocketRepository.findByIdAndCoupleId(pocket.id, couple.id) } returns pocket

        When("updatePocket is called") {
            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    service.updatePocket(user1.id, pocket.id, UpdatePocketRequest(name = "test"))
                }
            }
        }
    }

    // --- deletePocket ---

    Given("an active pocket to delete") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val pocket = MoneyPocket(couple = couple, name = "삭제할거", type = PocketType.CUSTOM, allocatedAmount = 100000, displayOrder = 1)
        every { moneyPocketRepository.findByIdAndCoupleId(pocket.id, couple.id) } returns pocket
        every { moneyPocketRepository.save(pocket) } returns pocket

        When("deletePocket is called") {
            service.deletePocket(user1.id, pocket.id)

            Then("soft deletes the pocket") {
                pocket.isActive shouldBe false
                verify(exactly = 1) { moneyPocketRepository.save(pocket) }
            }

            Then("publishes POCKET_DELETED event") {
                verify(exactly = 1) { syncEventPublisher.publish(match { it.type == "POCKET_DELETED" }) }
            }
        }
    }

    // --- seedDefaultPockets ---

    Given("a couple needing default pockets") {
        val pocketSlot = slot<MoneyPocket>()
        every { moneyPocketRepository.save(capture(pocketSlot)) } answers { pocketSlot.captured }

        When("seedDefaultPockets is called") {
            val result = service.seedDefaultPockets(couple)

            Then("creates 4 default pockets") {
                result shouldHaveSize 4
                result[0].name shouldBe "생활비"
                result[0].type shouldBe PocketType.LIVING
                result[1].name shouldBe "고정지출"
                result[1].type shouldBe PocketType.FIXED
                result[2].name shouldBe "카드대기"
                result[2].type shouldBe PocketType.CARD_PENDING
                result[3].name shouldBe "저축"
                result[3].type shouldBe PocketType.SAVINGS
            }
        }
    }

    // --- goal amount in create ---

    Given("a user creating a pocket with goal fields") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { moneyPocketRepository.maxDisplayOrderByCoupleId(couple.id) } returns 0

        When("creating a pocket with goalAmount and targetDate") {
            val request = CreatePocketRequest(
                name = "여행적금",
                type = "SAVINGS",
                allocatedAmount = 0,
                goalAmount = 3000000,
                targetDate = LocalDate.of(2026, 12, 31)
            )
            val pocketSlot = slot<MoneyPocket>()
            every { moneyPocketRepository.save(capture(pocketSlot)) } answers { pocketSlot.captured }

            val result = service.createPocket(user1.id, request)

            Then("response includes goalAmount and targetDate") {
                result.goalAmount shouldBe 3000000
                result.targetDate shouldBe LocalDate.of(2026, 12, 31)
            }
        }
    }

    // --- goal amount in update ---

    Given("an existing pocket to update with goal fields") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        val pocket = MoneyPocket(couple = couple, name = "저축", type = PocketType.SAVINGS, allocatedAmount = 100000, displayOrder = 1)
        every { moneyPocketRepository.findByIdAndCoupleId(pocket.id, couple.id) } returns pocket
        every { moneyPocketRepository.save(pocket) } returns pocket

        When("updating goalAmount and targetDate") {
            val request = UpdatePocketRequest(goalAmount = 5000000, targetDate = LocalDate.of(2027, 6, 30))
            val result = service.updatePocket(user1.id, pocket.id, request)

            Then("response reflects updated goal fields") {
                result.goalAmount shouldBe 5000000
                result.targetDate shouldBe LocalDate.of(2027, 6, 30)
            }
        }
    }

    // --- getActiveCouple error ---

    Given("a user not in any active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("getPockets is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.getPockets(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }
})
