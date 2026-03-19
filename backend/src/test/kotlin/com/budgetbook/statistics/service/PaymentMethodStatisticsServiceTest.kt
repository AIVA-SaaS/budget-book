package com.budgetbook.statistics.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.time.LocalDate
import java.util.UUID

class PaymentMethodStatisticsServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val service = PaymentMethodStatisticsService(transactionRepository, coupleResolver)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    val pmId1 = UUID.randomUUID()
    val pmId2 = UUID.randomUUID()

    Given("a user in an active couple with payment method spending") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        every {
            transactionRepository.sumByPaymentMethodForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                any()
            )
        } returns listOf(
            arrayOf(pmId1, "Shinhan Card", 800000L, 20L),
            arrayOf(pmId2, "Cash", 200000L, 15L)
        )

        When("getPaymentMethodStats is called") {
            val result = service.getPaymentMethodStats(user1.id, 2026, 3)

            Then("returns statistics for each payment method") {
                result shouldHaveSize 2
            }

            Then("first payment method has correct values") {
                result[0].paymentMethodId shouldBe pmId1.toString()
                result[0].paymentMethodName shouldBe "Shinhan Card"
                result[0].totalAmount shouldBe 800000L
                result[0].transactionCount shouldBe 20
                result[0].percentage shouldBe 80.0
            }

            Then("second payment method has correct values") {
                result[1].paymentMethodId shouldBe pmId2.toString()
                result[1].paymentMethodName shouldBe "Cash"
                result[1].totalAmount shouldBe 200000L
                result[1].transactionCount shouldBe 15
                result[1].percentage shouldBe 20.0
            }
        }
    }

    Given("a user with no expense transactions") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        every {
            transactionRepository.sumByPaymentMethodForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                any()
            )
        } returns emptyList()

        When("getPaymentMethodStats is called") {
            val result = service.getPaymentMethodStats(user1.id, 2026, 3)

            Then("returns empty list") {
                result shouldHaveSize 0
            }
        }
    }

    Given("a single payment method used for all expenses") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        every {
            transactionRepository.sumByPaymentMethodForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                any()
            )
        } returns listOf(
            arrayOf(pmId1, "KB Card", 500000L, 30L)
        )

        When("getPaymentMethodStats is called") {
            val result = service.getPaymentMethodStats(user1.id, 2026, 3)

            Then("single payment method has 100% share") {
                result shouldHaveSize 1
                result[0].percentage shouldBe 100.0
                result[0].totalAmount shouldBe 500000L
                result[0].transactionCount shouldBe 30
            }
        }
    }

    Given("a user not in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("getPaymentMethodStats is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.getPaymentMethodStats(user1.id, 2026, 3)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    Given("three payment methods with varying amounts") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val pmId3 = UUID.randomUUID()

        every {
            transactionRepository.sumByPaymentMethodForCouple(
                couple.id,
                LocalDate.of(2026, 3, 1),
                LocalDate.of(2026, 3, 31),
                any()
            )
        } returns listOf(
            arrayOf(pmId1, "Card A", 700000L, 10L),
            arrayOf(pmId2, "Card B", 200000L, 5L),
            arrayOf(pmId3, "Cash", 100000L, 20L)
        )

        When("getPaymentMethodStats is called") {
            val result = service.getPaymentMethodStats(user1.id, 2026, 3)

            Then("percentages add up correctly") {
                result shouldHaveSize 3
                result[0].percentage shouldBe 70.0
                result[1].percentage shouldBe 20.0
                result[2].percentage shouldBe 10.0
            }
        }
    }
})
