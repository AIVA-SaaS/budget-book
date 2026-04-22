package com.budgetbook.statistics.service

import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.domain.TransferKinds
import com.budgetbook.transfer.repository.TransferRepository
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import java.time.LocalDate
import java.util.UUID

/**
 * Phase 22 — ExpenseCalculator 의 kind 기반 집계 검증.
 */
class ExpenseCalculatorTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val transferRepository = mockk<TransferRepository>()
    val calculator = ExpenseCalculator(transactionRepository, transferRepository)

    val coupleId = UUID.randomUUID()
    val userId = UUID.randomUUID()
    val from = LocalDate.of(2026, 4, 1)
    val to = LocalDate.of(2026, 4, 30)

    Given("Transaction EXPENSE + EXPENSE_TRANSFER 이 혼재") {
        every {
            transactionRepository.sumByTypeForCouple(coupleId, from, to, userId, "ALL")
        } returns listOf(
            arrayOf(TransactionType.EXPENSE, 500000L, 5L),
            arrayOf(TransactionType.INCOME, 1000000L, 3L),
            // ADJUSTMENT 가 DB 에서 반환되더라도 집계에서 제외되어야 함
            arrayOf(TransactionType.ADJUSTMENT, 200000L, 1L)
        )
        every {
            transferRepository.sumAmountBySourceByKind(coupleId, from, to, TransferKinds.EXPENSE_AFFECTING)
        } returns listOf(arrayOf<Any>(UUID.randomUUID(), 100000L))
        every {
            transferRepository.sumAmountByDestinationByKind(coupleId, from, to, TransferKinds.INCOME_AFFECTING)
        } returns listOf(arrayOf<Any>(UUID.randomUUID(), 300000L))
        every {
            transferRepository.sumAmountBySourceByKind(coupleId, from, to, TransferKinds.TRANSFER_ONLY)
        } returns listOf(arrayOf<Any>(UUID.randomUUID(), 50000L))

        When("totalExpense 계산") {
            val result = calculator.totalExpense(coupleId, from, to, userId, "ALL")
            Then("EXPENSE Transaction + EXPENSE_TRANSFER 만 합산 (ADJUSTMENT 제외)") {
                result shouldBe 600000L // 500000 + 100000
            }
        }

        When("totalIncome 계산") {
            val result = calculator.totalIncome(coupleId, from, to, userId, "ALL")
            Then("INCOME Transaction + INCOME_TRANSFER 만 합산") {
                result shouldBe 1300000L // 1000000 + 300000
            }
        }

        When("totalTransfer 계산") {
            val result = calculator.totalTransfer(coupleId, from, to)
            Then("GENERIC Transfer 만 합산") {
                result shouldBe 50000L
            }
        }
    }

    Given("Transaction ADJUSTMENT 만 존재") {
        every {
            transactionRepository.sumByTypeForCouple(coupleId, from, to, userId, "ALL")
        } returns listOf(
            arrayOf(TransactionType.ADJUSTMENT, 100000L, 1L)
        )
        every {
            transferRepository.sumAmountBySourceByKind(coupleId, from, to, any())
        } returns emptyList()
        every {
            transferRepository.sumAmountByDestinationByKind(coupleId, from, to, any())
        } returns emptyList()

        When("totalExpense 계산") {
            val result = calculator.totalExpense(coupleId, from, to, userId, "ALL")
            Then("ADJUSTMENT 은 집계 제외 → 0") {
                result shouldBe 0L
            }
        }

        When("totalIncome 계산") {
            val result = calculator.totalIncome(coupleId, from, to, userId, "ALL")
            Then("ADJUSTMENT 은 집계 제외 → 0") {
                result shouldBe 0L
            }
        }
    }

    Given("CARD_SETTLEMENT 이체가 존재하지만 나머지 집계에는 영향 없음") {
        // CARD_SETTLEMENT kind 은 EXPENSE_AFFECTING/INCOME_AFFECTING/TRANSFER_ONLY 어디에도 포함되지 않음.
        // 즉 Repository 에 해당 kind 필터링 쿼리가 오더라도 빈 결과를 돌려줘야 (Phase 22 구조적 원칙).
        every {
            transactionRepository.sumByTypeForCouple(coupleId, from, to, userId, "ALL")
        } returns listOf(
            arrayOf(TransactionType.EXPENSE, 1000000L, 10L)
        )
        every {
            transferRepository.sumAmountBySourceByKind(coupleId, from, to, TransferKinds.EXPENSE_AFFECTING)
        } returns emptyList()
        every {
            transferRepository.sumAmountByDestinationByKind(coupleId, from, to, TransferKinds.INCOME_AFFECTING)
        } returns emptyList()
        every {
            transferRepository.sumAmountBySourceByKind(coupleId, from, to, TransferKinds.TRANSFER_ONLY)
        } returns emptyList()

        When("totalExpense 계산") {
            val result = calculator.totalExpense(coupleId, from, to, userId, "ALL")
            Then("CARD_SETTLEMENT 은 집계 제외. Transaction 만 반영") {
                result shouldBe 1000000L
            }
        }
    }
})
