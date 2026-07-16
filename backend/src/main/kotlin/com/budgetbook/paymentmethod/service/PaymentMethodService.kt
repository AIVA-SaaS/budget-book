package com.budgetbook.paymentmethod.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.dto.AssetBalanceResponse
import com.budgetbook.paymentmethod.dto.CardPendingResponse
import com.budgetbook.paymentmethod.dto.CardSettlementMonth
import com.budgetbook.paymentmethod.dto.CardSettlementSummaryResponse
import com.budgetbook.paymentmethod.dto.CreatePaymentMethodRequest
import com.budgetbook.paymentmethod.dto.PaymentMethodResponse
import com.budgetbook.paymentmethod.dto.ReorderPaymentMethodRequest
import com.budgetbook.paymentmethod.dto.UpdatePaymentMethodRequest
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.repository.TransferRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class PaymentMethodService(
    private val paymentMethodRepository: PaymentMethodRepository,
    override val coupleResolver: CoupleResolver,
    private val transactionRepository: TransactionRepository,
    private val transferRepository: TransferRepository,
    private val syncEventPublisher: SyncEventPublisher
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun listPaymentMethods(userId: UUID): List<PaymentMethodResponse> {
        val couple = getActiveCouple(userId)
        val methods = paymentMethodRepository.findByCoupleIdOrderByDisplayOrder(couple.id)

        val balanceMap = calculateBalances(couple.id)

        return methods.map { pm ->
            val balance = if (pm.type != PaymentMethodType.CREDIT) balanceMap[pm.id] ?: 0L else null
            pm.toResponse(balance)
        }
    }

    private fun calculateBalances(coupleId: UUID): Map<UUID, Long> {
        val txNet = transactionRepository.netAmountByPaymentMethodForCouple(coupleId)
            .associate { row -> row[0] as UUID to (row[1] as Number).toLong() }

        val transferIn = transferRepository.sumAmountByDestinationForCouple(coupleId)
            .associate { row -> row[0] as UUID to (row[1] as Number).toLong() }

        val transferOut = transferRepository.sumAmountBySourceForCouple(coupleId)
            .associate { row -> row[0] as UUID to (row[1] as Number).toLong() }

        val allIds = txNet.keys + transferIn.keys + transferOut.keys
        return allIds.associateWith { id ->
            (txNet[id] ?: 0L) + (transferIn[id] ?: 0L) - (transferOut[id] ?: 0L)
        }
    }

    /**
     * asOf(배타 상한) 시점의 단일 결제수단 잔액 조회.
     * userId 로 활성 커플을 해석한 뒤 calculateBalanceAsOf 에 위임한다.
     */
    @Transactional(readOnly = true)
    fun getAssetBalance(userId: UUID, paymentMethodId: UUID, asOf: LocalDate): AssetBalanceResponse {
        val couple = getActiveCouple(userId)
        return calculateBalanceAsOf(couple.id, paymentMethodId, asOf)
    }

    /**
     * 단일 결제수단의 asOf 미만 시점 잔액을 계산한다.
     * - PM 이 커플 소유가 아니면 NotFoundException(404).
     * - CREDIT 타입은 balance = null.
     * - 그 외: txNet(asOf) + transferIn(asOf) - transferOut(asOf).
     */
    @Transactional(readOnly = true)
    fun calculateBalanceAsOf(coupleId: UUID, paymentMethodId: UUID, asOf: LocalDate): AssetBalanceResponse {
        val pm = paymentMethodRepository.findByIdAndCoupleId(paymentMethodId, coupleId)
            ?: throw NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Payment method does not exist.")

        if (pm.type == PaymentMethodType.CREDIT) {
            return AssetBalanceResponse(paymentMethodId = pm.id, asOf = asOf, balance = null)
        }

        val txNet = transactionRepository.netAmountByPaymentMethodForCoupleUpTo(coupleId, asOf)
            .associate { row -> row[0] as UUID to (row[1] as Number).toLong() }

        val transferIn = transferRepository.sumAmountByDestinationForCoupleUpTo(coupleId, asOf)
            .associate { row -> row[0] as UUID to (row[1] as Number).toLong() }

        val transferOut = transferRepository.sumAmountBySourceForCoupleUpTo(coupleId, asOf)
            .associate { row -> row[0] as UUID to (row[1] as Number).toLong() }

        val balance = (txNet[pm.id] ?: 0L) + (transferIn[pm.id] ?: 0L) - (transferOut[pm.id] ?: 0L)
        return AssetBalanceResponse(paymentMethodId = pm.id, asOf = asOf, balance = balance)
    }

    @Transactional
    fun createPaymentMethod(userId: UUID, request: CreatePaymentMethodRequest): PaymentMethodResponse {
        val couple = getActiveCouple(userId)

        val type = try {
            PaymentMethodType.valueOf(request.type)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid payment method type: ${request.type}")
        }

        if (type == PaymentMethodType.CREDIT) {
            if (request.settlementDay == null || request.closingDay == null) {
                throw BusinessException("VALIDATION_ERROR", "Credit card requires settlementDay and closingDay.")
            }
        }

        val linkedBank = resolveLinkedBank(request.linkedBankId, type, couple.id)

        val paymentMethod = PaymentMethod(
            couple = couple,
            name = request.name,
            type = type,
            settlementDay = request.settlementDay,
            closingDay = request.closingDay,
            linkedBank = linkedBank
        )

        val saved = paymentMethodRepository.save(paymentMethod)
        syncEventPublisher.publish(SyncEvent(
            type = "PAYMENT_METHOD_CREATED",
            entityType = "PAYMENT_METHOD",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse()
    }

    @Transactional
    fun updatePaymentMethod(userId: UUID, methodId: UUID, request: UpdatePaymentMethodRequest): PaymentMethodResponse {
        val couple = getActiveCouple(userId)
        val method = paymentMethodRepository.findByIdAndCoupleId(methodId, couple.id)
            ?: throw NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Payment method does not exist.")

        request.name?.let { method.name = it }
        request.settlementDay?.let { method.settlementDay = it }
        request.closingDay?.let { method.closingDay = it }
        request.isActive?.let { method.isActive = it }
        request.displayOrder?.let { method.displayOrder = it }
        request.linkedBankId?.let { bankId ->
            method.linkedBank = resolveLinkedBank(bankId, method.type, couple.id)
        }

        val saved = paymentMethodRepository.save(method)
        syncEventPublisher.publish(SyncEvent(
            type = "PAYMENT_METHOD_UPDATED",
            entityType = "PAYMENT_METHOD",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse()
    }

    @Transactional
    fun reorderPaymentMethods(userId: UUID, request: ReorderPaymentMethodRequest) {
        val couple = getActiveCouple(userId)
        val methods = paymentMethodRepository.findByCoupleIdOrderByDisplayOrder(couple.id)
        val methodMap = methods.associateBy { it.id }

        // Validate all IDs belong to this couple
        request.orderedIds.forEach { id ->
            if (!methodMap.containsKey(id)) {
                throw NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Payment method $id does not exist for this couple.")
            }
        }

        // Set displayOrder based on orderedIds position
        request.orderedIds.forEachIndexed { index, id ->
            methodMap[id]!!.displayOrder = index
        }

        paymentMethodRepository.saveAll(methods.filter { it.id in request.orderedIds })

        syncEventPublisher.publish(SyncEvent(
            type = "PAYMENT_METHOD_REORDERED",
            entityType = "PAYMENT_METHOD",
            entityId = couple.id,
            coupleId = couple.id,
            authorId = userId
        ))
    }

    @Transactional
    fun deletePaymentMethod(userId: UUID, methodId: UUID) {
        val couple = getActiveCouple(userId)
        val method = paymentMethodRepository.findByIdAndCoupleId(methodId, couple.id)
            ?: throw NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Payment method does not exist.")

        if (method.isDefault) {
            throw BusinessException("DEFAULT_METHOD_DELETE", "Cannot delete a default payment method.")
        }

        paymentMethodRepository.delete(method)
        syncEventPublisher.publish(SyncEvent(
            type = "PAYMENT_METHOD_DELETED",
            entityType = "PAYMENT_METHOD",
            entityId = methodId,
            coupleId = couple.id,
            authorId = userId
        ))
    }

    @Transactional
    fun seedDefaultPaymentMethods(couple: Couple) {
        val cash = PaymentMethod(
            couple = couple,
            name = "현금",
            type = PaymentMethodType.CASH,
            isDefault = true,
            displayOrder = 0
        )
        val debit = PaymentMethod(
            couple = couple,
            name = "체크카드",
            type = PaymentMethodType.DEBIT,
            isDefault = true,
            displayOrder = 1
        )
        paymentMethodRepository.saveAll(listOf(cash, debit))
    }

    @Transactional(readOnly = true)
    fun getCardPendingSummary(userId: UUID, year: Int, month: Int): List<CardPendingResponse> {
        val couple = getActiveCouple(userId)
        val creditCards = paymentMethodRepository.findByCoupleIdAndTypeAndIsActiveTrue(
            couple.id, PaymentMethodType.CREDIT
        )

        val yearMonth = YearMonth.of(year, month)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        return creditCards.map { card ->
            val results = transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                paymentMethodId = card.id,
                startDate = startDate,
                endDate = endDate,
                userId = userId
            )
            val totalAmount = results.firstOrNull()?.let { (it[0] as? Number)?.toLong() } ?: 0L
            val count = results.firstOrNull()?.let { (it[1] as? Number)?.toInt() } ?: 0

            CardPendingResponse(
                paymentMethod = card.toResponse(),
                pendingAmount = totalAmount,
                settlementDate = if (card.settlementDay != null) {
                    LocalDate.of(year, month, card.settlementDay!!.coerceAtMost(yearMonth.lengthOfMonth()))
                } else null,
                transactionCount = count
            )
        }
    }

    @Transactional(readOnly = true)
    fun getCardSettlementSummary(userId: UUID, year: Int? = null, month: Int? = null): CardSettlementSummaryResponse {
        val couple = getActiveCouple(userId)
        val now = if (year != null && month != null) YearMonth.of(year, month) else YearMonth.now()
        val prev = now.minusMonths(1)

        val creditCards = paymentMethodRepository.findByCoupleIdAndTypeAndIsActiveTrue(
            couple.id, PaymentMethodType.CREDIT
        )

        fun buildMonthByTransactionDate(yearMonth: YearMonth): CardSettlementMonth {
            val startDate = yearMonth.atDay(1)
            val endDate = yearMonth.atEndOfMonth()

            // Transfer OUT amounts (카드 결제 이체는 제외 — 이미 원본 거래로 계산됨, 이중 계산 방지).
            // Phase 22: kind 기반 쿼리로 전환. CARD_SETTLEMENT 제외.
            val transferOutMap = transferRepository.sumAmountBySourceByKind(
                couple.id, startDate, endDate, com.budgetbook.transfer.domain.TransferKinds.NON_CARD_SETTLEMENT
            ).associate { (it[0] as UUID) to (it[1] as Long) }

            val cards = creditCards.map { card ->
                val results = transactionRepository.sumByPaymentMethodAndTransactionDateRange(
                    paymentMethodId = card.id,
                    startDate = startDate,
                    endDate = endDate,
                    userId = userId
                )
                val txnAmount = results.firstOrNull()?.let { (it[0] as? Number)?.toLong() } ?: 0L
                val count = results.firstOrNull()?.let { (it[1] as? Number)?.toInt() } ?: 0
                val transferOut = transferOutMap[card.id] ?: 0L
                CardPendingResponse(
                    paymentMethod = card.toResponse(),
                    pendingAmount = txnAmount + transferOut,
                    settlementDate = if (card.settlementDay != null) {
                        LocalDate.of(yearMonth.year, yearMonth.month,
                            card.settlementDay!!.coerceAtMost(yearMonth.lengthOfMonth()))
                    } else null,
                    transactionCount = count
                )
            }
            return CardSettlementMonth(
                year = yearMonth.year,
                month = yearMonth.monthValue,
                totalAmount = cards.sumOf { it.pendingAmount },
                cards = cards
            )
        }

        fun buildMonthBySettlementDate(yearMonth: YearMonth): CardSettlementMonth {
            val startDate = yearMonth.atDay(1)
            val endDate = yearMonth.atEndOfMonth()

            // 미결제는 '해당 월에 결제할 카드 청구액' — Transaction만 집계.
            // 신용카드는 source로 이체가 불가능하고 Transfer(source=card)는 실제로 존재하지 않음.
            // 설령 있더라도 카드 청구와 무관하므로 미결제에 포함 안 함.
            val cards = creditCards.map { card ->
                val results = transactionRepository.sumByPaymentMethodAndSettlementDateRange(
                    paymentMethodId = card.id,
                    startDate = startDate,
                    endDate = endDate,
                    userId = userId
                )
                val txnAmount = results.firstOrNull()?.let { (it[0] as? Number)?.toLong() } ?: 0L
                val count = results.firstOrNull()?.let { (it[1] as? Number)?.toInt() } ?: 0
                CardPendingResponse(
                    paymentMethod = card.toResponse(),
                    pendingAmount = txnAmount,
                    settlementDate = if (card.settlementDay != null) {
                        LocalDate.of(yearMonth.year, yearMonth.month,
                            card.settlementDay!!.coerceAtMost(yearMonth.lengthOfMonth()))
                    } else null,
                    transactionCount = count
                )
            }
            return CardSettlementMonth(
                year = yearMonth.year,
                month = yearMonth.monthValue,
                totalAmount = cards.sumOf { it.pendingAmount },
                cards = cards
            )
        }

        return CardSettlementSummaryResponse(
            previousMonth = buildMonthByTransactionDate(prev),
            currentMonth = buildMonthByTransactionDate(now),
            unpaidMonth = buildMonthBySettlementDate(now)
        )
    }

    private fun resolveLinkedBank(linkedBankId: UUID?, type: PaymentMethodType, coupleId: UUID): PaymentMethod? {
        if (linkedBankId == null) return null
        if (type != PaymentMethodType.CREDIT) {
            throw BusinessException("VALIDATION_ERROR", "linkedBankId는 카드(CREDIT) 결제수단에만 설정할 수 있습니다.")
        }
        val bank = paymentMethodRepository.findByIdAndCoupleId(linkedBankId, coupleId)
            ?: throw NotFoundException("PAYMENT_METHOD_NOT_FOUND", "연결 은행 결제수단을 찾을 수 없습니다.")
        if (bank.type != PaymentMethodType.BANK) {
            throw BusinessException("VALIDATION_ERROR", "linkedBankId는 BANK 타입의 결제수단이어야 합니다.")
        }
        return bank
    }

    private fun PaymentMethod.toResponse(balance: Long? = null) = PaymentMethodResponse(
        id = id,
        name = name,
        type = type.name,
        settlementDay = settlementDay,
        closingDay = closingDay,
        isActive = isActive,
        isDefault = isDefault,
        displayOrder = displayOrder,
        balance = balance,
        linkedBankId = linkedBank?.id,
        linkedBankName = linkedBank?.name,
        createdAt = createdAt
    )
}
