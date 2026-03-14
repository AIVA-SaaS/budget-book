package com.budgetbook.transaction.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldStartWith
import io.mockk.every
import io.mockk.mockk
import org.springframework.data.domain.Sort
import org.springframework.data.jpa.domain.Specification
import java.time.LocalDate

class TransactionExportServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val coupleRepository = mockk<CoupleRepository>()
    val service = TransactionExportService(transactionRepository, coupleRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    val category = Category(
        couple = couple,
        name = "식비",
        type = CategoryType.EXPENSE,
        icon = "restaurant",
        color = "#FF0000"
    )

    val paymentMethod = PaymentMethod(
        couple = couple,
        name = "신한카드",
        type = PaymentMethodType.CREDIT
    )

    Given("a couple with transactions") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val tx1 = Transaction(
            couple = couple,
            author = user1,
            category = category,
            type = TransactionType.EXPENSE,
            amount = 15000,
            description = "점심식사",
            memo = "맛있었다",
            transactionDate = LocalDate.of(2026, 3, 5),
            paymentMethod = paymentMethod
        )

        val tx2 = Transaction(
            couple = couple,
            author = user1,
            category = null,
            type = TransactionType.INCOME,
            amount = 3000000,
            description = "월급",
            memo = null,
            transactionDate = LocalDate.of(2026, 3, 1)
        )

        every { transactionRepository.findAll(any<Specification<Transaction>>(), any<Sort>()) } returns listOf(tx2, tx1)

        When("exportCsv is called for 2026-03") {
            val csv = service.exportCsv(user1.id, 2026, 3, null, null)

            Then("CSV starts with BOM") {
                csv shouldStartWith "\uFEFF"
            }

            Then("CSV has header row") {
                csv shouldContain "날짜,유형,카테고리,설명,금액,메모,결제수단"
            }

            Then("CSV contains transaction data") {
                csv shouldContain "2026-03-01,수입,,월급,3000000,,"
                csv shouldContain "2026-03-05,지출,식비,점심식사,15000,맛있었다,신한카드"
            }
        }
    }

    Given("a couple with no transactions") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple
        every { transactionRepository.findAll(any<Specification<Transaction>>(), any<Sort>()) } returns emptyList()

        When("exportCsv is called") {
            val csv = service.exportCsv(user1.id, 2026, 3, null, null)

            Then("CSV contains only header") {
                val lines = csv.lines().filter { it.isNotBlank() }
                lines.size shouldBe 1
                lines[0] shouldContain "날짜,유형,카테고리,설명,금액,메모,결제수단"
            }
        }
    }

    Given("a transaction with CSV-special characters in description") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        val tx = Transaction(
            couple = couple,
            author = user1,
            type = TransactionType.EXPENSE,
            amount = 5000,
            description = "커피, 케이크",
            memo = "He said \"hello\"",
            transactionDate = LocalDate.of(2026, 3, 10)
        )

        every { transactionRepository.findAll(any<Specification<Transaction>>(), any<Sort>()) } returns listOf(tx)

        When("exportCsv is called") {
            val csv = service.exportCsv(user1.id, 2026, 3, null, null)

            Then("fields with commas/quotes are properly escaped") {
                csv shouldContain "\"커피, 케이크\""
                csv shouldContain "\"He said \"\"hello\"\"\""
            }
        }
    }

    Given("an invalid transaction type for export") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns couple

        When("exportCsv is called with invalid type") {
            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.exportCsv(user1.id, 2026, 3, "INVALID", null)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("a user not in an active couple") {
        every { coupleRepository.findByUserIdAndStatus(user1.id, CoupleStatus.ACTIVE) } returns null

        When("exportCsv is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.exportCsv(user1.id, 2026, 3, null, null)
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }
})
