package com.budgetbook.statistics.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.budget.repository.MonthlyBudgetRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.spendingplan.repository.SpendingPlanRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.domain.Transfer
import com.budgetbook.transfer.domain.TransferKind
import com.budgetbook.transfer.repository.TransferRepository
import org.springframework.data.jpa.domain.Specification
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

class StatisticsServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val transferRepository = mockk<TransferRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val budgetRepository = mockk<MonthlyBudgetRepository>()
    val spendingPlanRepository = mockk<SpendingPlanRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    // Phase 22: StatisticsService 는 ExpenseCalculator 를 통해 집계. 실제 ExpenseCalculator 주입하면
    // 내부적으로 transactionRepository + transferRepository 를 다시 사용한다.
    val expenseCalculator = com.budgetbook.statistics.service.ExpenseCalculator(transactionRepository, transferRepository)
    val service = StatisticsService(
        transactionRepository,
        transferRepository,
        coupleResolver,
        budgetRepository,
        spendingPlanRepository,
        categoryRepository,
        expenseCalculator,
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val fixturePaymentMethod = PaymentMethod(couple = couple, name = "주계좌", type = PaymentMethodType.BANK)

    // Default: no transfers (individual tests can override)
    // Phase 22: kind 기반 쿼리로 전환. 기존 ExcludingSettlement 계열은 deprecated 지만 호환을 위해 유지.
    every { transferRepository.sumAmountBySourceExcludingSettlement(any(), any(), any()) } returns emptyList()
    every { transferRepository.sumAmountByDestinationExcludingSettlement(any(), any(), any()) } returns emptyList()
    every { transferRepository.sumAmountBySourceByKind(any(), any(), any(), any()) } returns emptyList()
    every { transferRepository.sumAmountByDestinationByKind(any(), any(), any(), any()) } returns emptyList()
    // 2026-08-12 — 합계는 거래·이체 모두 spec 조회를 탄다. 기본은 "결과 없음".
    every { transactionRepository.findAll(any<Specification<Transaction>>()) } returns emptyList()
    every { transferRepository.findAll(any<Specification<Transfer>>()) } returns emptyList()

    fun txOf(type: TransactionType, amount: Long, date: LocalDate = LocalDate.of(2026, 3, 15)) =
        Transaction(
            couple = couple, author = user1, type = type, amount = amount,
            description = "fixture", transactionDate = date
        )

    fun transferOf(kind: TransferKind, amount: Long, date: LocalDate = LocalDate.of(2026, 3, 15)) =
        Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = fixturePaymentMethod, destinationPaymentMethod = fixturePaymentMethod,
            amount = amount, description = "fixture", transferDate = date, kind = kind
        )

    // --- getMonthlySummary ---
    //
    // 2026-08-12 — 합계는 **단일 경로**다. 이전에는 "필터 없으면 집계 SQL / 있으면 spec" 두
    // 갈래였고 이체 포함 규칙이 갈래마다 달라 "합계 ≠ 행" 이 생겼다. 이제 거래는 항상
    // spec 1회 조회 후 타입별 fold, 이체는 항상 TransferGating 판정으로 집계한다.

    Given("a user in an active couple for monthly summary") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("there are income and expense transactions with default visibility") {
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(
                txOf(TransactionType.INCOME, 5_000_000L),
                txOf(TransactionType.EXPENSE, 2_000_000L),
                txOf(TransactionType.EXPENSE, 1_200_000L),
            )

            val result = service.getMonthlySummary(user1.id, 2026, 3)

            Then("returns correct summary") {
                result.yearMonth shouldBe "2026-03"
                result.totalIncome shouldBe 5000000L
                result.totalExpense shouldBe 3200000L
                result.balance shouldBe 1800000L
                result.transactionCount shouldBe 3
            }

            Then("counts no transfers when there are none") {
                result.totalTransfer shouldBe 0L
                result.transferCount shouldBe 0
            }
        }

        When("transfers of every kind exist in the month") {
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(txOf(TransactionType.EXPENSE, 1_000_000L))
            every {
                transferRepository.findAll(any<Specification<Transfer>>())
            } returns listOf(
                transferOf(TransferKind.EXPENSE_TRANSFER, 300_000L),
                transferOf(TransferKind.INCOME_TRANSFER, 200_000L),
                transferOf(TransferKind.GENERIC, 500_000L),
                transferOf(TransferKind.CARD_SETTLEMENT, 900_000L),
            )

            val result = service.getMonthlySummary(user1.id, 2026, 3)

            // 집계식은 ExpenseCalculator KDoc + FE LedgerSummary 와 동일해야 한다.
            Then("EXPENSE_TRANSFER lands in expense and INCOME_TRANSFER in income") {
                result.totalExpense shouldBe 1_300_000L
                result.totalIncome shouldBe 200_000L
            }

            Then("GENERIC is the transfer bucket and CARD_SETTLEMENT is excluded everywhere") {
                result.totalTransfer shouldBe 500_000L
                // CARD_SETTLEMENT 는 어느 버킷에도 없고 건수에도 세지 않는다.
                result.transferCount shouldBe 3
            }
        }

        // 이번 회차의 핵심 회귀 가드 — 필터가 켜져도 이체가 합계에서 사라지지 않는다.
        // (이전: hasContentFilters == true → totalTransfer = 0 + 이체 legs 누락)
        When("a content filter that keeps transfers is active (amount range)") {
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(txOf(TransactionType.EXPENSE, 50_000L))
            every {
                transferRepository.findAll(any<Specification<Transfer>>())
            } returns listOf(
                transferOf(TransferKind.EXPENSE_TRANSFER, 80_000L),
                transferOf(TransferKind.GENERIC, 90_000L),
            )

            val result = service.getMonthlySummary(
                user1.id, 2026, 3, CommonFilterParams(amountMin = 10_000, amountMax = 100_000)
            )

            Then("transfers still count toward the totals") {
                result.totalExpense shouldBe 130_000L
                result.totalTransfer shouldBe 90_000L
            }
        }

        // 이체에 없는 축이 켜지면 이체는 조회조차 하지 않는다 (목록도 같은 판정 → 양쪽이 함께 사라진다).
        When("a filter axis absent from transfers is active (category)") {
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(txOf(TransactionType.EXPENSE, 70_000L))
            // 이체 stub 은 비어있지 않다 — 그래도 합계에 잡히지 않아야 전량 제외가 증명된다.
            every {
                transferRepository.findAll(any<Specification<Transfer>>())
            } returns listOf(transferOf(TransferKind.GENERIC, 55_000L))
            every { categoryRepository.findByGroupIdIn(any()) } returns emptyList()

            val result = service.getMonthlySummary(
                user1.id, 2026, 3, CommonFilterParams(categoryId = UUID.randomUUID())
            )

            Then("transfers are excluded wholesale") {
                result.totalExpense shouldBe 70_000L
                result.totalTransfer shouldBe 0L
                result.transferCount shouldBe 0
            }
        }

        // "이체만 보기" — 거래는 0건이어야 한다. 예전에는 FE 가 TRANSFER 를 잘라 보내
        // 서버가 "필터 없음" 으로 해석해 거래 전체를 합계에 넣었다.
        When("only TRANSFER is selected") {
            // 거래 조회가 **일어나도** 결과에 반영되지 않아야 한다는 것이 아니라,
            // 애초에 거래를 세지 않는다는 것이 정답이다. 그래서 stub 은 일부러 비어있지 않다 —
            // 합계가 0 이면 거래 경로를 타지 않았다는 증거다.
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(txOf(TransactionType.EXPENSE, 999_000L))
            every {
                transferRepository.findAll(any<Specification<Transfer>>())
            } returns listOf(transferOf(TransferKind.GENERIC, 400_000L))

            val result = service.getMonthlySummary(
                user1.id, 2026, 3, CommonFilterParams(transactionTypes = listOf("TRANSFER"))
            )

            Then("transactions are not counted and only the transfer bucket is filled") {
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 0L
                result.transactionCount shouldBe 0
                result.totalTransfer shouldBe 400_000L
            }
        }

        When("EXPENSE and TRANSFER are selected together") {
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(txOf(TransactionType.EXPENSE, 60_000L))
            every {
                transferRepository.findAll(any<Specification<Transfer>>())
            } returns listOf(transferOf(TransferKind.GENERIC, 30_000L))

            val result = service.getMonthlySummary(
                user1.id, 2026, 3,
                CommonFilterParams(transactionTypes = listOf("EXPENSE", "TRANSFER"))
            )

            Then("both streams contribute") {
                result.totalExpense shouldBe 60_000L
                result.totalTransfer shouldBe 30_000L
            }
        }

        When("visibility is SHARED") {
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(
                txOf(TransactionType.INCOME, 3_000_000L),
                txOf(TransactionType.EXPENSE, 2_000_000L),
            )

            val result = service.getMonthlySummary(user1.id, 2026, 3, CommonFilterParams(visibility = "SHARED"))

            // visibility 자체가 spec 에 실려 나가는지는 mock 으로 확인할 수 없다
            // (Specification 내부는 들여다볼 수 없다) → 실 DB 계약 테스트가 담당한다:
            // LedgerSummaryRowContractIntegrationTest.
            Then("returns shared-only summary") {
                result.totalIncome shouldBe 3000000L
                result.totalExpense shouldBe 2000000L
                result.transactionCount shouldBe 2
            }
        }

        When("visibility is PRIVATE") {
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(txOf(TransactionType.EXPENSE, 500_000L))

            val result = service.getMonthlySummary(user1.id, 2026, 3, CommonFilterParams(visibility = "PRIVATE"))

            Then("returns private-only summary") {
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 500000L
                result.transactionCount shouldBe 1
            }

            // 이체엔 visibility 가 없다 → 개인 필터에서는 이체를 노출하지 않는다.
            Then("transfers are excluded for the PRIVATE view") {
                result.totalTransfer shouldBe 0L
                result.transferCount shouldBe 0
            }
        }

        When("there are no transactions") {
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns emptyList()

            val result = service.getMonthlySummary(user1.id, 2026, 1)

            Then("returns zero values") {
                result.yearMonth shouldBe "2026-01"
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 0L
                result.balance shouldBe 0L
                result.transactionCount shouldBe 0
            }
        }

        When("invalid visibility is provided") {
            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    service.getMonthlySummary(user1.id, 2026, 3, CommonFilterParams(visibility = "INVALID"))
                }.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("a user NOT in a couple for monthly summary") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("requesting summary") {
            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    service.getMonthlySummary(user1.id, 2026, 3)
                }.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    // --- getCategoryBreakdown ---

    Given("a user in an active couple for category breakdown") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val catId1 = UUID.randomUUID()
        val catId2 = UUID.randomUUID()

        When("there are expense transactions by category with default visibility") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    TransactionType.EXPENSE,
                    any(),
                    "ALL"
                )
            } returns listOf(
                arrayOf<Any?>(800000L, 12L, catId1, "식비", com.budgetbook.category.domain.CategoryType.EXPENSE, "restaurant", "#FF5733", null, null),
                arrayOf<Any?>(320000L, 8L, catId2, "교통비", com.budgetbook.category.domain.CategoryType.EXPENSE, "directions_car", "#2196F3", null, null)
            )

            val result = service.getCategoryBreakdown(user1.id, 2026, 3, "EXPENSE")

            Then("returns category statistics sorted by amount DESC") {
                result shouldHaveSize 2
                result[0].category.name shouldBe "식비"
                result[0].amount shouldBe 800000L
                result[0].percentage shouldBe 71.4
                result[0].transactionCount shouldBe 12
                result[1].category.name shouldBe "교통비"
                result[1].amount shouldBe 320000L
                result[1].transactionCount shouldBe 8
            }
        }

        When("visibility is SHARED for category breakdown") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    TransactionType.EXPENSE,
                    any(),
                    "SHARED"
                )
            } returns listOf(
                arrayOf<Any?>(600000L, 8L, catId1, "식비", com.budgetbook.category.domain.CategoryType.EXPENSE, "restaurant", "#FF5733", null, null)
            )

            val result = service.getCategoryBreakdown(user1.id, 2026, 3, "EXPENSE", "SHARED")

            Then("returns shared-only category breakdown") {
                result shouldHaveSize 1
                result[0].amount shouldBe 600000L
            }

            Then("passes SHARED to repository") {
                verify {
                    transactionRepository.sumByCategoryForCouple(
                        couple.id, any(), any(), TransactionType.EXPENSE, any(), "SHARED"
                    )
                }
            }
        }

        When("type is null, defaults to EXPENSE") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id,
                    LocalDate.of(2026, 3, 1),
                    LocalDate.of(2026, 3, 31),
                    TransactionType.EXPENSE,
                    any(),
                    "ALL"
                )
            } returns emptyList()

            val result = service.getCategoryBreakdown(user1.id, 2026, 3, null)

            Then("returns empty list") {
                result shouldHaveSize 0
            }
        }

        When("invalid type is provided") {
            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    service.getCategoryBreakdown(user1.id, 2026, 3, "INVALID")
                }.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- getMonthlyTrend ---

    Given("a user in an active couple for monthly trend") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("requesting 3 months of trend data with default visibility") {
            val now = YearMonth.now()
            val startMonth = now.minusMonths(2)

            every {
                transactionRepository.monthlyTrendForCouple(
                    couple.id,
                    startMonth.atDay(1),
                    now.atEndOfMonth(),
                    any(),
                    "ALL"
                )
            } returns listOf(
                arrayOf(startMonth.toString(), "INCOME", 4000000L),
                arrayOf(startMonth.toString(), "EXPENSE", 3000000L),
                arrayOf(now.toString(), "INCOME", 5000000L),
                arrayOf(now.toString(), "EXPENSE", 3200000L)
            )

            val result = service.getMonthlyTrend(user1.id, 3)

            Then("returns 3 months with zeros for missing month") {
                result shouldHaveSize 3
                result[0].yearMonth shouldBe startMonth.toString()
                result[0].totalIncome shouldBe 4000000L
                result[0].totalExpense shouldBe 3000000L
                result[0].balance shouldBe 1000000L

                // Middle month has no data
                result[1].totalIncome shouldBe 0L
                result[1].totalExpense shouldBe 0L
                result[1].balance shouldBe 0L

                result[2].yearMonth shouldBe now.toString()
                result[2].totalIncome shouldBe 5000000L
                result[2].totalExpense shouldBe 3200000L
                result[2].balance shouldBe 1800000L
            }
        }

        When("requesting trend with SHARED visibility") {
            val now = YearMonth.now()
            val startMonth = now.minusMonths(2)

            every {
                transactionRepository.monthlyTrendForCouple(
                    couple.id,
                    startMonth.atDay(1),
                    now.atEndOfMonth(),
                    any(),
                    "SHARED"
                )
            } returns listOf(
                arrayOf(now.toString(), "INCOME", 2000000L),
                arrayOf(now.toString(), "EXPENSE", 1000000L)
            )

            val result = service.getMonthlyTrend(user1.id, 3, "SHARED")

            Then("returns trend data filtered by SHARED") {
                result shouldHaveSize 3
                result[2].totalIncome shouldBe 2000000L
                result[2].totalExpense shouldBe 1000000L
            }

            Then("passes SHARED to repository") {
                verify {
                    transactionRepository.monthlyTrendForCouple(
                        couple.id, any(), any(), any(), "SHARED"
                    )
                }
            }
        }

        When("months parameter exceeds max") {
            val now = YearMonth.now()
            val startMonth = now.minusMonths(23)

            every {
                transactionRepository.monthlyTrendForCouple(
                    couple.id,
                    startMonth.atDay(1),
                    now.atEndOfMonth(),
                    any(),
                    "ALL"
                )
            } returns emptyList()

            val result = service.getMonthlyTrend(user1.id, 100)

            Then("is clamped to 24 months") {
                result shouldHaveSize 24
            }
        }

        When("invalid visibility is provided for trend") {
            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    service.getMonthlyTrend(user1.id, 3, "INVALID")
                }.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- getMonthlySummary with dateFrom/dateTo (C-11) ---

    Given("a user requesting summary with custom date range") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("dateFrom and dateTo are provided") {
            val customStart = LocalDate.of(2026, 3, 10)
            val customEnd = LocalDate.of(2026, 3, 20)

            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns List(5) { txOf(TransactionType.EXPENSE, 100_000L, customStart) }

            val result = service.getMonthlySummary(user1.id, 2026, 3, CommonFilterParams(dateFrom = customStart, dateTo = customEnd))

            Then("uses the custom date range instead of full month") {
                result.totalExpense shouldBe 500000L
                result.transactionCount shouldBe 5
            }
        }

        When("only dateFrom is provided, dateTo defaults to end of month") {
            val customStart = LocalDate.of(2026, 3, 15)

            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(txOf(TransactionType.INCOME, 300_000L, customStart))

            val result = service.getMonthlySummary(user1.id, 2026, 3, CommonFilterParams(dateFrom = customStart))

            Then("uses dateFrom with month end as dateTo") {
                result.totalIncome shouldBe 300000L
            }
        }
    }

    // --- getCategoryBreakdown with dateFrom/dateTo (C-11) ---

    Given("a user requesting category breakdown with custom date range") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val catId = UUID.randomUUID()
        val customStart = LocalDate.of(2026, 3, 1)
        val customEnd = LocalDate.of(2026, 3, 15)

        When("dateFrom and dateTo are provided") {
            every {
                transactionRepository.sumByCategoryForCouple(
                    couple.id, customStart, customEnd, TransactionType.EXPENSE, any(), "ALL"
                )
            } returns listOf(
                arrayOf<Any?>(200000L, 4L, catId, "식비", com.budgetbook.category.domain.CategoryType.EXPENSE, "restaurant", "#FF5733", null, null)
            )

            val result = service.getCategoryBreakdown(user1.id, 2026, 3, "EXPENSE", "ALL", customStart, customEnd)

            Then("uses the custom date range") {
                result shouldHaveSize 1
                result[0].amount shouldBe 200000L
                result[0].transactionCount shouldBe 4
            }
        }
    }

    // --- getPeriodSummary ---

    Given("a user in an active couple for period summary") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val dateFrom = LocalDate.of(2026, 3, 1)
        val dateTo = LocalDate.of(2026, 3, 31)
        val catId1 = UUID.randomUUID()
        val catId2 = UUID.randomUUID()

        When("requesting period summary with data") {
            // 2026-08-12 — 총액은 getMonthlySummary 와 같은 spec 경로에서 나온다.
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(
                txOf(TransactionType.INCOME, 5_000_000L, dateFrom),
                txOf(TransactionType.EXPENSE, 3_200_000L, dateFrom),
            )

            // sumByCategoryForCouple
            every {
                transactionRepository.sumByCategoryForCouple(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, any(), "ALL")
            } returns listOf(
                arrayOf<Any?>(2000000L, 15L, catId1, "식비", com.budgetbook.category.domain.CategoryType.EXPENSE, "restaurant", "#FF5733", null, null),
                arrayOf<Any?>(1200000L, 20L, catId2, "교통비", com.budgetbook.category.domain.CategoryType.EXPENSE, "directions_car", "#2196F3", null, null)
            )

            // budgets
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()

            // sumAmountByCoupleIdAndDateRange (total spent)
            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 3200000L

            // spending plan
            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id, any(), any()) } returns 0L

            // byPaymentMethod
            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            // dailySummary
            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns listOf(
                arrayOf<Any>(java.sql.Date.valueOf(dateFrom), "INCOME", 2000000L, 3L),
                arrayOf<Any>(java.sql.Date.valueOf(dateFrom), "EXPENSE", 1000000L, 10L),
                arrayOf<Any>(java.sql.Date.valueOf(LocalDate.of(2026, 3, 15)), "EXPENSE", 2200000L, 25L)
            )

            val result = service.getPeriodSummary(user1.id, dateFrom, dateTo)

            Then("returns correct totals") {
                result.dateFrom shouldBe "2026-03-01"
                result.dateTo shouldBe "2026-03-31"
                result.totalIncome shouldBe 5000000L
                result.totalExpense shouldBe 3200000L
                result.balance shouldBe 1800000L
            }

            Then("returns category breakdown with percentages") {
                result.byCategory shouldHaveSize 2
                result.byCategory[0].categoryName shouldBe "식비"
                result.byCategory[0].amount shouldBe 2000000L
                result.byCategory[0].percentage shouldBe 62.5
                result.byCategory[1].categoryName shouldBe "교통비"
                result.byCategory[1].amount shouldBe 1200000L
                result.byCategory[1].percentage shouldBe 37.5
            }

            Then("returns daily spending") {
                result.byDate shouldHaveSize 2
                result.byDate[0].date shouldBe "2026-03-01"
                result.byDate[0].income shouldBe 2000000L
                result.byDate[0].expense shouldBe 1000000L
                result.byDate[1].date shouldBe "2026-03-15"
                result.byDate[1].income shouldBe 0L
                result.byDate[1].expense shouldBe 2200000L
            }
        }

        When("requesting period summary with no data") {
            every {
                transactionRepository.sumByTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            every {
                transactionRepository.sumByCategoryForCouple(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, any(), "ALL")
            } returns emptyList()

            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()

            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 0L

            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id, any(), any()) } returns 0L

            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            val result = service.getPeriodSummary(user1.id, dateFrom, dateTo)

            Then("returns zero values") {
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 0L
                result.balance shouldBe 0L
                result.byCategory shouldHaveSize 0
                result.byBudget shouldHaveSize 0
                result.byPaymentMethod shouldHaveSize 0
                result.byDate shouldHaveSize 0
            }
        }

        When("invalid visibility is provided for period summary") {
            Then("throws BusinessException") {
                shouldThrow<BusinessException> {
                    service.getPeriodSummary(user1.id, dateFrom, dateTo, CommonFilterParams(visibility = "INVALID"))
                }.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- getPeriodSummary: Transfer inclusion (matching getMonthlySummary behavior) ---

    Given("a user for period summary with transfers") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val dateFrom = LocalDate.of(2026, 3, 1)
        val dateTo = LocalDate.of(2026, 3, 31)

        When("transfers exist in the period") {
            // Transaction totals
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(
                txOf(TransactionType.INCOME, 5_000_000L, dateFrom),
                txOf(TransactionType.EXPENSE, 3_000_000L, dateFrom),
            )
            every {
                transactionRepository.sumByCategoryForCouple(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, any(), "ALL")
            } returns emptyList()
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()
            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 3000000L
            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id, any(), any()) } returns 0L
            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()
            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            // 2026-08-12 — 이체 집계는 kind 별 쿼리 대신 `TransferGating.spec` 1회 조회 + fold.
            // (이체 목록 조회와 같은 판정을 쓰기 위한 통일. EXPENSE_TRANSFER=200000, INCOME_TRANSFER=100000)
            every {
                transferRepository.findAll(any<Specification<Transfer>>())
            } returns listOf(
                transferOf(TransferKind.EXPENSE_TRANSFER, 200_000L, dateFrom),
                transferOf(TransferKind.INCOME_TRANSFER, 100_000L, dateFrom),
            )

            val result = service.getPeriodSummary(user1.id, dateFrom, dateTo)

            Then("totalExpense includes EXPENSE_TRANSFER amounts") {
                result.totalExpense shouldBe 3200000L // 3000000 + 200000
            }

            Then("totalIncome includes INCOME_TRANSFER amounts") {
                result.totalIncome shouldBe 5100000L // 5000000 + 100000
            }

            Then("balance reflects kind-adjusted totals") {
                result.balance shouldBe 1900000L // 5100000 - 3200000
            }
        }
    }

    // --- getPeriodSummary: summary vs period-summary consistency ---

    Given("consistency between getMonthlySummary and getPeriodSummary") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val dateFrom = LocalDate.of(2026, 4, 1)
        val dateTo = LocalDate.of(2026, 4, 30)
        val pmId = UUID.randomUUID()

        When("same period data is queried via both endpoints") {
            // Same transaction data for both — 이제 두 엔드포인트가 같은 spec 경로를 탄다.
            every {
                transactionRepository.findAll(any<Specification<Transaction>>())
            } returns listOf(
                txOf(TransactionType.INCOME, 4_000_000L, dateFrom),
                txOf(TransactionType.EXPENSE, 2_500_000L, dateFrom),
            )

            // Transfers
            every {
                transferRepository.sumAmountBySourceExcludingSettlement(couple.id, dateFrom, dateTo)
            } returns listOf(arrayOf<Any>(pmId, 300000L))
            every {
                transferRepository.sumAmountByDestinationExcludingSettlement(couple.id, dateFrom, dateTo)
            } returns listOf(arrayOf<Any>(pmId, 150000L))

            // Additional mocks for getPeriodSummary
            every {
                transactionRepository.sumByCategoryForCouple(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, any(), "ALL")
            } returns emptyList()
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-04", user1.id) } returns emptyList()
            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 2500000L
            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id, any(), any()) } returns 0L
            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()
            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            val summaryResult = service.getMonthlySummary(user1.id, 2026, 4, CommonFilterParams(dateFrom = dateFrom, dateTo = dateTo))
            val periodResult = service.getPeriodSummary(user1.id, dateFrom, dateTo)

            Then("totalIncome matches between summary and period-summary") {
                periodResult.totalIncome shouldBe summaryResult.totalIncome
            }

            Then("totalExpense matches between summary and period-summary") {
                periodResult.totalExpense shouldBe summaryResult.totalExpense
            }

            Then("balance matches between summary and period-summary") {
                periodResult.balance shouldBe summaryResult.balance
            }
        }
    }

    // --- getMonthlySummary: needsReviewOnly (2026-07-27 회귀 가드) ---

    Given("a user filtering the ledger by needs_review") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        When("needsReviewOnly=true is passed") {
            // needsReviewOnly 는 content 필터 → sumByTypeForCouple(전체 합계) 대신
            // Specification 경로로 가야 한다. sumByTypeForCouple 을 mock 하지 않았으므로
            // 그 경로를 타면 mockk 가 예외를 던져 테스트가 실패한다 (= 가드).
            every {
                transactionRepository.findAll(
                    any<org.springframework.data.jpa.domain.Specification<com.budgetbook.transaction.domain.Transaction>>()
                )
            } returns emptyList()

            val result = service.getMonthlySummary(
                userId = user1.id, year = 2026, month = 3,
                filter = CommonFilterParams(needsReviewOnly = true)
            )

            Then("uses the filtered Specification path so totals match the visible rows") {
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 0L
                result.transactionCount shouldBe 0
                // 2026-08-12 — 타입별 2회 조회를 1회 + fold 로 바꿨다.
                verify(atLeast = 1) {
                    transactionRepository.findAll(any<Specification<Transaction>>())
                }
            }
        }
    }

    // --- getPeriodSummary: filters applied ---

    Given("a user for period summary with filters") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val dateFrom = LocalDate.of(2026, 3, 1)
        val dateTo = LocalDate.of(2026, 3, 31)
        val filterCategoryId = UUID.randomUUID()

        When("categoryId filter is applied") {
            // When filters are active, findAll(spec) is used instead of sumByType
            every {
                transactionRepository.findAll(any<org.springframework.data.jpa.domain.Specification<com.budgetbook.transaction.domain.Transaction>>())
            } returns emptyList()

            // Budget/plan/daily/pm mocks
            every { budgetRepository.findByCoupleIdAndYearMonthAndUserId(couple.id, "2026-03", user1.id) } returns emptyList()
            every {
                transactionRepository.sumAmountByCoupleIdAndDateRange(couple.id, dateFrom, dateTo, TransactionType.EXPENSE, user1.id)
            } returns 0L
            every { spendingPlanRepository.sumTotalPlannedAmount(couple.id, user1.id, any(), any()) } returns 0L
            every {
                transactionRepository.sumByPaymentMethodWithTypeForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()
            every {
                transactionRepository.dailySummaryForCouple(couple.id, dateFrom, dateTo, any(), "ALL")
            } returns emptyList()

            val result = service.getPeriodSummary(
                user1.id, dateFrom, dateTo,
                CommonFilterParams(categoryId = filterCategoryId)
            )

            Then("uses Specifications-based query (returns filtered data)") {
                result.totalIncome shouldBe 0L
                result.totalExpense shouldBe 0L
            }

            Then("transfers are NOT included when filters are active") {
                // Phase 22: kind 기반 쿼리가 호출되지 않아야 함.
                verify(exactly = 0) {
                    transferRepository.sumAmountBySourceByKind(any(), any(), any(), any())
                }
                verify(exactly = 0) {
                    transferRepository.sumAmountByDestinationByKind(any(), any(), any(), any())
                }
            }
        }
    }
})
