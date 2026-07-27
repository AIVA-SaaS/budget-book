package com.budgetbook.reconciliation.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ConflictException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.reconciliation.domain.Reconciliation
import com.budgetbook.reconciliation.domain.ReconciliationItem
import com.budgetbook.reconciliation.domain.ReconciliationItemKind
import com.budgetbook.reconciliation.dto.CreateReconciliationRequest
import com.budgetbook.reconciliation.dto.ReconciliationDetailResponse
import com.budgetbook.reconciliation.dto.ReconciliationItemResponse
import com.budgetbook.reconciliation.dto.ReconciliationResponse
import com.budgetbook.reconciliation.dto.ReconciliationSummaryResponse
import com.budgetbook.reconciliation.dto.UpdateReconciliationRequest
import com.budgetbook.reconciliation.repository.ReconciliationItemRepository
import com.budgetbook.reconciliation.repository.ReconciliationRepository
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transaction.repository.TransactionSpecifications
import com.budgetbook.transfer.domain.Transfer
import com.budgetbook.transfer.repository.TransferRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

/**
 * 정산 스냅샷 서비스.
 *
 * 핵심 규칙 4가지
 *  1) **한 항목은 최대 1개 스냅샷** — DB partial unique 로도 강제되지만, 사용자에게 의미 있는
 *     409 를 주기 위해 서비스에서도 선검사한다. 동시 요청 경합은 DB 제약이 최종 방어선.
 *  2) **조회자 게이팅 후 재집계** — 파트너의 PRIVATE 항목은 목록에서 빼고 소계도 다시 계산한다.
 *     전체 기준 소계를 그대로 주면 "합계 ≠ 보이는 행" 불일치가 된다.
 *  3) **소계 계산은 [ReconciliationAggregator] 단독** — 서비스에서 sumOf 를 직접 쓰지 않는다.
 *  4) **저장 순서 saveAndFlush(헤더) → items** — items 가 헤더 PK 를 FK 참조하므로,
 *     flush 없이 진행하면 FK 위반이 날 수 있다 (2026-07-22 카드 정산 FK 사고와 같은 부류).
 */
