package com.budgetbook.pocket.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.pocket.domain.DistributionRatio
import com.budgetbook.pocket.domain.MoneyPocket
import com.budgetbook.pocket.domain.PocketType
import com.budgetbook.pocket.dto.RatioEntry
import com.budgetbook.pocket.dto.SaveDistributionRatiosRequest
import com.budgetbook.pocket.repository.DistributionRatioRepository
import com.budgetbook.pocket.repository.MoneyPocketRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.math.BigDecimal

class DistributionRatioServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val distributionRatioRepository = mockk<DistributionRatioRepository>()
    val moneyPocketRepository = mockk<MoneyPocketRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val service = DistributionRatioService(distributionRatioRepository, moneyPocketRepository, coupleRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    val pocket1 = MoneyPocket(couple = couple, name = "생활비", type = PocketType.LIVING, allocatedAmount = 500000, displayOrder = 1)
    val pocket2 = MoneyPocket(couple = couple, name = "저축", type = PocketType.SAVINGS, allocatedAmount = 300000, displayOrder = 2)

    // --- getRatios ---

    Given("a couple with saved distribution ratios") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        val ratio1 = DistributionRatio(couple = couple, pocket = pocket1, ratio = BigDecimal("70.00"))
        val ratio2 = DistributionRatio(couple = couple, pocket = pocket2, ratio = BigDecimal("30.00"))
        every { distributionRatioRepository.findByCoupleId(couple.id) } returns listOf(ratio1, ratio2)

        When("getRatios is called") {
            val result = service.getRatios(user1.id)

            Then("returns all saved ratios") {
                result shouldHaveSize 2
                result[0].pocketName shouldBe "생활비"
                result[0].ratio shouldBe BigDecimal("70.00")
                result[1].pocketName shouldBe "저축"
                result[1].ratio shouldBe BigDecimal("30.00")
            }
        }
    }

    // --- saveRatios ---

    Given("a couple with active pockets") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { moneyPocketRepository.findByCoupleIdAndIsActiveTrue(couple.id) } returns listOf(pocket1, pocket2)
        justRun { distributionRatioRepository.deleteByCoupleId(couple.id) }
        val ratioSlot = slot<DistributionRatio>()
        every { distributionRatioRepository.save(capture(ratioSlot)) } answers { ratioSlot.captured }

        When("saving valid ratios that sum to 100") {
            val request = SaveDistributionRatiosRequest(
                ratios = listOf(
                    RatioEntry(pocket1.id, BigDecimal("60.00")),
                    RatioEntry(pocket2.id, BigDecimal("40.00"))
                )
            )
            val result = service.saveRatios(user1.id, request)

            Then("deletes old ratios and saves new ones") {
                verify(exactly = 1) { distributionRatioRepository.deleteByCoupleId(couple.id) }
                result shouldHaveSize 2
                result[0].ratio shouldBe BigDecimal("60.00")
                result[1].ratio shouldBe BigDecimal("40.00")
            }
        }
    }

    Given("ratios that do not sum to 100") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("saving ratios summing to 90") {
            val request = SaveDistributionRatiosRequest(
                ratios = listOf(
                    RatioEntry(pocket1.id, BigDecimal("50.00")),
                    RatioEntry(pocket2.id, BigDecimal("40.00"))
                )
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.saveRatios(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("ratios with an invalid pocket ID") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { moneyPocketRepository.findByCoupleIdAndIsActiveTrue(couple.id) } returns listOf(pocket1)

        When("saving ratios referencing a non-existent pocket") {
            val fakePocketId = java.util.UUID.randomUUID()
            val request = SaveDistributionRatiosRequest(
                ratios = listOf(
                    RatioEntry(pocket1.id, BigDecimal("60.00")),
                    RatioEntry(fakePocketId, BigDecimal("40.00"))
                )
            )

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.saveRatios(user1.id, request)
                }
                ex.code shouldBe "POCKET_NOT_FOUND"
            }
        }
    }

    Given("ratios with duplicate pocket IDs") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { moneyPocketRepository.findByCoupleIdAndIsActiveTrue(couple.id) } returns listOf(pocket1, pocket2)

        When("saving ratios with duplicated pocket") {
            val request = SaveDistributionRatiosRequest(
                ratios = listOf(
                    RatioEntry(pocket1.id, BigDecimal("50.00")),
                    RatioEntry(pocket1.id, BigDecimal("50.00"))
                )
            )

            Then("throws BusinessException for duplicate") {
                val ex = shouldThrow<BusinessException> {
                    service.saveRatios(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- getActiveCouple error ---

    Given("a user not in an active couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("getRatios is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.getRatios(user1.id)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }
})
