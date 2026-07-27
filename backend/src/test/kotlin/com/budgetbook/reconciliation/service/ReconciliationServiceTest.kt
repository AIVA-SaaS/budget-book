package com.budgetbook.reconciliation.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.reconciliation.domain.Reconciliation
import com.budgetbook.reconciliation.domain.ReconciliationItem
import com.budgetbook.reconciliation.domain.ReconciliationItemKind
import com.budgetbook.reconciliation.dto.CreateReconciliationRequest
import com.budgetbook.reconciliation.repository.ReconciliationItemRepository
import com.budgetbook.reconciliation.repository.ReconciliationRepository
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.repository.TransferRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.springframework.data.jpa.domain.Specification
import java.time.LocalDate
import java.util.Optional
import java.util.UUID

/**
 * 정산 서비스 검증 경계 테스트 (mock 기반).
 *
 * DB 제약(CHECK/FK/partial UNIQUE)은 mock 으로 검증할 수 없으므로
 * [com.budgetbook.reconciliation.integration.ReconciliationIntegrationTest] 가 담당한다.
 * 여기서는 **서비스 레이어 규칙** 만 고정한다: 입력 검증, 커플/가시성 게이팅, 소계 저장,
 * 조회자 게이팅 후 재집계, sync 이벤트 발행.
 */
class ReconciliationServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val reconciliationRepository = mockk<ReconciliationRepository>()
    val reconciliationItemRepository = mockk<ReconciliationItemRepository>(relaxed = true)
    val transactionRepository = mockk<TransactionRepository>()
    val transferRepository = mockk<TransferRepository>()
    val userRepository = mockk<UserRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val service = ReconciliationService(
        reconciliationRepository,
        reconciliationItemRepository,
        transactionRepository,
        transferRepository,
        userRepository,
        coupleResolver,
        ReconciliationAggregator(),
        ReconciliationScope(),
        syncEventPublisher
    )

    val me = User(email = "me@test.com", nickname = "Me", provider = AuthProvider.GOOGLE, providerId = "g1")
    val partner = User(email = "p@test.com", nickname = "Partner", provider = AuthProvider.KAKAO, providerId = "k1")
    val couple = Couple(user1 = me, user2 = partner, status = CoupleStatus.ACTIVE)
    val otherCouple = Couple(user1 = partner, user2 = null, status = CoupleStatus.ACTIVE)

    fun txn(
        amount: Long = 10000,
        type: TransactionType = TransactionType.EXPENSE,
        date: LocalDate = LocalDate.of(2026, 7, 15),
        owningCouple: Couple = couple,
        visibility: Visibility = Visibility.SHARED,
        owner: User? = null
    ) = Transaction(
        couple = owningCouple,
        author = me,
        type = type,
        amount = amount,
        description = "테스트 거래",
        transactionDate = date,
        visibility = visibility,
        owner = owner
    )

    // 공통 stub. `beforeEach` 를 쓰면 InstancePerLeaf 에서 **컨테이너 본문(When 블록)이 먼저
    // 실행**되어 stub 이 아직 없거나, 반대로 컨테이너에서 세팅한 구체 stub 을 beforeEach 가
    // 덮어써 테스트가 조용히 무력화된다. 그래서 각 When 블록이 명시적으로 호출한다.
    fun defaults() {
        every { coupleResolver.getActiveCouple(me.id) } returns couple
        every { userRepository.findById(me.id) } returns Optional.of(me)
        every { reconciliationRepository.findMaxSeq(couple.id, any()) } returns null
        every { reconciliationRepository.saveAndFlush(any<Reconciliation>()) } answers { firstArg() }
        every { reconciliationRepository.save(any<Reconciliation>()) } answers { firstArg() }
        every { reconciliationItemRepository.findByTransactionIdIn(any()) } returns emptyList()
        every { reconciliationItemRepository.findByTransferIdIn(any()) } returns emptyList()
        every { transferRepository.findAllById(any()) } returns emptyList()
    }

    Given("정산 생성 입력 검증") {
        When("선택 항목이 하나도 없으면") {
            defaults()
            Then("VALIDATION_ERROR") {
                shouldThrow<BusinessException> {
                    service.createReconciliation(me.id, CreateReconciliationRequest("2026-07"))
                }.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("항목이 상한(1000건)을 넘으면") {
            defaults()
            Then("VALIDATION_ERROR") {
                val tooMany = (1..1001).map { UUID.randomUUID() }
                shouldThrow<BusinessException> {
                    service.createReconciliation(
                        me.id,
                        CreateReconciliationRequest("2026-07", transactionIds = tooMany)
                    )
                }.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("대상 월과 다른 달의 거래가 섞이면") {
            defaults()
            val tx = txn(date = LocalDate.of(2026, 8, 3))
            every { transactionRepository.findAllById(listOf(tx.id)) } returns listOf(tx)

            Then("VALIDATION_ERROR") {
                shouldThrow<BusinessException> {
                    service.createReconciliation(
                        me.id,
                        CreateReconciliationRequest("2026-07", transactionIds = listOf(tx.id))
                    )
                }.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("존재하지 않는 거래 id 면") {
            defaults()
            val missing = UUID.randomUUID()
            every { transactionRepository.findAllById(listOf(missing)) } returns emptyList()

            Then("TRANSACTION_NOT_FOUND") {
                shouldThrow<NotFoundException> {
                    service.createReconciliation(
                        me.id,
                        CreateReconciliationRequest("2026-07", transactionIds = listOf(missing))
                    )
                }.code shouldBe "TRANSACTION_NOT_FOUND"
            }
        }
    }

    Given("커플/가시성 게이팅") {
        When("다른 커플의 거래를 정산하려 하면") {
            defaults()
            val tx = txn(owningCouple = otherCouple)
            every { transactionRepository.findAllById(listOf(tx.id)) } returns listOf(tx)

            Then("FORBIDDEN") {
                shouldThrow<ForbiddenException> {
                    service.createReconciliation(
                        me.id,
                        CreateReconciliationRequest("2026-07", transactionIds = listOf(tx.id))
                    )
                }.code shouldBe "FORBIDDEN"
            }
        }

        When("파트너의 개인(PRIVATE) 거래를 정산하려 하면") {
            defaults()
            val tx = txn(visibility = Visibility.PRIVATE, owner = partner)
            every { transactionRepository.findAllById(listOf(tx.id)) } returns listOf(tx)

            Then("FORBIDDEN — 볼 수 없는 항목은 정산도 못 한다") {
                shouldThrow<ForbiddenException> {
                    service.createReconciliation(
                        me.id,
                        CreateReconciliationRequest("2026-07", transactionIds = listOf(tx.id))
                    )
                }.code shouldBe "FORBIDDEN"
            }
        }

        When("본인의 개인 거래면") {
            defaults()
            val tx = txn(visibility = Visibility.PRIVATE, owner = me)
            every { transactionRepository.findAllById(listOf(tx.id)) } returns listOf(tx)

            Then("정상 정산된다") {
                val result = service.createReconciliation(
                    me.id,
                    CreateReconciliationRequest("2026-07", transactionIds = listOf(tx.id))
                )
                result.itemCount shouldBe 1
                result.totalExpense shouldBe 10000
            }
        }
    }

    Given("이미 정산된 항목") {
        val tx = txn()
        When("다른 스냅샷에 이미 기록돼 있으면") {
            defaults()
            every { transactionRepository.findAllById(listOf(tx.id)) } returns listOf(tx)
            every { reconciliationItemRepository.findByTransactionIdIn(listOf(tx.id)) } returns listOf(
                ReconciliationItem(
                    reconciliation = Reconciliation(
                        couple = couple, yearMonth = "2026-07", seq = 1, reconciledBy = me
                    ),
                    itemKind = ReconciliationItemKind.TRANSACTION,
                    transactionId = tx.id,
                    snapshotAmount = 10000,
                    snapshotDate = tx.transactionDate,
                    snapshotKind = "EXPENSE"
                )
            )

            Then("409 ALREADY_RECONCILED") {
                shouldThrow<ConflictException> {
                    service.createReconciliation(
                        me.id,
                        CreateReconciliationRequest("2026-07", transactionIds = listOf(tx.id))
                    )
                }.code shouldBe "ALREADY_RECONCILED"
            }
        }
    }

    Given("정산 생성 성공") {
        val expense = txn(amount = 10000, type = TransactionType.EXPENSE)
        val income = txn(amount = 30000, type = TransactionType.INCOME)

        When("지출/수입 2건을 정산하면") {
            defaults()
            every { transactionRepository.findAllById(any()) } returns listOf(expense, income)

            val result = service.createReconciliation(
                me.id,
                CreateReconciliationRequest(
                    "2026-07", "1차",
                    transactionIds = listOf(expense.id, income.id)
                )
            )

            Then("회차는 1, 소계는 집계 규칙대로") {
                result.seq shouldBe 1
                result.label shouldBe "1차"
                result.itemCount shouldBe 2
                result.totalExpense shouldBe 10000
                result.totalIncome shouldBe 30000
                result.totalTransfer shouldBe 0
                result.items shouldHaveSize 2
            }

            Then("헤더에 소계가 저장된다 (FE 재계산 금지 전제)") {
                val saved = slot<Reconciliation>()
                verify { reconciliationRepository.save(capture(saved)) }
                saved.captured.itemCount shouldBe 2
                saved.captured.totalExpense shouldBe 10000
                saved.captured.totalIncome shouldBe 30000
            }

            Then("RECONCILIATION 동기화 이벤트가 발행된다") {
                val event = slot<SyncEvent>()
                verify { syncEventPublisher.publish(capture(event)) }
                event.captured.entityType shouldBe "RECONCILIATION"
                event.captured.type shouldBe "RECONCILIATION_CREATED"
                event.captured.coupleId shouldBe couple.id
                event.captured.authorId shouldBe me.id
            }
        }

        When("회차가 이미 2까지 있으면") {
            defaults()
            every { reconciliationRepository.findMaxSeq(couple.id, "2026-07") } returns 2
            every { transactionRepository.findAllById(any()) } returns listOf(expense)

            Then("다음 회차는 3") {
                service.createReconciliation(
                    me.id,
                    CreateReconciliationRequest("2026-07", transactionIds = listOf(expense.id))
                ).seq shouldBe 3
            }
        }
    }

    Given("조회 게이팅") {
        val header = Reconciliation(couple = couple, yearMonth = "2026-07", seq = 1, reconciledBy = me)
        val mine = txn(amount = 10000, visibility = Visibility.PRIVATE, owner = me)
        val partners = txn(amount = 50000, visibility = Visibility.PRIVATE, owner = partner)

        fun itemOf(tx: Transaction) = ReconciliationItem(
            reconciliation = header,
            itemKind = ReconciliationItemKind.TRANSACTION,
            transactionId = tx.id,
            snapshotAmount = tx.amount,
            snapshotDate = tx.transactionDate,
            snapshotKind = tx.type.name,
            snapshotVisibility = tx.visibility,
            snapshotOwnerId = tx.owner?.id
        )

        When("파트너의 개인 항목이 스냅샷에 포함돼 있으면") {
            defaults()
            every { reconciliationRepository.findById(header.id) } returns Optional.of(header)
            every { reconciliationItemRepository.findByReconciliationId(header.id) } returns
                listOf(itemOf(mine), itemOf(partners))
            every { transactionRepository.findAllById(any()) } returns listOf(mine, partners)

            val detail = service.getReconciliation(me.id, header.id)

            Then("목록에서 제외되고 소계도 게이팅 후 재계산된다") {
                detail.items shouldHaveSize 1
                detail.items.single().refId shouldBe mine.id
                // 50000(파트너 개인) 이 빠진 금액이어야 한다 — 안 빠지면 "합계 ≠ 행".
                detail.totalExpense shouldBe 10000
                detail.itemCount shouldBe 1
            }
        }
    }

    Given("잔액 수정(ADJUSTMENT) 은 정산 대상이 아니다") {
        When("잔액 수정 거래를 정산에 넣으려 하면") {
            defaults()
            val adj = txn(type = TransactionType.ADJUSTMENT, amount = -30000)
            every { transactionRepository.findAllById(listOf(adj.id)) } returns listOf(adj)

            Then("VALIDATION_ERROR — 조용히 건너뛰지 않는다") {
                // 무시하면 사용자가 고른 N건과 실제 기록 건수가 어긋난다.
                shouldThrow<BusinessException> {
                    service.createReconciliation(
                        me.id,
                        CreateReconciliationRequest("2026-07", transactionIds = listOf(adj.id))
                    )
                }.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("요약을 조회하면") {
            defaults()
            val expense = txn(amount = 10000)
            val income = txn(type = TransactionType.INCOME, amount = 70000)
            val adj = txn(type = TransactionType.ADJUSTMENT, amount = -30000)
            every { transactionRepository.findAll(any<Specification<Transaction>>()) } returns
                listOf(expense, income, adj)
            every {
                transferRepository.findByCoupleIdAndTransferDateBetweenOrderByTransferDateDesc(
                    couple.id, any(), any()
                )
            } returns emptyList()
            every { reconciliationRepository.countByCoupleIdAndYearMonth(couple.id, "2026-07") } returns 0

            val summary = service.getSummary(me.id, 2026, 7)

            Then("미기록 건수·소계 어디에도 잔액 수정이 없다") {
                // 건수까지 빼야 한다. 금액만 0 원 처리하면 목록에는 계속 남아
                // "이 달 정산 완료" 에 영원히 도달하지 못한다.
                summary.unrecordedCount shouldBe 2
                summary.unrecordedExpense shouldBe 10000
                summary.unrecordedIncome shouldBe 70000
            }
        }

        When("남은 미기록이 잔액 수정뿐이면") {
            defaults()
            val adj = txn(type = TransactionType.ADJUSTMENT, amount = -30000)
            every { transactionRepository.findAll(any<Specification<Transaction>>()) } returns listOf(adj)
            every {
                transferRepository.findByCoupleIdAndTransferDateBetweenOrderByTransferDateDesc(
                    couple.id, any(), any()
                )
            } returns emptyList()
            every { reconciliationRepository.countByCoupleIdAndYearMonth(couple.id, "2026-07") } returns 1

            val summary = service.getSummary(me.id, 2026, 7)

            Then("미기록 0건 — FE 가 \"이 달 정산 완료\" 로 판정할 수 있다") {
                summary.unrecordedCount shouldBe 0
                summary.unrecordedExpense shouldBe 0
                summary.unrecordedIncome shouldBe 0
            }
        }
    }

    Given("다른 커플의 스냅샷 접근") {
        val foreign = Reconciliation(couple = otherCouple, yearMonth = "2026-07", seq = 1, reconciledBy = partner)

        When("id 로 직접 조회하면") {
            defaults()
            every { reconciliationRepository.findById(foreign.id) } returns Optional.of(foreign)

            Then("존재 자체를 노출하지 않고 404") {
                shouldThrow<NotFoundException> {
                    service.getReconciliation(me.id, foreign.id)
                }.code shouldBe "RECONCILIATION_NOT_FOUND"
            }
        }
    }
})
