package com.budgetbook.statistics.integration

import com.budgetbook.admin.integration.HighApiVersionDockerStrategy
import com.budgetbook.common.dto.CommonFilterParams
import com.budgetbook.statistics.service.StatisticsService
import com.budgetbook.transaction.service.TransactionService
import com.budgetbook.transfer.domain.TransferKind
import com.budgetbook.transfer.service.TransferService
import io.kotest.core.spec.style.FunSpec
import io.kotest.extensions.spring.SpringExtension
import io.kotest.matchers.shouldBe
import jakarta.persistence.EntityManager
import jakarta.persistence.PersistenceContext
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.context.ApplicationContextInitializer
import org.springframework.context.ConfigurableApplicationContext
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.context.ContextConfiguration
import org.springframework.test.context.support.TestPropertySourceUtils
import org.springframework.transaction.PlatformTransactionManager
import org.springframework.transaction.support.TransactionTemplate
import org.testcontainers.containers.PostgreSQLContainer
import java.time.LocalDate
import java.util.UUID

/**
 * **"합계 = 행" 계약 테스트** (2026-08-12).
 *
 * 장부는 거래 목록 API + 이체 목록 API + 합계 API 세 개를 한 화면에 합쳐 보여준다.
 * 같은 필터를 줬을 때 **합계가 목록 행의 합과 같아야** 한다. 이 불변식이 4회 깨졌고
 * (축 누락 → 이체 전량 노출 → 필터 시 이체 전량 제외 → 기간 필터에서 이체 월 고착),
 * 매번 "한쪽만 고치는" 패치로 끝나 재발했다.
 *
 * 그래서 이 테스트는 **세 API 를 실제 PostgreSQL 에 대고 함께 호출**해 축 조합마다
 * 합계와 행을 대조한다. mock 으로는 Specification/JPQL 층이 검증되지 않아
 * (`spec` 이 실제로 어떤 행을 고르는지) 이 계열 버그를 잡을 수 없다.
 *
 * 픽스처는 kind 4종과 타입 3종을 모두 섞고, **월을 넘는 기간**을 포함한다.
 */
