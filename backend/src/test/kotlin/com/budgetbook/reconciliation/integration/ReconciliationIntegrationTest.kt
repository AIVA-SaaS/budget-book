package com.budgetbook.reconciliation.integration

import com.budgetbook.admin.integration.HighApiVersionDockerStrategy
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.reconciliation.dto.CreateReconciliationRequest
import com.budgetbook.reconciliation.dto.UpdateReconciliationRequest
import com.budgetbook.reconciliation.service.ReconciliationService
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
 * 정산 스냅샷(V65) 통합테스트 — 실 PostgreSQL + Flyway.
 *
 * mock 기반 테스트로는 검증할 수 없는 것만 여기서 확인한다 (2026-07-22 카드 정산 FK 사고 교훈:
 * mock 은 CHECK/FK/partial UNIQUE 를 절대 잡지 못한다).
 *
 * 1. 헤더→항목 저장 순서 (items 가 헤더 PK 를 FK 참조 → saveAndFlush 필요)
 * 2. `uk_recon_items_transaction` partial UNIQUE — 한 거래는 최대 1개 스냅샷
 * 3. 원본 거래 삭제 시 `ON DELETE SET NULL` — 스냅샷 기록은 남고 참조만 끊긴다
 * 4. `ck_recon_items_ref` CHECK — item_kind 와 FK 조합 강제
 * 5. 스냅샷 삭제 시 항목 CASCADE + 원본 거래는 보존
 */
