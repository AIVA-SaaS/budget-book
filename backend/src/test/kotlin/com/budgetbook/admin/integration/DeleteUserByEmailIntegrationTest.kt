package com.budgetbook.admin.integration

import com.budgetbook.admin.service.AdminService
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.FunSpec
import io.kotest.extensions.spring.SpringExtension
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
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
 * Integration test for [AdminService.deleteUserByEmail].
 *
 * Uses a real PostgreSQL container (Testcontainers) with Flyway migrations applied,
 * so that actual FK CASCADE and NO ACTION constraints are exercised.
 * H2 mock tests cannot catch: couple ON DELETE RESTRICT, transactions ON DELETE RESTRICT author_id, etc.
 *
 * The container is started eagerly in the companion object's init block so that
 * DataSourceInitializer can read the JDBC URL before the Spring context is created.
 * (@Container / @Testcontainers lifecycle runs after ApplicationContextInitializer,
 * so we must start the container ourselves at class-load time.)
 *
 * Transactions: Kotest FunSpec does not support @Transactional rollback.
 * Each test creates its data in a setup transaction and cleans up manually in afterTest,
 * OR uses TransactionTemplate to run data operations within explicit transactions.
 */
@SpringBootTest
@ActiveProfiles("integration-test")
@ContextConfiguration(initializers = [DeleteUserByEmailIntegrationTest.DataSourceInitializer::class])
class DeleteUserByEmailIntegrationTest(
    private val adminService: AdminService,
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
            // Configure Testcontainers to use our custom strategy that forces API version 1.44.
            // Docker Desktop 4.x proxy rejects /v1.32/info (docker-java default) with an empty 400,
            // causing all built-in Testcontainers strategies to fail on macOS Docker Desktop.
            System.setProperty(
                "testcontainers.docker.client.strategy",
                "com.budgetbook.admin.integration.HighApiVersionDockerStrategy"
            )
            // Start the container at class-load time so the JDBC URL is available
            // when DataSourceInitializer.initialize() is called by the Spring test framework.
            postgres.start()
        }
    }

    /** Feeds the container's JDBC URL into Spring before context loads. */
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

    // ── Transaction helper ────────────────────────────────────────────────────

    private fun <T> inTx(action: () -> T): T {
        val txTemplate = TransactionTemplate(txManager)
        return txTemplate.execute { action() }!!
    }

    // ── Data helpers ──────────────────────────────────────────────────────────

    private fun insertUser(
        email: String,
        nickname: String,
        provider: String = "GOOGLE",
        providerId: String = UUID.randomUUID().toString(),
        role: String = "USER",
    ): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO users (id, email, nickname, provider, provider_id, role, is_active, created_at, updated_at)
               VALUES (:id, :email, :nickname, :provider, :providerId, :role, true, now(), now())"""
        )
            .setParameter("id", id)
            .setParameter("email", email)
            .setParameter("nickname", nickname)
            .setParameter("provider", provider)
            .setParameter("providerId", providerId)
            .setParameter("role", role)
            .executeUpdate()
        return id
    }

    private fun insertSelfCouple(userId: UUID): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO couples (id, user1_id, user2_id, status, is_self, created_at, updated_at)
               VALUES (:id, :userId, null, 'ACTIVE', true, now(), now())"""
        )
            .setParameter("id", id)
            .setParameter("userId", userId)
            .executeUpdate()
        return id
    }

    private fun insertRealCouple(user1Id: UUID, user2Id: UUID, status: String = "ACTIVE"): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO couples (id, user1_id, user2_id, status, is_self, created_at, updated_at)
               VALUES (:id, :u1, :u2, :status, false, now(), now())"""
        )
            .setParameter("id", id)
            .setParameter("u1", user1Id)
            .setParameter("u2", user2Id)
            .setParameter("status", status)
            .executeUpdate()
        return id
    }

    private fun insertCategory(coupleId: UUID): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO categories (id, couple_id, name, type, is_default, display_order, created_at, updated_at)
               VALUES (:id, :coupleId, '식비', 'EXPENSE', false, 0, now(), now())"""
        )
            .setParameter("id", id)
            .setParameter("coupleId", coupleId)
            .executeUpdate()
        return id
    }

    private fun insertPaymentMethod(coupleId: UUID): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO payment_methods (id, couple_id, name, type, is_active, is_default, display_order, created_at, updated_at)
               VALUES (:id, :coupleId, '현금', 'CASH', true, true, 0, now(), now())"""
        )
            .setParameter("id", id)
            .setParameter("coupleId", coupleId)
            .executeUpdate()
        return id
    }

    private fun insertTransaction(coupleId: UUID, authorId: UUID, categoryId: UUID): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO transactions (id, couple_id, author_id, category_id, type, amount, description, transaction_date, created_at, updated_at)
               VALUES (:id, :coupleId, :authorId, :categoryId, 'EXPENSE', 10000, '테스트 지출', :txDate, now(), now())"""
        )
            .setParameter("id", id)
            .setParameter("coupleId", coupleId)
            .setParameter("authorId", authorId)
            .setParameter("categoryId", categoryId)
            .setParameter("txDate", LocalDate.now())
            .executeUpdate()
        return id
    }

    private fun insertRefreshToken(userId: UUID): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO refresh_tokens (id, user_id, token, expires_at, revoked, created_at)
               VALUES (:id, :userId, :token, now() + interval '7 days', false, now())"""
        )
            .setParameter("id", id)
            .setParameter("userId", userId)
            .setParameter("token", "test-token-${UUID.randomUUID()}")
            .executeUpdate()
        return id
    }

    private fun countRows(table: String, whereClause: String, id: UUID): Long {
        @Suppress("UNCHECKED_CAST")
        return (em.createNativeQuery("SELECT COUNT(*) FROM $table WHERE $whereClause = :id")
            .setParameter("id", id)
            .singleResult as Number).toLong()
    }

    // ── Admin user (idempotent setup) ─────────────────────────────────────────

    private val adminId: UUID = UUID.fromString("10000000-0000-0000-0000-000000000001")

    private fun ensureAdminExists() {
        val count = (em.createNativeQuery("SELECT COUNT(*) FROM users WHERE id = :id")
            .setParameter("id", adminId)
            .singleResult as Number).toLong()
        if (count == 0L) {
            em.createNativeQuery(
                """INSERT INTO users (id, email, nickname, provider, provider_id, role, is_active, created_at, updated_at)
                   VALUES (:id, 'admin@test.com', 'AdminUser', 'GOOGLE', 'admin-provider-id', 'ADMIN', true, now(), now())"""
            ).setParameter("id", adminId).executeUpdate()
        }
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    init {
        beforeEach {
            inTx { ensureAdminExists() }
        }

        // ─── Happy path: self-couple user with categories/transactions/refresh_token ───

        test("happy path: deletes self-couple user and all related rows without FK violation") {
            // Arrange: insert all related rows in a committed transaction
            lateinit var userId: UUID
            lateinit var coupleId: UUID
            lateinit var categoryId: UUID
            inTx {
                userId = insertUser("victim@test.com", "Victim")
                coupleId = insertSelfCouple(userId)
                categoryId = insertCategory(coupleId)
                insertPaymentMethod(coupleId)
                insertTransaction(coupleId, userId, categoryId)
                insertRefreshToken(userId)
            }

            // Act: service runs in its own @Transactional
            val result = adminService.deleteUserByEmail(adminId, "victim@test.com", confirm = true)

            // Assert result DTO
            result.deletedUserId shouldBe userId
            result.email shouldBe "victim@test.com"
            result.deletedCoupleIds shouldBe listOf(coupleId)
            result.deletedAt shouldNotBe null

            // Assert: all rows gone (read in new tx)
            inTx {
                countRows("users", "id", userId) shouldBe 0
                countRows("couples", "id", coupleId) shouldBe 0
                countRows("categories", "couple_id", coupleId) shouldBe 0
                countRows("payment_methods", "couple_id", coupleId) shouldBe 0
                countRows("transactions", "couple_id", coupleId) shouldBe 0
                countRows("refresh_tokens", "user_id", userId) shouldBe 0
            }
        }

        // ─── email with leading/trailing whitespace is trimmed ───────────────

        test("email with surrounding whitespace is trimmed before lookup") {
            lateinit var userId: UUID
            inTx {
                userId = insertUser("trimmed@test.com", "TrimUser")
                insertSelfCouple(userId)
            }

            val result = adminService.deleteUserByEmail(adminId, "  trimmed@test.com  ", confirm = true)
            result.email shouldBe "trimmed@test.com"
            inTx { countRows("users", "id", userId) shouldBe 0 }
        }

        // ─── Guard: confirm = false ────────────────────────────────────────────

        test("guard: confirm=false throws DELETE_NOT_CONFIRMED") {
            shouldThrow<BusinessException> {
                adminService.deleteUserByEmail(adminId, "any@test.com", confirm = false)
            }.code shouldBe "DELETE_NOT_CONFIRMED"
        }

        // ─── Guard: SYSTEM account ────────────────────────────────────────────

        test("guard: SYSTEM account throws CANNOT_DELETE_SYSTEM_ACCOUNT") {
            // system account is seeded by V35 migration
            shouldThrow<BusinessException> {
                adminService.deleteUserByEmail(adminId, "system@budgetbook.internal", confirm = true)
            }.code shouldBe "CANNOT_DELETE_SYSTEM_ACCOUNT"
        }

        // ─── Guard: partner in ACTIVE couple ──────────────────────────────────

        test("guard: user with active partner throws COUPLE_HAS_PARTNER") {
            lateinit var u1: UUID
            lateinit var u2: UUID
            inTx {
                u1 = insertUser("partner1@test.com", "P1")
                u2 = insertUser("partner2@test.com", "P2")
                insertRealCouple(u1, u2, status = "ACTIVE")
            }

            shouldThrow<BusinessException> {
                adminService.deleteUserByEmail(adminId, "partner1@test.com", confirm = true)
            }.code shouldBe "COUPLE_HAS_PARTNER"

            // cleanup
            inTx {
                em.createNativeQuery("DELETE FROM couples WHERE user1_id = :u1 OR user2_id = :u1")
                    .setParameter("u1", u1).executeUpdate()
                em.createNativeQuery("DELETE FROM users WHERE id = :u1 OR id = :u2")
                    .setParameter("u1", u1).setParameter("u2", u2).executeUpdate()
            }
        }

        // ─── Guard: partner in DISSOLVED couple (shared-data safety) ──────────

        test("guard: user with dissolved partner couple throws COUPLE_HAS_PARTNER") {
            lateinit var u1: UUID
            lateinit var u2: UUID
            inTx {
                u1 = insertUser("dissolved1@test.com", "D1")
                u2 = insertUser("dissolved2@test.com", "D2")
                insertRealCouple(u1, u2, status = "DISSOLVED")
            }

            shouldThrow<BusinessException> {
                adminService.deleteUserByEmail(adminId, "dissolved1@test.com", confirm = true)
            }.code shouldBe "COUPLE_HAS_PARTNER"

            // cleanup
            inTx {
                em.createNativeQuery("DELETE FROM couples WHERE user1_id = :u1 OR user2_id = :u1")
                    .setParameter("u1", u1).executeUpdate()
                em.createNativeQuery("DELETE FROM users WHERE id = :u1 OR id = :u2")
                    .setParameter("u1", u1).setParameter("u2", u2).executeUpdate()
            }
        }

        // ─── Guard: user not found ────────────────────────────────────────────

        test("guard: non-existent email throws USER_NOT_FOUND") {
            shouldThrow<NotFoundException> {
                adminService.deleteUserByEmail(adminId, "ghost@test.com", confirm = true)
            }.code shouldBe "USER_NOT_FOUND"
        }
    }
}