@SpringBootTest
@ActiveProfiles("integration-test")
@ContextConfiguration(initializers = [LedgerSummaryRowContractIntegrationTest.DataSourceInitializer::class])
class LedgerSummaryRowContractIntegrationTest(
    private val statisticsService: StatisticsService,
    private val transactionService: TransactionService,
    private val transferService: TransferService,
    @PersistenceContext private val em: EntityManager,
    private val txManager: PlatformTransactionManager,
) : FunSpec() {

    override fun extensions() = listOf(SpringExtension)

    companion object {
        val postgres: PostgreSQLContainer<*> = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("budgetbook_test")
            .withUsername("test")
            .withPassword("test")

        init {
            System.setProperty(
                "testcontainers.docker.client.strategy",
                HighApiVersionDockerStrategy::class.java.name
            )
            postgres.start()
        }
    }

    class DataSourceInitializer : ApplicationContextInitializer<ConfigurableApplicationContext> {
        override fun initialize(ctx: ConfigurableApplicationContext) {
            TestPropertySourceUtils.addInlinedPropertiesToEnvironment(
                ctx,
                "spring.datasource.url=${postgres.jdbcUrl}",
                "spring.datasource.username=${postgres.username}",
                "spring.datasource.password=${postgres.password}",
                "spring.datasource.driver-class-name=org.postgresql.Driver",
                "spring.jpa.hibernate.ddl-auto=validate",
                "spring.flyway.enabled=true",
                "spring.flyway.baseline-on-migrate=true"
            )
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun <T> inTx(action: () -> T): T = TransactionTemplate(txManager).execute { action() }!!

    private fun insertUser(email: String): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO users (id, email, nickname, provider, provider_id, role, is_active, created_at, updated_at)
               VALUES (:id, :email, 'Ledger', 'GOOGLE', :pid, 'USER', true, now(), now())"""
        ).setParameter("id", id).setParameter("email", email)
            .setParameter("pid", UUID.randomUUID().toString()).executeUpdate()
        return id
    }

    private fun insertSelfCouple(userId: UUID): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO couples (id, user1_id, user2_id, status, is_self, created_at, updated_at)
               VALUES (:id, :userId, null, 'ACTIVE', true, now(), now())"""
        ).setParameter("id", id).setParameter("userId", userId).executeUpdate()
        return id
    }

    private fun insertPaymentMethod(coupleId: UUID, name: String, type: String = "BANK"): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO payment_methods (id, couple_id, name, type, is_active, is_default, display_order, created_at, updated_at)
               VALUES (:id, :coupleId, :name, :type, true, false, 0, now(), now())"""
        ).setParameter("id", id).setParameter("coupleId", coupleId)
            .setParameter("name", name).setParameter("type", type).executeUpdate()
        return id
    }

    private fun insertTransaction(
        coupleId: UUID,
        authorId: UUID,
        paymentMethodId: UUID?,
        type: String,
        amount: Long,
        date: LocalDate,
        description: String = "거래",
    ): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO transactions
               (id, couple_id, author_id, payment_method_id, type, amount, description,
                transaction_date, visibility, needs_review, created_at, updated_at)
               VALUES (:id, :coupleId, :authorId, :pm, :type, :amount, :description,
                       :date, 'SHARED', false, now(), now())"""
        ).setParameter("id", id).setParameter("coupleId", coupleId).setParameter("authorId", authorId)
            .setParameter("pm", paymentMethodId).setParameter("type", type)
            .setParameter("amount", amount).setParameter("description", description)
            .setParameter("date", date).executeUpdate()
        return id
    }

    private fun insertTransfer(
        coupleId: UUID,
        authorId: UUID,
        sourceId: UUID,
        destinationId: UUID,
        amount: Long,
        date: LocalDate,
        kind: String,
        description: String = "이체",
    ): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO transfers
               (id, couple_id, author_id, source_payment_method_id, destination_payment_method_id,
                amount, description, transfer_date, kind, is_card_settlement, created_at, updated_at)
               VALUES (:id, :coupleId, :authorId, :src, :dst, :amount, :description,
                       :date, :kind, :isSettlement, now(), now())"""
        ).setParameter("id", id).setParameter("coupleId", coupleId).setParameter("authorId", authorId)
            .setParameter("src", sourceId).setParameter("dst", destinationId)
            .setParameter("amount", amount).setParameter("description", description)
            .setParameter("date", date).setParameter("kind", kind)
            .setParameter("isSettlement", kind == "CARD_SETTLEMENT")
            .executeUpdate()
        return id
    }

    /**
     * 목록 두 개(거래/이체)를 합계와 같은 규칙으로 접어 "행의 합" 을 만든다.
     * FE `LedgerSummary` 와 BE `ExpenseCalculator` 의 집계식을 그대로 따른다:
     * ADJUSTMENT·CARD_SETTLEMENT 는 어느 버킷에도 넣지 않는다.
     */
    private data class RowTotals(val income: Long, val expense: Long, val transfer: Long)

    private fun rowTotals(userId: UUID, filter: CommonFilterParams, year: Int, month: Int): RowTotals {
        val transactions = transactionService.listTransactions(
            userId = userId, year = year, month = month, type = filter.type,
            categoryId = filter.categoryId, keyword = filter.keyword,
            paymentMethodId = filter.paymentMethodId, pocketId = filter.pocketId,
            amountMin = filter.amountMin, amountMax = filter.amountMax,
            dateFrom = filter.dateFrom, dateTo = filter.dateTo,
            visibility = filter.visibility, page = 0, size = 500,
            categoryIds = filter.categoryIds, categoryGroupIds = filter.categoryGroupIds,
            paymentMethodIds = filter.paymentMethodIds, pocketIds = filter.pocketIds,
            transactionTypes = filter.transactionTypes,
            needsReviewOnly = filter.needsReviewOnly,
        ).content
        // 이체 목록은 범위를 VO 에서 읽는다. FE 도 같은 쿼리스트링에 year/month 를 실어 보내므로
        // 여기서 채워 넣는 것이 실제 호출과 동일하다(dateFrom/dateTo 가 있으면 그쪽이 우선).
        val transfers = transferService.listTransfers(
            userId,
            filter.copy(year = filter.year ?: year, month = filter.month ?: month)
        )

        var income = transactions.filter { it.type == "INCOME" }.sumOf { it.amount }
        var expense = transactions.filter { it.type == "EXPENSE" }.sumOf { it.amount }
        var transfer = 0L
        for (t in transfers) {
            when (t.kind) {
                TransferKind.EXPENSE_TRANSFER -> expense += t.amount
                TransferKind.INCOME_TRANSFER -> income += t.amount
                TransferKind.GENERIC -> transfer += t.amount
                TransferKind.CARD_SETTLEMENT -> Unit // 원본 EXPENSE 로 이미 집계됨
            }
        }
        return RowTotals(income, expense, transfer)
    }

    init {
        lateinit var userId: UUID
        lateinit var bankId: UUID
        lateinit var savingsId: UUID
        lateinit var cardId: UUID

        beforeSpec {
            inTx {
                userId = insertUser("ledger-contract-${UUID.randomUUID()}@test.com")
                val coupleId = insertSelfCouple(userId)
                bankId = insertPaymentMethod(coupleId, "주계좌")
                savingsId = insertPaymentMethod(coupleId, "저축통장")
                cardId = insertPaymentMethod(coupleId, "신용카드", "CREDIT")

                // 7월 — 기준 월
                insertTransaction(coupleId, userId, bankId, "EXPENSE", 30_000, LocalDate.of(2026, 7, 5), "커피 정기결제")
                insertTransaction(coupleId, userId, cardId, "EXPENSE", 120_000, LocalDate.of(2026, 7, 10), "마트")
                insertTransaction(coupleId, userId, bankId, "INCOME", 2_000_000, LocalDate.of(2026, 7, 25), "급여")
                // ADJUSTMENT — 통계 범주 밖(잔액 전용). 합계 어느 칸에도 들어가지 않아야 한다.
                insertTransaction(coupleId, userId, bankId, "ADJUSTMENT", 5_000, LocalDate.of(2026, 7, 26), "잔액 조정")

                insertTransfer(coupleId, userId, bankId, savingsId, 500_000, LocalDate.of(2026, 7, 12), "GENERIC")
                insertTransfer(coupleId, userId, bankId, savingsId, 80_000, LocalDate.of(2026, 7, 18), "EXPENSE_TRANSFER")
                insertTransfer(coupleId, userId, savingsId, bankId, 60_000, LocalDate.of(2026, 7, 20), "INCOME_TRANSFER")
                insertTransfer(coupleId, userId, bankId, cardId, 120_000, LocalDate.of(2026, 7, 28), "CARD_SETTLEMENT")

                // 6월 — 기간 필터가 월을 넘을 때만 보여야 하는 데이터
                insertTransaction(coupleId, userId, bankId, "EXPENSE", 40_000, LocalDate.of(2026, 6, 20), "6월 지출")
                insertTransfer(coupleId, userId, bankId, savingsId, 300_000, LocalDate.of(2026, 6, 22), "GENERIC")
            }
        }

        /** 축 조합마다 (합계 == 행의 합) 을 확인한다. */
        fun assertSummaryMatchesRows(label: String, filter: CommonFilterParams) {
            test("summary equals rows — $label") {
                val summary = statisticsService.getMonthlySummary(userId, 2026, 7, filter)
                val rows = rowTotals(userId, filter, 2026, 7)

                summary.totalIncome shouldBe rows.income
                summary.totalExpense shouldBe rows.expense
                summary.totalTransfer shouldBe rows.transfer
            }
        }

        assertSummaryMatchesRows("no filter", CommonFilterParams())
        assertSummaryMatchesRows(
            "amount range",
            CommonFilterParams(amountMin = 50_000, amountMax = 600_000)
        )
        assertSummaryMatchesRows("keyword", CommonFilterParams(keyword = "커피"))
        assertSummaryMatchesRows("needsReviewOnly", CommonFilterParams(needsReviewOnly = true))
        assertSummaryMatchesRows("visibility SHARED", CommonFilterParams(visibility = "SHARED"))
        assertSummaryMatchesRows("visibility PRIVATE", CommonFilterParams(visibility = "PRIVATE"))
        assertSummaryMatchesRows(
            "types EXPENSE only",
            CommonFilterParams(transactionTypes = listOf("EXPENSE"))
        )
        assertSummaryMatchesRows(
            "types TRANSFER only",
            CommonFilterParams(transactionTypes = listOf("TRANSFER"))
        )
        assertSummaryMatchesRows(
            "types EXPENSE + TRANSFER",
            CommonFilterParams(transactionTypes = listOf("EXPENSE", "TRANSFER"))
        )
        assertSummaryMatchesRows(
            "date range inside the month",
            CommonFilterParams(dateFrom = LocalDate.of(2026, 7, 10), dateTo = LocalDate.of(2026, 7, 20))
        )
        // 이번 회차의 본체 — 기간이 월을 넘어가는 경우.
        assertSummaryMatchesRows(
            "date range spanning two months",
            CommonFilterParams(dateFrom = LocalDate.of(2026, 6, 15), dateTo = LocalDate.of(2026, 7, 31))
        )

        // ── 절대값 회귀 가드 ────────────────────────────────────────────────────
        // 위 대조만으로는 "둘 다 똑같이 틀린" 경우를 못 잡는다. 기대값을 못박는다.

        test("no filter — absolute totals follow the kind rules") {
            val summary = statisticsService.getMonthlySummary(userId, 2026, 7, CommonFilterParams())

            // 지출 = 30,000 + 120,000 거래 + 80,000 EXPENSE_TRANSFER (CARD_SETTLEMENT 제외)
            summary.totalExpense shouldBe 230_000L
            // 수입 = 2,000,000 급여 + 60,000 INCOME_TRANSFER
            summary.totalIncome shouldBe 2_060_000L
            // 이체 칸 = GENERIC 만
            summary.totalTransfer shouldBe 500_000L
            // ADJUSTMENT 는 어느 칸에도 없다 → 거래 건수는 INCOME/EXPENSE 3건
            summary.transactionCount shouldBe 3
            // CARD_SETTLEMENT 는 집계 건수에서도 빠진다 → 이체 3건
            summary.transferCount shouldBe 3
        }

        test("date range spanning two months includes the other month's transfers") {
            val filter = CommonFilterParams(
                dateFrom = LocalDate.of(2026, 6, 15),
                dateTo = LocalDate.of(2026, 7, 31),
            )
            val summary = statisticsService.getMonthlySummary(userId, 2026, 7, filter)
            val transfers = transferService.listTransfers(userId, filter)

            // 6월 GENERIC 300,000 + 7월 GENERIC 500,000. 이체가 월에 갇혀 있던 버그가 있으면
            // 여기서 500,000 만 나온다(= 이번 회차가 고친 것).
            summary.totalTransfer shouldBe 800_000L
            transfers.count { it.kind == TransferKind.GENERIC } shouldBe 2
            // 지출 = 6월 40,000 + 7월 30,000 + 120,000 + EXPENSE_TRANSFER 80,000
            summary.totalExpense shouldBe 270_000L
        }

        test("a filter axis absent from transfers hides transfers from BOTH sides") {
            // 포켓 필터는 이체에 없는 축 → 목록에도 합계에도 이체가 없어야 한다.
            val filter = CommonFilterParams(pocketIds = listOf(UUID.randomUUID()))

            val summary = statisticsService.getMonthlySummary(userId, 2026, 7, filter)
            val transfers = transferService.listTransfers(userId, filter.copy(year = 2026, month = 7))

            transfers.size shouldBe 0
            summary.totalTransfer shouldBe 0L
            summary.transferCount shouldBe 0
        }

        test("payment method filter matches transfers on either leg") {
            // 저축통장은 GENERIC(출금 bank→savings)·EXPENSE_TRANSFER(→savings)·
            // INCOME_TRANSFER(savings→bank) 세 건에 걸린다.
            val filter = CommonFilterParams(paymentMethodIds = listOf(savingsId))

            val summary = statisticsService.getMonthlySummary(userId, 2026, 7, filter)
            val rows = rowTotals(userId, filter, 2026, 7)

            summary.totalTransfer shouldBe rows.transfer
            summary.totalExpense shouldBe rows.expense
            summary.totalIncome shouldBe rows.income
            summary.totalTransfer shouldBe 500_000L
        }
    }
}
