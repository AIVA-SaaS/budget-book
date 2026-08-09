package com.budgetbook.transfer.integration

import com.budgetbook.admin.integration.HighApiVersionDockerStrategy
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.transaction.dto.ConvertToTransactionRequest
import com.budgetbook.transaction.service.TransactionService
import io.kotest.assertions.throwables.shouldThrow
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
 * Integration test for [TransactionService.convertFromTransfer] (이체 → 거래 역변환)
 * against a real PostgreSQL container with Flyway migrations applied.
 *
 * Why a real DB is required here (mocks cannot catch any of this):
 * 1. The conversion deletes a `transfers` row and inserts a `transactions` row in ONE transaction.
 *    Ordering matters — the same class of FK/flush timing bug that hit card settlement in prod
 *    (see [CardSettlementIntegrationTest]) applies. Mocks never exercise the real constraint.
 * 2. `transactions.description` is NOT NULL while `transfers.description` is nullable. Without the
 *    service-side guard this surfaces only as a DB constraint violation (500), never in mock tests.
 * 3. `transactions.settlement_transfer_id` is `ON DELETE SET NULL` — deleting a transfer that still
 *    has payment links would silently unlink them rather than fail, so the guard has to be proven
 *    against real rows.
 */
@SpringBootTest
@ActiveProfiles("integration-test")
@ContextConfiguration(initializers = [TransferToTransactionIntegrationTest.DataSourceInitializer::class])
class TransferToTransactionIntegrationTest(
    private val transactionService: TransactionService,
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
               VALUES (:id, :email, 'Converter', 'GOOGLE', :pid, 'USER', true, now(), now())"""
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

    private fun insertTransfer(
        coupleId: UUID,
        authorId: UUID,
        sourceId: UUID,
        destinationId: UUID,
        description: String?,
        kind: String = "GENERIC",
    ): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO transfers
               (id, couple_id, author_id, source_payment_method_id, destination_payment_method_id,
                amount, description, memo, transfer_date, kind, is_card_settlement, created_at, updated_at)
               VALUES (:id, :coupleId, :authorId, :src, :dst, 50000, :description, '메모',
                       :transferDate, :kind, false, now(), now())"""
        ).setParameter("id", id).setParameter("coupleId", coupleId).setParameter("authorId", authorId)
            .setParameter("src", sourceId).setParameter("dst", destinationId)
            .setParameter("description", description)
            .setParameter("transferDate", LocalDate.of(2026, 7, 15))
            .setParameter("kind", kind).executeUpdate()
        return id
    }

    private fun countTransfers(id: UUID): Long =
        (em.createNativeQuery("SELECT count(*) FROM transfers WHERE id = :id")
            .setParameter("id", id).singleResult as Number).toLong()

    // ── Tests ─────────────────────────────────────────────────────────────────

    init {
        test("convertFromTransfer deletes the transfer and inserts the transaction in one transaction") {
            lateinit var userId: UUID
            lateinit var transferId: UUID
            lateinit var bankId: UUID
            lateinit var cashId: UUID
            lateinit var categoryId: UUID
            inTx {
                userId = insertUser("convert-${UUID.randomUUID()}@test.com")
                val coupleId = insertSelfCouple(userId)
                categoryId = insertCategory(coupleId)
                bankId = insertPaymentMethod(coupleId, "국민은행", "BANK")
                cashId = insertPaymentMethod(coupleId, "현금", "CASH")
                transferId = insertTransfer(coupleId, userId, bankId, cashId, "계좌 이동")
            }

            val result = transactionService.convertFromTransfer(
                userId, transferId, ConvertToTransactionRequest(type = "EXPENSE", categoryId = categoryId)
            )

            result.type shouldBe "EXPENSE"
            result.amount shouldBe 50000
            result.description shouldBe "계좌 이동"
            result.transactionDate shouldBe LocalDate.of(2026, 7, 15)
            // EXPENSE 는 돈이 나간 쪽(출금) 결제수단을 승계한다.
            result.paymentMethodId shouldBe bankId

            inTx { countTransfers(transferId) shouldBe 0L }
        }

        test("INCOME conversion inherits the destination payment method") {
            lateinit var userId: UUID
            lateinit var transferId: UUID
            lateinit var cashId: UUID
            inTx {
                userId = insertUser("convert-in-${UUID.randomUUID()}@test.com")
                val coupleId = insertSelfCouple(userId)
                val bankId = insertPaymentMethod(coupleId, "국민은행", "BANK")
                cashId = insertPaymentMethod(coupleId, "현금", "CASH")
                transferId = insertTransfer(coupleId, userId, bankId, cashId, "현금 입금")
            }

            val result = transactionService.convertFromTransfer(
                userId, transferId, ConvertToTransactionRequest(type = "INCOME")
            )

            result.type shouldBe "INCOME"
            result.paymentMethodId shouldBe cashId
            inTx { countTransfers(transferId) shouldBe 0L }
        }

        test("a transfer without a description is rejected before the NOT NULL constraint fires") {
            lateinit var userId: UUID
            lateinit var transferId: UUID
            inTx {
                userId = insertUser("convert-nodesc-${UUID.randomUUID()}@test.com")
                val coupleId = insertSelfCouple(userId)
                val bankId = insertPaymentMethod(coupleId, "국민은행", "BANK")
                val cashId = insertPaymentMethod(coupleId, "현금", "CASH")
                transferId = insertTransfer(coupleId, userId, bankId, cashId, null)
            }

            // transfers.description 은 nullable, transactions.description 은 NOT NULL.
            // 가드가 없으면 여기서 DataIntegrityViolationException(500) 이 난다.
            shouldThrow<BusinessException> {
                transactionService.convertFromTransfer(
                    userId, transferId, ConvertToTransactionRequest(type = "EXPENSE")
                )
            }.code shouldBe "VALIDATION_ERROR"

            // 원본 이체는 그대로 남아 있어야 한다 (원자성).
            inTx { countTransfers(transferId) shouldBe 1L }
        }

        test("a card settlement transfer is rejected and left intact") {
            lateinit var userId: UUID
            lateinit var transferId: UUID
            inTx {
                userId = insertUser("convert-card-${UUID.randomUUID()}@test.com")
                val coupleId = insertSelfCouple(userId)
                val bankId = insertPaymentMethod(coupleId, "국민은행", "BANK")
                val cardId = insertPaymentMethod(coupleId, "현대카드", "CREDIT")
                transferId = insertTransfer(
                    coupleId, userId, bankId, cardId, "현대카드 결제", kind = "CARD_SETTLEMENT"
                )
            }

            shouldThrow<BusinessException> {
                transactionService.convertFromTransfer(
                    userId, transferId, ConvertToTransactionRequest(type = "EXPENSE")
                )
            }.code shouldBe "VALIDATION_ERROR"

            inTx { countTransfers(transferId) shouldBe 1L }
        }
    }
}