@Service
class ReconciliationService(
    private val reconciliationRepository: ReconciliationRepository,
    private val reconciliationItemRepository: ReconciliationItemRepository,
    private val transactionRepository: TransactionRepository,
    private val transferRepository: TransferRepository,
    private val userRepository: UserRepository,
    private val coupleResolver: CoupleResolver,
    private val aggregator: ReconciliationAggregator,
    private val syncEventPublisher: SyncEventPublisher
) {

    companion object {
        /** 한 번에 정산할 수 있는 항목 수 상한 (단일 트랜잭션 시간 보호). */
        const val MAX_ITEMS_PER_REQUEST = 1000
    }

    // ── 조회 ──────────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    fun listReconciliations(userId: UUID, year: Int, month: Int): List<ReconciliationResponse> {
        val couple = coupleResolver.getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)

        val headers = reconciliationRepository
            .findByCoupleIdAndYearMonthOrderBySeqDesc(couple.id, yearMonth)
        if (headers.isEmpty()) return emptyList()

        // 항목을 한 번에 벌크 조회 (헤더당 조회 = N+1 금지).
        val itemsByHeader = reconciliationItemRepository
            .findByReconciliationIdIn(headers.map { it.id })
            .groupBy { it.reconciliation.id }

        val origins = loadOrigins(itemsByHeader.values.flatten())

        return headers.map { header ->
            val visible = itemsByHeader[header.id].orEmpty().filter { visibleTo(it, origins, userId) }
            val totals = aggregator.aggregate(visible)
            ReconciliationResponse(
                id = header.id,
                yearMonth = header.yearMonth,
                seq = header.seq,
                label = header.label,
                itemCount = totals.itemCount,
                totalIncome = totals.totalIncome,
                totalExpense = totals.totalExpense,
                totalTransfer = totals.totalTransfer,
                reconciledAt = header.reconciledAt,
                reconciledBy = header.reconciledBy.toSummary(),
                hasChangedItems = visible.any { changedAfterReconcile(it, origins) },
                hasDeletedItems = visible.any { it.originDeleted }
            )
        }
    }

    @Transactional(readOnly = true)
    fun getReconciliation(userId: UUID, id: UUID): ReconciliationDetailResponse {
        val couple = coupleResolver.getActiveCouple(userId)
        val header = findOwnedHeader(id, couple)
        val items = reconciliationItemRepository.findByReconciliationId(header.id)
        return toDetail(header, items, userId)
    }

    /**
     * 월말 누락 점검 요약.
     *
     * 미기록 = 해당 월 항목 중 어떤 스냅샷에도 없는 것. 거래는 조회자 게이팅된 Specification
     * 으로, 이체는 월 전체를 가져와 계산한다 (이체는 현재 전부 SHARED).
     */
    @Transactional(readOnly = true)
    fun getSummary(userId: UUID, year: Int, month: Int): ReconciliationSummaryResponse {
        val couple = coupleResolver.getActiveCouple(userId)
        val yearMonth = formatYearMonth(year, month)
        val ym = YearMonth.of(year, month)

        val transactions = transactionRepository.findAll(
            TransactionSpecifications.withFilters(
                coupleId = couple.id,
                startDate = ym.atDay(1),
                endDate = ym.atEndOfMonth(),
                type = null, categoryId = null, keyword = null,
                paymentMethodId = null, pocketId = null,
                amountMin = null, amountMax = null,
                userId = userId
            )
        )
        val transfers = transferRepository
            .findByCoupleIdAndTransferDateBetweenOrderByTransferDateDesc(
                couple.id, ym.atDay(1), ym.atEndOfMonth()
            )

        val reconciledTxIds = transactions.takeIf { it.isNotEmpty() }
            ?.let { txs -> reconciliationItemRepository.findByTransactionIdIn(txs.map { it.id }) }
            ?.mapNotNull { it.transactionId }?.toSet() ?: emptySet()
        val reconciledTfIds = transfers.takeIf { it.isNotEmpty() }
            ?.let { tfs -> reconciliationItemRepository.findByTransferIdIn(tfs.map { it.id }) }
            ?.mapNotNull { it.transferId }?.toSet() ?: emptySet()

        val unrecordedTx = transactions.filter { it.id !in reconciledTxIds }
        val unrecordedTf = transfers.filter { it.id !in reconciledTfIds }

        // 미기록 소계도 스냅샷과 **같은 집계기** 로 계산한다 (규칙이 두 벌로 갈라지면
        // "미기록 + Σ스냅샷 = 월 전체" 가 깨진다).
        val entries =
            unrecordedTx.map { ReconciliationAggregator.Entry(it.type.name, it.amount) } +
                unrecordedTf.map { ReconciliationAggregator.Entry(it.kind.name, it.amount) }
        val totals = aggregator.aggregateEntries(entries)

        return ReconciliationSummaryResponse(
            yearMonth = yearMonth,
            snapshotCount = reconciliationRepository.countByCoupleIdAndYearMonth(couple.id, yearMonth),
            recordedCount = reconciledTxIds.size + reconciledTfIds.size,
            unrecordedCount = totals.itemCount,
            unrecordedIncome = totals.totalIncome,
            unrecordedExpense = totals.totalExpense,
            unrecordedTransfer = totals.totalTransfer,
            needsReviewCount = unrecordedTx.count { it.needsReview }
        )
    }

    // ── 변경 ──────────────────────────────────────────────────────────────────

    @Transactional
    fun createReconciliation(userId: UUID, request: CreateReconciliationRequest): ReconciliationDetailResponse {
        val couple = coupleResolver.getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val totalRequested = request.transactionIds.size + request.transferIds.size
        if (totalRequested == 0) {
            throw BusinessException("VALIDATION_ERROR", "정산할 항목을 1건 이상 선택하세요.")
        }
        if (totalRequested > MAX_ITEMS_PER_REQUEST) {
            throw BusinessException(
                "VALIDATION_ERROR",
                "한 번에 정산할 수 있는 항목은 최대 ${MAX_ITEMS_PER_REQUEST}건입니다."
            )
        }

        val nextSeq = (reconciliationRepository.findMaxSeq(couple.id, request.yearMonth) ?: 0) + 1
        val header = Reconciliation(
            couple = couple,
            yearMonth = request.yearMonth,
            seq = nextSeq,
            label = request.label?.takeIf { it.isNotBlank() },
            reconciledBy = user
        )
        // items 가 헤더 PK 를 FK 참조 → flush 로 헤더 row 를 먼저 확정한다.
        val savedHeader = reconciliationRepository.saveAndFlush(header)

        val items = buildItems(
            couple = couple,
            userId = userId,
            header = savedHeader,
            yearMonth = request.yearMonth,
            transactionIds = request.transactionIds,
            transferIds = request.transferIds
        )
        reconciliationItemRepository.saveAll(items)
        applyTotals(savedHeader, items)
        reconciliationRepository.save(savedHeader)

        publish("RECONCILIATION_CREATED", savedHeader.id, couple.id, userId)
        return toDetail(savedHeader, items, userId)
    }

    @Transactional
    fun updateReconciliation(
        userId: UUID,
        id: UUID,
        request: UpdateReconciliationRequest
    ): ReconciliationDetailResponse {
        val couple = coupleResolver.getActiveCouple(userId)
        val header = findOwnedHeader(id, couple)

        val current = reconciliationItemRepository.findByReconciliationId(header.id).toMutableList()

        // 1) 제외 — 제외된 항목은 미기록으로 복귀한다.
        if (request.removeItemIds.isNotEmpty()) {
            val removeIds = request.removeItemIds.toSet()
            val toRemove = current.filter { it.id in removeIds }
            val unknown = removeIds - toRemove.map { it.id }.toSet()
            if (unknown.isNotEmpty()) {
                throw NotFoundException(
                    "RECONCILIATION_NOT_FOUND",
                    "이 정산에 없는 항목이 포함되어 있습니다."
                )
            }
            reconciliationItemRepository.deleteAll(toRemove)
            current.removeAll(toRemove)
        }

        // 2) 추가
        val added = buildItems(
            couple = couple,
            userId = userId,
            header = header,
            yearMonth = header.yearMonth,
            transactionIds = request.addTransactionIds,
            transferIds = request.addTransferIds
        )
        if (added.isNotEmpty()) {
            if (current.size + added.size > MAX_ITEMS_PER_REQUEST) {
                throw BusinessException(
                    "VALIDATION_ERROR",
                    "한 스냅샷의 항목은 최대 ${MAX_ITEMS_PER_REQUEST}건입니다."
                )
            }
            reconciliationItemRepository.saveAll(added)
            current.addAll(added)
        }

        request.label?.let { header.label = it.takeIf { l -> l.isNotBlank() } }

        // 3) 항목이 하나도 남지 않으면 빈 스냅샷을 남기지 않고 삭제한다.
        if (current.isEmpty()) {
            reconciliationRepository.delete(header)
            publish("RECONCILIATION_DELETED", header.id, couple.id, userId)
            return ReconciliationDetailResponse(
                id = header.id,
                yearMonth = header.yearMonth,
                seq = header.seq,
                label = header.label,
                itemCount = 0,
                totalIncome = 0,
                totalExpense = 0,
                totalTransfer = 0,
                reconciledAt = header.reconciledAt,
                reconciledBy = header.reconciledBy.toSummary(),
                hasChangedItems = false,
                hasDeletedItems = false,
                items = emptyList()
            )
        }

        applyTotals(header, current)
        reconciliationRepository.save(header)
        publish("RECONCILIATION_UPDATED", header.id, couple.id, userId)
        return toDetail(header, current, userId)
    }

    @Transactional
    fun deleteReconciliation(userId: UUID, id: UUID) {
        val couple = coupleResolver.getActiveCouple(userId)
        val header = findOwnedHeader(id, couple)
        // items 는 FK ON DELETE CASCADE + orphanRemoval 로 함께 삭제되고,
        // 담겨 있던 거래/이체는 (원본 그대로) 미기록으로 복귀한다.
        reconciliationRepository.delete(header)
        publish("RECONCILIATION_DELETED", id, couple.id, userId)
    }

    // ── 내부 ──────────────────────────────────────────────────────────────────

    /**
     * 요청 id 들을 검증해 스냅샷 항목으로 만든다.
     *
     * 검증: 커플 소속 → 조회자 가시성 → 대상 월 일치 → 이미 정산됨(409).
     */
    private fun buildItems(
        couple: Couple,
        userId: UUID,
        header: Reconciliation,
        yearMonth: String,
        transactionIds: List<UUID>,
        transferIds: List<UUID>
    ): List<ReconciliationItem> {
        if (transactionIds.isEmpty() && transferIds.isEmpty()) return emptyList()

        val items = mutableListOf<ReconciliationItem>()

        if (transactionIds.isNotEmpty()) {
            val distinctIds = transactionIds.distinct()
            val found = transactionRepository.findAllById(distinctIds).associateBy { it.id }
            val alreadyReconciled = reconciliationItemRepository.findByTransactionIdIn(distinctIds)
                .mapNotNull { it.transactionId }.toSet()

            for (txId in distinctIds) {
                val tx = found[txId]
                    ?: throw NotFoundException("TRANSACTION_NOT_FOUND", "Transaction does not exist.")
                if (tx.couple.id != couple.id) {
                    throw ForbiddenException("FORBIDDEN", "Transaction belongs to a different couple.")
                }
                if (!canSee(tx.visibility, tx.owner?.id, userId)) {
                    throw ForbiddenException("FORBIDDEN", "Cannot reconcile a partner's private transaction.")
                }
                requireSameMonth(tx.transactionDate, yearMonth)
                if (txId in alreadyReconciled) {
                    throw ConflictException(
                        "ALREADY_RECONCILED",
                        "이미 정산에 기록된 거래가 포함되어 있습니다."
                    )
                }
                items += ReconciliationItem(
                    reconciliation = header,
                    itemKind = ReconciliationItemKind.TRANSACTION,
                    transactionId = tx.id,
                    snapshotAmount = tx.amount,
                    snapshotDate = tx.transactionDate,
                    snapshotDescription = tx.description,
                    snapshotKind = aggregator.snapshotKindOf(tx.type),
                    snapshotVisibility = tx.visibility,
                    snapshotOwnerId = tx.owner?.id
                )
            }
        }

        if (transferIds.isNotEmpty()) {
            val distinctIds = transferIds.distinct()
            val found = transferRepository.findAllById(distinctIds).associateBy { it.id }
            val alreadyReconciled = reconciliationItemRepository.findByTransferIdIn(distinctIds)
                .mapNotNull { it.transferId }.toSet()

            for (tfId in distinctIds) {
                val tf = found[tfId]
                    ?: throw NotFoundException("TRANSFER_NOT_FOUND", "Transfer does not exist.")
                if (tf.couple.id != couple.id) {
                    throw ForbiddenException("FORBIDDEN", "Transfer belongs to a different couple.")
                }
                requireSameMonth(tf.transferDate, yearMonth)
                if (tfId in alreadyReconciled) {
                    throw ConflictException(
                        "ALREADY_RECONCILED",
                        "이미 정산에 기록된 이체가 포함되어 있습니다."
                    )
                }
                items += ReconciliationItem(
                    reconciliation = header,
                    itemKind = ReconciliationItemKind.TRANSFER,
                    transferId = tf.id,
                    snapshotAmount = tf.amount,
                    snapshotDate = tf.transferDate,
                    snapshotDescription = tf.description,
                    snapshotKind = aggregator.snapshotKindOf(tf.kind),
                    // 이체는 현재 전부 공유 자산 기준 (개인 자산 도입 시 함께 확장).
                    snapshotVisibility = Visibility.SHARED,
                    snapshotOwnerId = null
                )
            }
        }

        return items
    }

    private fun applyTotals(header: Reconciliation, items: Collection<ReconciliationItem>) {
        val totals = aggregator.aggregate(items)
        header.itemCount = totals.itemCount
        header.totalIncome = totals.totalIncome
        header.totalExpense = totals.totalExpense
        header.totalTransfer = totals.totalTransfer
    }

    private fun findOwnedHeader(id: UUID, couple: Couple): Reconciliation {
        val header = reconciliationRepository.findById(id).orElseThrow {
            NotFoundException("RECONCILIATION_NOT_FOUND", "Reconciliation does not exist.")
        }
        if (header.couple.id != couple.id) {
            // 다른 커플의 스냅샷은 존재 자체를 노출하지 않는다.
            throw NotFoundException("RECONCILIATION_NOT_FOUND", "Reconciliation does not exist.")
        }
        return header
    }

    private fun toDetail(
        header: Reconciliation,
        items: Collection<ReconciliationItem>,
        userId: UUID
    ): ReconciliationDetailResponse {
        val origins = loadOrigins(items)
        val visible = items.filter { visibleTo(it, origins, userId) }
        val totals = aggregator.aggregate(visible)

        return ReconciliationDetailResponse(
            id = header.id,
            yearMonth = header.yearMonth,
            seq = header.seq,
            label = header.label,
            itemCount = totals.itemCount,
            totalIncome = totals.totalIncome,
            totalExpense = totals.totalExpense,
            totalTransfer = totals.totalTransfer,
            reconciledAt = header.reconciledAt,
            reconciledBy = header.reconciledBy.toSummary(),
            hasChangedItems = visible.any { changedAfterReconcile(it, origins) },
            hasDeletedItems = visible.any { it.originDeleted },
            items = visible
                .sortedWith(compareByDescending<ReconciliationItem> { it.snapshotDate }.thenBy { it.id })
                .map { item ->
                    val origin = origins.forItem(item)
                    ReconciliationItemResponse(
                        itemId = item.id,
                        itemKind = item.itemKind.name,
                        refId = item.refId,
                        snapshotAmount = item.snapshotAmount,
                        snapshotDate = item.snapshotDate,
                        snapshotDescription = item.snapshotDescription,
                        snapshotKind = item.snapshotKind,
                        currentAmount = origin?.amount,
                        currentDate = origin?.date,
                        changedAfterReconcile = changedAfterReconcile(item, origins),
                        originDeleted = item.originDeleted
                    )
                }
        )
    }

    /** 항목들의 원본 거래/이체를 벌크 조회 (항목당 조회 금지). */
    private fun loadOrigins(items: Collection<ReconciliationItem>): Origins {
        val txIds = items.mapNotNull { it.transactionId }
        val tfIds = items.mapNotNull { it.transferId }
        val txs = if (txIds.isEmpty()) emptyMap() else
            transactionRepository.findAllById(txIds).associateBy { it.id }
        val tfs = if (tfIds.isEmpty()) emptyMap() else
            transferRepository.findAllById(tfIds).associateBy { it.id }
        return Origins(txs, tfs)
    }

    private data class OriginView(val amount: Long, val date: LocalDate)

    private inner class Origins(
        val transactions: Map<UUID, Transaction>,
        val transfers: Map<UUID, Transfer>
    ) {
        fun forItem(item: ReconciliationItem): OriginView? = when (item.itemKind) {
            ReconciliationItemKind.TRANSACTION ->
                item.transactionId?.let { transactions[it] }?.let { OriginView(it.amount, it.transactionDate) }
            ReconciliationItemKind.TRANSFER ->
                item.transferId?.let { transfers[it] }?.let { OriginView(it.amount, it.transferDate) }
        }

        /** 게이팅 기준 visibility/owner. 원본이 있으면 **원본의 현재 값** 이 우선이다. */
        fun visibilityOf(item: ReconciliationItem): Pair<Visibility, UUID?> {
            val tx = item.transactionId?.let { transactions[it] }
            return if (tx != null) tx.visibility to tx.owner?.id
            else item.snapshotVisibility to item.snapshotOwnerId
        }
    }

    /**
     * 조회자에게 보이는 항목인지. 원본이 나중에 PRIVATE 로 바뀌면 파트너에게서 즉시 사라진다
     * (스냅샷 복제값이 아니라 원본 현재 값 기준).
     */
    private fun visibleTo(item: ReconciliationItem, origins: Origins, userId: UUID): Boolean {
        val (visibility, ownerId) = origins.visibilityOf(item)
        return canSee(visibility, ownerId, userId)
    }

    private fun canSee(visibility: Visibility, ownerId: UUID?, userId: UUID): Boolean =
        visibility != Visibility.PRIVATE || ownerId == null || ownerId == userId

    /** 정산 후 원본 금액/날짜가 바뀌었는지. 원본이 삭제된 경우는 [ReconciliationItem.originDeleted] 로 구분. */
    private fun changedAfterReconcile(item: ReconciliationItem, origins: Origins): Boolean {
        val origin = origins.forItem(item) ?: return false
        return origin.amount != item.snapshotAmount || origin.date != item.snapshotDate
    }

    private fun requireSameMonth(date: LocalDate, yearMonth: String) {
        if (YearMonth.from(date).toString() != yearMonth) {
            throw BusinessException(
                "VALIDATION_ERROR",
                "정산 대상 월($yearMonth) 이 아닌 항목이 포함되어 있습니다."
            )
        }
    }

    private fun formatYearMonth(year: Int, month: Int): String = YearMonth.of(year, month).toString()

    private fun publish(type: String, entityId: UUID, coupleId: UUID, authorId: UUID) {
        syncEventPublisher.publish(
            SyncEvent(
                type = type,
                entityType = "RECONCILIATION",
                entityId = entityId,
                coupleId = coupleId,
                authorId = authorId
            )
        )
    }

    private fun com.budgetbook.auth.domain.User.toSummary() =
        UserSummary(id = id, nickname = nickname, profileImageUrl = profileImageUrl)
}
