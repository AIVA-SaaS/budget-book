package com.budgetbook.pocket.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.pocket.domain.MoneyPocket
import com.budgetbook.pocket.domain.PocketTransfer
import com.budgetbook.pocket.domain.PocketType
import com.budgetbook.pocket.dto.CreateTransferRequest
import com.budgetbook.pocket.dto.DistributeRequest
import com.budgetbook.pocket.dto.DistributionItem
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.pocket.repository.PocketTransferRepository
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
import java.time.LocalDate
import java.util.Optional

class PocketTransferServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val pocketTransferRepository = mockk<PocketTransferRepository>()
    val moneyPocketRepository = mockk<MoneyPocketRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val userRepository = mockk<UserRepository>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val service = PocketTransferService(pocketTransferRepository, moneyPocketRepository, coupleRepository, userRepository, syncEventPublisher)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val pocket1 = MoneyPocket(couple = couple, name = "생활비", type = PocketType.LIVING, allocatedAmount = 500000, displayOrder = 1)
    val pocket2 = MoneyPocket(couple = couple, name = "저축", type = PocketType.SAVINGS, allocatedAmount = 1000000, displayOrder = 2)

    // --- getTransfers ---

    Given("a user with transfers") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val transfer = PocketTransfer(
            couple = couple, fromPocket = pocket1, toPocket = pocket2,
            amount = 100000, description = "저축 이동", transferDate = LocalDate.of(2024, 3, 1), author = user1
        )
        every { pocketTransferRepository.findByCoupleId(couple.id) } returns listOf(transfer)

        When("getTransfers is called") {
            val result = service.getTransfers(user1.id)

            Then("returns list of transfers") {
                result shouldHaveSize 1
                result[0].amount shouldBe 100000
                result[0].fromPocket.name shouldBe "생활비"
                result[0].toPocket.name shouldBe "저축"
                result[0].authorId shouldBe user1.id
            }
        }
    }

    // --- createTransfer ---

    Given("a user creating a transfer") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { moneyPocketRepository.findByIdAndCoupleId(pocket1.id, couple.id) } returns pocket1
        every { moneyPocketRepository.findByIdAndCoupleId(pocket2.id, couple.id) } returns pocket2

        When("creating a valid transfer") {
            val request = CreateTransferRequest(
                fromPocketId = pocket1.id,
                toPocketId = pocket2.id,
                amount = 50000,
                description = "저축 이동",
                transferDate = LocalDate.of(2024, 3, 1)
            )
            val transferSlot = slot<PocketTransfer>()
            every { pocketTransferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val result = service.createTransfer(user1.id, request)

            Then("creates the transfer") {
                result.amount shouldBe 50000
                result.fromPocket.id shouldBe pocket1.id
                result.toPocket.id shouldBe pocket2.id
                result.description shouldBe "저축 이동"
            }

            Then("publishes sync event") {
                verify(exactly = 1) { syncEventPublisher.publish(match { it.type == "POCKET_TRANSFER_CREATED" }) }
            }
        }

        When("creating a transfer to the same pocket") {
            val request = CreateTransferRequest(
                fromPocketId = pocket1.id,
                toPocketId = pocket1.id,
                amount = 50000,
                transferDate = LocalDate.of(2024, 3, 1)
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.createTransfer(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("a user creating a transfer with non-existent source pocket") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        val fakeId = java.util.UUID.randomUUID()
        every { moneyPocketRepository.findByIdAndCoupleId(fakeId, couple.id) } returns null

        When("createTransfer is called") {
            val request = CreateTransferRequest(
                fromPocketId = fakeId,
                toPocketId = pocket2.id,
                amount = 50000,
                transferDate = LocalDate.of(2024, 3, 1)
            )

            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    service.createTransfer(user1.id, request)
                }
            }
        }
    }

    // --- distribute ---

    Given("a user distributing income") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { moneyPocketRepository.findByIdAndCoupleId(pocket1.id, couple.id) } returns pocket1
        every { moneyPocketRepository.findByIdAndCoupleId(pocket2.id, couple.id) } returns pocket2
        every { moneyPocketRepository.save(any()) } answers { firstArg() }

        When("distributing with matching total") {
            val request = DistributeRequest(
                totalAmount = 3000000,
                distributions = listOf(
                    DistributionItem(pocketId = pocket1.id, amount = 2000000),
                    DistributionItem(pocketId = pocket2.id, amount = 1000000)
                )
            )

            val result = service.distribute(user1.id, request)

            Then("distributes to each pocket") {
                result.totalDistributed shouldBe 3000000
                result.distributions shouldHaveSize 2
                result.distributions[0].pocketName shouldBe "생활비"
                result.distributions[0].amount shouldBe 2000000
                result.distributions[1].pocketName shouldBe "저축"
                result.distributions[1].amount shouldBe 1000000
            }

            Then("adds to pocket allocatedAmount") {
                pocket1.allocatedAmount shouldBe 2500000 // 500000 + 2000000
                pocket2.allocatedAmount shouldBe 2000000 // 1000000 + 1000000
            }
        }
    }

    Given("a user distributing with mismatched total") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("distribute is called with wrong total") {
            val request = DistributeRequest(
                totalAmount = 3000000,
                distributions = listOf(
                    DistributionItem(pocketId = pocket1.id, amount = 1000000),
                    DistributionItem(pocketId = pocket2.id, amount = 1000000)
                )
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.distribute(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- getActiveCouple error ---

    Given("a user not in any active couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("getTransfers is called") {
            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    service.getTransfers(user1.id)
                }
            }
        }
    }
})
