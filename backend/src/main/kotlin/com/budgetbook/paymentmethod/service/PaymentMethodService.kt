package com.budgetbook.paymentmethod.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.dto.CardPendingResponse
import com.budgetbook.paymentmethod.dto.CreatePaymentMethodRequest
import com.budgetbook.paymentmethod.dto.PaymentMethodResponse
import com.budgetbook.paymentmethod.dto.UpdatePaymentMethodRequest
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class PaymentMethodService(
    private val paymentMethodRepository: PaymentMethodRepository,
    private val coupleResolver: CoupleResolver,
    private val transactionRepository: TransactionRepository,
    private val syncEventPublisher: SyncEventPublisher
) {

    @Transactional(readOnly = true)
    fun listPaymentMethods(userId: UUID): List<PaymentMethodResponse> {
        val couple = getActiveCouple(userId)
        return paymentMethodRepository.findByCoupleIdOrderByDisplayOrder(couple.id)
            .map { it.toResponse() }
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

        val paymentMethod = PaymentMethod(
            couple = couple,
            name = request.name,
            type = type,
            settlementDay = request.settlementDay,
            closingDay = request.closingDay
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
                endDate = endDate
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

    private fun getActiveCouple(userId: UUID): Couple {
        return coupleResolver.getActiveCouple(userId)
    }

    private fun PaymentMethod.toResponse() = PaymentMethodResponse(
        id = id,
        name = name,
        type = type.name,
        settlementDay = settlementDay,
        closingDay = closingDay,
        isActive = isActive,
        isDefault = isDefault,
        displayOrder = displayOrder,
        createdAt = createdAt
    )
}
