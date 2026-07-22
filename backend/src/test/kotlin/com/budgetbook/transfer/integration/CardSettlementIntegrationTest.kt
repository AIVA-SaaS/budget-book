package com.budgetbook.transfer.integration

import com.budgetbook.admin.integration.HighApiVersionDockerStrategy
import com.budgetbook.transfer.domain.TransferKind
import com.budgetbook.transfer.service.TransferService
import io.kotest.core.spec.style.FunSpec
import io.kotest.extensions.spring.SpringExtension
import io.kotest.matchers.nulls.shouldNotBeNull
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
 * Integration test for [TransferService.createCardSettlement] / [TransferService.updateCardSettlement]
 * against a real PostgreSQL container (Testcontainers) with Flyway migrations applied.
 *
 * Regression guard for the FK ordering bug (prod, 2026-07-22):
 * `createCardSettlement` did `transferRepository.save(transfer)` (application-assigned UUID → INSERT
 * merely scheduled, not flushed) and then ran the `markAsPaidForSettlement` bulk `@Modifying` UPDATE
 * on the `transactions` table. Hibernate auto-flush before a bulk update only flushes changes whose
 * query-spaces intersect the update's table, so the pending `transfers` INSERT was NOT flushed →
 * `transactions.settlement_transfer_id` referenced a transfer row that did not yet exist →
 * `transactions_settlement_transfer_id_fkey` violation (DataIntegrityViolationException).
 *
 * Mock-based [com.budgetbook.transfer.service.TransferServiceTest] cannot catch this: mocks never
 * exercise the real FK. Only a real DB reproduces it. The fix is `saveAndFlush`.
 */
@SpringBootTest
@ActiveProfiles("integration-test")
@ContextConfiguration(initializers = [CardSettlementIntegrationTest.DataSourceInitializer::class])
class CardSettlementIntegrationTest(
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

    private fun <T> inTx(action: () -> T): T =
        TransactionTemplate(txManager).execute { action() }!!

    private fun insertUser(email: String): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO users (id, email, nickname, provider, provider_id, role, is_active, created_at, updated_at)
               VALUES (:id, :email, 'Settler', 'GOOGLE', :pid, 'USER', true, now(), now())"""
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

    private fun insertCategory(coupleId: UUID): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO categories (id, couple_id, name, type, is_default, display_order, created_at, updated_at)
               VALUES (:id, :coupleId, '식비', 'EXPENSE', false, 0, now(), now())"""
        ).setParameter("id", id).setParameter("coupleId", coupleId).executeUpdate()
        return id
    }

    private fun insertPaymentMethod(coupleId: UUID, name: String, type: String): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO payment_methods (id, couple_id, name, type, is_active, is_default, display_order, created_at, updated_at)
               VALUES (:id, :coupleId, :name, :type, true, false, 0, now(), now())"""
        ).setParameter("id", id).setParameter("coupleId", coupleId)
            .setParameter("name", name).setParameter("type", type).executeUpdate()
        return id
    }

    private fun insertExpenseTxn(coupleId: UUID, authorId: UUID, categoryId: UUID, cardId: UUID): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO transactions
               (id, couple_id, author_id, category_id, payment_method_id, type, amount, description, transaction_date, created_at, updated_at)
               VALUES (:id, :coupleId, :authorId, :categoryId, :cardId, 'EXPENSE', 10000, '카드 지출', :txDate, now(), now())"""
        ).setParameter("id", id).setParameter("coupleId", coupleId).setParameter("authorId", authorId)
            .setParameter("categoryId", categoryId).setParameter("cardId", cardId)
            .setParameter("txDate", LocalDate.of(2026, 6, 15)).executeUpdate()
        return id
    }

    private fun settlementTransferIdOf(txnId: UUID): UUID? =
        em.createNativeQuery("SELECT settlement_transfer_id FROM transactions WHERE id = :id")
            .setParameter("id", txnId).singleResult as UUID?

    private fun paidAtOf(txnId: UUID): Any? =
        em.createNativeQuery("SELECT paid_at FROM transactions WHERE id = :id")
            .setParameter("id", txnId).singleResult

    // ── Tests ─────────────────────────────────────────────────────────────────

    init {
        test("createCardSettlement with linked transactions persists transfer before marking (no FK violation)") {
            lateinit var userId: UUID
            lateinit var bankId: UUID
            lateinit var cardId: UUID
            val txnIds = mutableListOf<UUID>()
            inTx {
                userId = insertUser("settle-${UUID.randomUUID()}@test.com")
                val coupleId = insertSelfCouple(userId)
                val categoryId = insertCategory(coupleId)
                bankId = insertPaymentMethod(coupleId, "신한은행", "BANK")
                cardId = insertPaymentMethod(coupleId, "현대카드", "CREDIT")
                repeat(3) { txnIds.add(insertExpenseTxn(coupleId, userId, categoryId, cardId)) }
            }

            // Act — before the fix this threw DataIntegrityViolationException on the FK.
            val result = transferService.createCardSettlement(
                userId = userId,
                sourcePaymentMethodId = bankId,
                destinationPaymentMethodId = cardId,
                amount = 30000,
                transferDate = LocalDate.of(2026, 7, 1),
                description = "현대카드 7월 결제",
                transactionIds = txnIds,
            )

            // Assert — transfer row exists and every linked transaction points to it.
            result.kind shouldBe TransferKind.CARD_SETTLEMENT
            inTx {
                txnIds.forEach { txnId ->
                    settlementTransferIdOf(txnId) shouldBe result.id
                    paidAtOf(txnId).shouldNotBeNull()
                }
            }
        }

        test("updateCardSettlement re-links a new transaction selection (no FK violation)") {
            lateinit var userId: UUID
            lateinit var bankId: UUID
            lateinit var cardId: UUID
            lateinit var firstTxn: UUID
            lateinit var secondTxn: UUID
            inTx {
                userId = insertUser("update-${UUID.randomUUID()}@test.com")
                val coupleId = insertSelfCouple(userId)
                val categoryId = insertCategory(coupleId)
                bankId = insertPaymentMethod(coupleId, "국민은행", "BANK")
                cardId = insertPaymentMethod(coupleId, "삼성카드", "CREDIT")
                firstTxn = insertExpenseTxn(coupleId, userId, categoryId, cardId)
                secondTxn = insertExpenseTxn(coupleId, userId, categoryId, cardId)
            }

            val created = transferService.createCardSettlement(
                userId = userId,
                sourcePaymentMethodId = bankId,
                destinationPaymentMethodId = cardId,
                amount = 10000,
                transferDate = LocalDate.of(2026, 7, 1),
                description = "삼성카드 결제",
                transactionIds = listOf(firstTxn),
            )

            // Act — swap the linked selection to the second transaction.
            transferService.updateCardSettlement(
                userId = userId,
                transferId = created.id,
                sourcePaymentMethodId = bankId,
                destinationPaymentMethodId = cardId,
                amount = 10000,
                transferDate = LocalDate.of(2026, 7, 1),
                description = "삼성카드 결제 (수정)",
                transactionIds = listOf(secondTxn),
            )

            inTx {
                settlementTransferIdOf(firstTxn) shouldBe null
                settlementTransferIdOf(secondTxn) shouldBe created.id
            }
        }
    }
}