@SpringBootTest
@ActiveProfiles("integration-test")
@ContextConfiguration(initializers = [ReconciliationIntegrationTest.DataSourceInitializer::class])
class ReconciliationIntegrationTest(
    private val reconciliationService: ReconciliationService,
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

    init {
        test("스냅샷 생성 — 헤더/항목이 실제로 커밋되고 소계가 저장된다") {
            val f = inTx { fixture("recon-create") }

            val result = inTx {
                reconciliationService.createReconciliation(
                    f.userId,
                    CreateReconciliationRequest(
                        yearMonth = "2026-06",
                        label = "1차",
                        transactionIds = listOf(f.expenseTxnId, f.incomeTxnId),
                        transferIds = listOf(f.genericTransferId)
                    )
                )
            }

            result.seq shouldBe 1
            result.label shouldBe "1차"
            result.itemCount shouldBe 3
            result.totalExpense shouldBe 10000
            result.totalIncome shouldBe 30000
            result.totalTransfer shouldBe 5000

            // 헤더 소계가 DB 에 저장돼 있어야 한다 (조회 때 재집계 없이 사용).
            inTx {
                countRows("reconciliations", result.id) shouldBe 1
                itemCountOf(result.id) shouldBe 3
                totalExpenseOf(result.id) shouldBe 10000L
            }
        }

        test("한 거래는 최대 1개 스냅샷 — 두 번째 정산은 409") {
            val f = inTx { fixture("recon-dup") }

            inTx {
                reconciliationService.createReconciliation(
                    f.userId,
                    CreateReconciliationRequest("2026-06", "1차", listOf(f.expenseTxnId))
                )
            }

            shouldThrow<ConflictException> {
                inTx {
                    reconciliationService.createReconciliation(
                        f.userId,
                        CreateReconciliationRequest("2026-06", "2차", listOf(f.expenseTxnId))
                    )
                }
            }.code shouldBe "ALREADY_RECONCILED"
        }

        test("partial UNIQUE 가 DB 레벨에서 중복 기록을 막는다 (동시 요청 최종 방어선)") {
            val f = inTx { fixture("recon-db-unique") }
            val created = inTx {
                reconciliationService.createReconciliation(
                    f.userId,
                    CreateReconciliationRequest("2026-06", "1차", listOf(f.expenseTxnId))
                )
            }

            // 서비스 선검사를 우회해 같은 transaction_id 를 직접 INSERT → 인덱스 위반이어야 한다.
            shouldThrow<org.hibernate.exception.ConstraintViolationException> {
                inTx {
                    em.createNativeQuery(
                        """INSERT INTO reconciliation_items
                           (id, reconciliation_id, item_kind, transaction_id, snapshot_amount,
                            snapshot_date, snapshot_kind, snapshot_visibility, created_at, updated_at)
                           VALUES (:id, :rid, 'TRANSACTION', :txId, 10000, :d, 'EXPENSE', 'SHARED', now(), now())"""
                    ).setParameter("id", UUID.randomUUID())
                        .setParameter("rid", created.id)
                        .setParameter("txId", f.expenseTxnId)
                        .setParameter("d", LocalDate.of(2026, 6, 15))
                        .executeUpdate()
                    em.flush()
                }
            }
        }

        test("ck_recon_items_ref — item_kind 와 어긋난 FK 조합은 거부된다") {
            val f = inTx { fixture("recon-check") }
            val created = inTx {
                reconciliationService.createReconciliation(
                    f.userId,
                    CreateReconciliationRequest("2026-06", "1차", listOf(f.expenseTxnId))
                )
            }

            // item_kind=TRANSACTION 인데 transfer_id 를 채우면 CHECK 위반.
            shouldThrow<org.hibernate.exception.ConstraintViolationException> {
                inTx {
                    em.createNativeQuery(
                        """INSERT INTO reconciliation_items
                           (id, reconciliation_id, item_kind, transfer_id, snapshot_amount,
                            snapshot_date, snapshot_kind, snapshot_visibility, created_at, updated_at)
                           VALUES (:id, :rid, 'TRANSACTION', :tfId, 5000, :d, 'GENERIC', 'SHARED', now(), now())"""
                    ).setParameter("id", UUID.randomUUID())
                        .setParameter("rid", created.id)
                        .setParameter("tfId", f.genericTransferId)
                        .setParameter("d", LocalDate.of(2026, 6, 20))
                        .executeUpdate()
                    em.flush()
                }
            }
        }

        test("원본 거래 삭제 — 스냅샷 항목은 남고 참조만 끊긴다 (SET NULL)") {
            val f = inTx { fixture("recon-origin-delete") }
            val created = inTx {
                reconciliationService.createReconciliation(
                    f.userId,
                    CreateReconciliationRequest("2026-06", "1차", listOf(f.expenseTxnId))
                )
            }

            inTx {
                em.createNativeQuery("DELETE FROM transactions WHERE id = :id")
                    .setParameter("id", f.expenseTxnId).executeUpdate()
            }

            // 항목 row 는 그대로, transaction_id 만 NULL.
            inTx { itemCountOf(created.id) shouldBe 1 }
            inTx {
                (
                    em.createNativeQuery(
                        "SELECT count(*) FROM reconciliation_items WHERE reconciliation_id = :rid AND transaction_id IS NULL"
                    ).setParameter("rid", created.id).singleResult as Number
                    ).toInt() shouldBe 1
            }

            // 상세 응답은 "원본 삭제됨" 으로 표시하고, 소계는 스냅샷 값을 유지한다.
            val detail = inTx { reconciliationService.getReconciliation(f.userId, created.id) }
            detail.items.single().originDeleted shouldBe true
            detail.items.single().currentAmount shouldBe null
            detail.totalExpense shouldBe 10000
        }

        test("정산 후 원본 금액 변경 — changedAfterReconcile 로 표면화") {
            val f = inTx { fixture("recon-drift") }
            val created = inTx {
                reconciliationService.createReconciliation(
                    f.userId,
                    CreateReconciliationRequest("2026-06", "1차", listOf(f.expenseTxnId))
                )
            }

            inTx {
                em.createNativeQuery("UPDATE transactions SET amount = 99999 WHERE id = :id")
                    .setParameter("id", f.expenseTxnId).executeUpdate()
            }

            val detail = inTx { reconciliationService.getReconciliation(f.userId, created.id) }
            detail.items.single().changedAfterReconcile shouldBe true
            detail.items.single().currentAmount shouldBe 99999
            // 스냅샷 소계는 정산 당시 값 유지 (대조 이력이므로).
            detail.totalExpense shouldBe 10000
            detail.hasChangedItems shouldBe true
        }

        test("스냅샷 삭제 — 항목은 CASCADE, 원본 거래는 보존되어 미기록으로 복귀") {
            val f = inTx { fixture("recon-delete") }
            val created = inTx {
                reconciliationService.createReconciliation(
                    f.userId,
                    CreateReconciliationRequest("2026-06", "1차", listOf(f.expenseTxnId))
                )
            }

            inTx { reconciliationService.deleteReconciliation(f.userId, created.id) }

            inTx {
                countRows("reconciliations", created.id) shouldBe 0
                itemCountOf(created.id) shouldBe 0
                // 원본 거래는 살아 있다.
                (
                    em.createNativeQuery("SELECT count(*) FROM transactions WHERE id = :id")
                        .setParameter("id", f.expenseTxnId).singleResult as Number
                    ).toInt() shouldBe 1
            }

            // 미기록으로 복귀 → summary 가 다시 센다.
            val summary = inTx { reconciliationService.getSummary(f.userId, 2026, 6) }
            summary.snapshotCount shouldBe 0
            summary.recordedCount shouldBe 0
            summary.unrecordedExpense shouldBe 10000
        }

        test("항목 제외로 비면 스냅샷 자체가 삭제된다") {
            val f = inTx { fixture("recon-empty") }
            val created = inTx {
                reconciliationService.createReconciliation(
                    f.userId,
                    CreateReconciliationRequest("2026-06", "1차", listOf(f.expenseTxnId))
                )
            }
            val itemId = created.items.single().itemId

            val patched = inTx {
                reconciliationService.updateReconciliation(
                    f.userId, created.id,
                    UpdateReconciliationRequest(removeItemIds = listOf(itemId))
                )
            }

            patched.itemCount shouldBe 0
            inTx { countRows("reconciliations", created.id) shouldBe 0 }
        }

        test("summary — 미기록 + 기록 = 월 전체 (ADJUSTMENT/카드결제 규칙 준수)") {
            val f = inTx { fixture("recon-summary") }

            val before = inTx { reconciliationService.getSummary(f.userId, 2026, 6) }
            // 지출 10000 + 수입 30000 + 이체 5000 + ADJUSTMENT(집계 제외) + 카드결제 이체(제외)
            before.unrecordedCount shouldBe 5
            before.unrecordedExpense shouldBe 10000
            before.unrecordedIncome shouldBe 30000
            before.unrecordedTransfer shouldBe 5000

            inTx {
                reconciliationService.createReconciliation(
                    f.userId,
                    CreateReconciliationRequest("2026-06", "1차", listOf(f.expenseTxnId))
                )
            }

            val after = inTx { reconciliationService.getSummary(f.userId, 2026, 6) }
            after.snapshotCount shouldBe 1
            after.recordedCount shouldBe 1
            after.unrecordedCount shouldBe 4
            // 기록된 지출이 미기록에서 빠진다 → 합은 보존.
            after.unrecordedExpense shouldBe 0
            (after.unrecordedExpense + 10000) shouldBe before.unrecordedExpense
        }

        test("다른 달 항목을 섞으면 400") {
            val f = inTx { fixture("recon-month") }
            shouldThrow<com.budgetbook.common.exception.BusinessException> {
                inTx {
                    reconciliationService.createReconciliation(
                        f.userId,
                        CreateReconciliationRequest("2026-07", "잘못된 달", listOf(f.expenseTxnId))
                    )
                }
            }.code shouldBe "VALIDATION_ERROR"
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private data class Fixture(
        val userId: UUID,
        val coupleId: UUID,
        val expenseTxnId: UUID,
        val incomeTxnId: UUID,
        val adjustmentTxnId: UUID,
        val genericTransferId: UUID,
        val cardSettlementTransferId: UUID
    )

    private fun <T> inTx(action: () -> T): T =
        TransactionTemplate(txManager).execute { action() }!!

    /** 2026-06 에 거래 3건(지출/수입/조정) + 이체 2건(일반/카드결제)을 만든다. */
    private fun fixture(tag: String): Fixture {
        val userId = insertUser("$tag@test.com")
        val coupleId = insertSelfCouple(userId)
        val categoryId = insertCategory(coupleId)
        val bankId = insertPaymentMethod(coupleId, "$tag-은행", "BANK")
        val cashId = insertPaymentMethod(coupleId, "$tag-현금", "CASH")
        val cardId = insertPaymentMethod(coupleId, "$tag-카드", "CREDIT")

        return Fixture(
            userId = userId,
            coupleId = coupleId,
            expenseTxnId = insertTxn(coupleId, userId, categoryId, "EXPENSE", 10000, LocalDate.of(2026, 6, 15)),
            incomeTxnId = insertTxn(coupleId, userId, categoryId, "INCOME", 30000, LocalDate.of(2026, 6, 10)),
            adjustmentTxnId = insertTxn(coupleId, userId, null, "ADJUSTMENT", -2000, LocalDate.of(2026, 6, 18)),
            genericTransferId = insertTransfer(coupleId, userId, bankId, cashId, 5000, "GENERIC"),
            cardSettlementTransferId = insertTransfer(coupleId, userId, bankId, cardId, 70000, "CARD_SETTLEMENT")
        )
    }

    private fun insertUser(email: String): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO users (id, email, nickname, provider, provider_id, role, is_active, created_at, updated_at)
               VALUES (:id, :email, 'Reconciler', 'GOOGLE', :pid, 'USER', true, now(), now())"""
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

    private fun insertTxn(
        coupleId: UUID,
        authorId: UUID,
        categoryId: UUID?,
        type: String,
        amount: Long,
        date: LocalDate
    ): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO transactions
               (id, couple_id, author_id, category_id, type, amount, description, transaction_date,
                visibility, needs_review, created_at, updated_at)
               VALUES (:id, :coupleId, :authorId, :categoryId, :type, :amount, :desc, :d,
                       'SHARED', false, now(), now())"""
        ).setParameter("id", id).setParameter("coupleId", coupleId).setParameter("authorId", authorId)
            .setParameter("categoryId", categoryId).setParameter("type", type)
            .setParameter("amount", amount).setParameter("desc", "$type 거래")
            .setParameter("d", date).executeUpdate()
        return id
    }

    private fun insertTransfer(
        coupleId: UUID,
        authorId: UUID,
        sourceId: UUID,
        destId: UUID,
        amount: Long,
        kind: String
    ): UUID {
        val id = UUID.randomUUID()
        em.createNativeQuery(
            """INSERT INTO transfers
               (id, couple_id, author_id, source_payment_method_id, destination_payment_method_id,
                amount, description, transfer_date, is_card_settlement, kind, created_at, updated_at)
               VALUES (:id, :coupleId, :authorId, :src, :dst, :amount, :desc, :d, :isCard, :kind, now(), now())"""
        ).setParameter("id", id).setParameter("coupleId", coupleId).setParameter("authorId", authorId)
            .setParameter("src", sourceId).setParameter("dst", destId)
            .setParameter("amount", amount).setParameter("desc", "$kind 이체")
            .setParameter("d", LocalDate.of(2026, 6, 20))
            .setParameter("isCard", kind == "CARD_SETTLEMENT")
            .setParameter("kind", kind).executeUpdate()
        return id
    }

    private fun countRows(table: String, id: UUID): Int =
        (
            em.createNativeQuery("SELECT count(*) FROM $table WHERE id = :id")
                .setParameter("id", id).singleResult as Number
            ).toInt()

    private fun itemCountOf(reconciliationId: UUID): Int =
        (
            em.createNativeQuery("SELECT count(*) FROM reconciliation_items WHERE reconciliation_id = :rid")
                .setParameter("rid", reconciliationId).singleResult as Number
            ).toInt()

    private fun totalExpenseOf(reconciliationId: UUID): Long =
        (
            em.createNativeQuery("SELECT total_expense FROM reconciliations WHERE id = :id")
                .setParameter("id", reconciliationId).singleResult as Number
            ).toLong()
}
