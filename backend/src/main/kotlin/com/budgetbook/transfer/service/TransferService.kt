package com.budgetbook.transfer.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transfer.domain.Transfer
import com.budgetbook.transfer.dto.CreateTransferRequest
import com.budgetbook.transfer.dto.PaymentMethodSummary
import com.budgetbook.transfer.dto.TransferResponse
import com.budgetbook.transfer.dto.UpdateTransferRequest
import com.budgetbook.transfer.repository.TransferRepository
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class TransferService(
    private val transferRepository: TransferRepository,
    override val coupleResolver: CoupleResolver,
    private val userRepository: UserRepository,
    private val paymentMethodRepository: PaymentMethodRepository,
    private val syncEventPublisher: SyncEventPublisher,
    private val transactionRepository: TransactionRepository
) : CoupleAwareService {

    @Transactional
    fun createTransfer(userId: UUID, request: CreateTransferRequest): TransferResponse {
        if (request.sourcePaymentMethodId == request.destinationPaymentMethodId) {
            throw BusinessException("VALIDATION_ERROR", "Source and destination payment methods must be different.")
        }

        val couple = getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val source = paymentMethodRepository.findById(request.sourcePaymentMethodId)
            .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Source payment method does not exist.") }
        OwnershipValidator.validateOwnership(source.couple.id, couple, "Payment method")

        val destination = paymentMethodRepository.findById(request.destinationPaymentMethodId)
            .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Destination payment method does not exist.") }
        OwnershipValidator.validateOwnership(destination.couple.id, couple, "Payment method")

        validateNotCreditToCredit(source.type, destination.type)

        val transfer = Transfer(
            couple = couple,
            author = user,
            sourcePaymentMethod = source,
            destinationPaymentMethod = destination,
            amount = request.amount,
            description = request.description,
            memo = request.memo,
            transferDate = request.transferDate
        )

        val saved = transferRepository.save(transfer)
        syncEventPublisher.publish(SyncEvent(
            type = "TRANSFER_CREATED",
            entityType = "TRANSFER",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse()
    }

    @Transactional(readOnly = true)
    fun listTransfers(userId: UUID, year: Int, month: Int): List<TransferResponse> {
        val couple = getActiveCouple(userId)
        val yearMonth = YearMonth.of(year, month)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        return transferRepository.findByCoupleIdAndTransferDateBetweenOrderByTransferDateDesc(
            couple.id, startDate, endDate
        ).map { it.toResponse() }
    }

    @Transactional(readOnly = true)
    fun getTransfer(userId: UUID, transferId: UUID): TransferResponse {
        val couple = getActiveCouple(userId)
        val transfer = transferRepository.findByIdAndCoupleId(transferId, couple.id)
            ?: throw NotFoundException("TRANSFER_NOT_FOUND", "Transfer does not exist.")
        return transfer.toResponse()
    }

    @Transactional
    fun updateTransfer(userId: UUID, transferId: UUID, request: UpdateTransferRequest): TransferResponse {
        val couple = getActiveCouple(userId)
        val transfer = transferRepository.findByIdAndCoupleId(transferId, couple.id)
            ?: throw NotFoundException("TRANSFER_NOT_FOUND", "Transfer does not exist.")

        request.amount?.let { transfer.amount = it }
        request.transferDate?.let { transfer.transferDate = it }
        request.description?.let { transfer.description = it.value }
        request.memo?.let { transfer.memo = it.value }

        request.sourcePaymentMethodId?.let { patchValue ->
            val pmId = patchValue.value
                ?: throw BusinessException("VALIDATION_ERROR", "Source payment method ID cannot be null.")
            val pm = paymentMethodRepository.findById(pmId)
                .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Source payment method does not exist.") }
            OwnershipValidator.validateOwnership(pm.couple.id, couple, "Payment method")
            transfer.sourcePaymentMethod = pm
        }

        request.destinationPaymentMethodId?.let { patchValue ->
            val pmId = patchValue.value
                ?: throw BusinessException("VALIDATION_ERROR", "Destination payment method ID cannot be null.")
            val pm = paymentMethodRepository.findById(pmId)
                .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Destination payment method does not exist.") }
            OwnershipValidator.validateOwnership(pm.couple.id, couple, "Payment method")
            transfer.destinationPaymentMethod = pm
        }

        if (transfer.sourcePaymentMethod.id == transfer.destinationPaymentMethod.id) {
            throw BusinessException("VALIDATION_ERROR", "Source and destination payment methods must be different.")
        }

        validateNotCreditToCredit(transfer.sourcePaymentMethod.type, transfer.destinationPaymentMethod.type)

        val saved = transferRepository.save(transfer)
        syncEventPublisher.publish(SyncEvent(
            type = "TRANSFER_UPDATED",
            entityType = "TRANSFER",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse()
    }

    @Transactional
    fun deleteTransfer(userId: UUID, transferId: UUID) {
        val couple = getActiveCouple(userId)
        val transfer = transferRepository.findByIdAndCoupleId(transferId, couple.id)
            ?: throw NotFoundException("TRANSFER_NOT_FOUND", "Transfer does not exist.")

        transferRepository.delete(transfer)
        syncEventPublisher.publish(SyncEvent(
            type = "TRANSFER_DELETED",
            entityType = "TRANSFER",
            entityId = transferId,
            coupleId = couple.id,
            authorId = userId
        ))
    }

    @Transactional
    fun createTransferInternal(
        authorId: UUID,
        couple: com.budgetbook.couple.domain.Couple,
        source: com.budgetbook.paymentmethod.domain.PaymentMethod,
        destination: com.budgetbook.paymentmethod.domain.PaymentMethod,
        amount: Long,
        description: String?,
        transferDate: java.time.LocalDate,
        autoSettlementKey: String? = null
    ): Transfer {
        val author = userRepository.findById(authorId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "System user not found.") }

        val transfer = Transfer(
            couple = couple,
            author = author,
            sourcePaymentMethod = source,
            destinationPaymentMethod = destination,
            amount = amount,
            description = description,
            transferDate = transferDate,
            autoSettlementKey = autoSettlementKey
        )

        val saved = transferRepository.save(transfer)
        syncEventPublisher.publish(SyncEvent(
            type = "TRANSFER_CREATED",
            entityType = "TRANSFER",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = authorId
        ))
        return saved
    }

    /**
     * 카드 결제 처리 (구조적 수정):
     * 1. is_card_settlement=true 인 Transfer 생성 (통계 이중 계산 방지)
     * 2. 선택된 transactionIds의 paid_at을 결제일로 일괄 업데이트 (미결제 목록에서 제외)
     *
     * 한 트랜잭션 내에서 처리되어 원자성 보장.
     */
    @Transactional
    fun createCardSettlement(
        userId: UUID,
        sourcePaymentMethodId: UUID,
        destinationPaymentMethodId: UUID,
        amount: Long,
        transferDate: LocalDate,
        description: String?,
        transactionIds: List<UUID>
    ): TransferResponse {
        if (sourcePaymentMethodId == destinationPaymentMethodId) {
            throw BusinessException("VALIDATION_ERROR", "Source and destination payment methods must be different.")
        }

        val couple = getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val source = paymentMethodRepository.findById(sourcePaymentMethodId)
            .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Source payment method does not exist.") }
        OwnershipValidator.validateOwnership(source.couple.id, couple, "Payment method")

        val destination = paymentMethodRepository.findById(destinationPaymentMethodId)
            .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Destination payment method does not exist.") }
        OwnershipValidator.validateOwnership(destination.couple.id, couple, "Payment method")

        // 카드 결제는 반드시 destination이 CREDIT 카드여야 함
        if (destination.type != PaymentMethodType.CREDIT) {
            throw BusinessException("VALIDATION_ERROR", "카드 결제는 destination이 CREDIT 타입이어야 합니다.")
        }

        // 1. Transfer 생성 (is_card_settlement=true)
        val transfer = Transfer(
            couple = couple,
            author = user,
            sourcePaymentMethod = source,
            destinationPaymentMethod = destination,
            amount = amount,
            description = description ?: "카드 결제",
            transferDate = transferDate,
            isCardSettlement = true
        )
        val saved = transferRepository.save(transfer)

        // 2. 선택된 거래들의 paid_at 업데이트 (미결제 목록에서 제외)
        if (transactionIds.isNotEmpty()) {
            transactionRepository.markAsPaid(transactionIds, transferDate)
        }

        syncEventPublisher.publish(SyncEvent(
            type = "CARD_SETTLEMENT_CREATED",
            entityType = "TRANSFER",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse()
    }

    private fun validateNotCreditToCredit(sourceType: PaymentMethodType, destType: PaymentMethodType) {
        if (sourceType == PaymentMethodType.CREDIT && destType == PaymentMethodType.CREDIT) {
            throw BusinessException("TRANSFER_CREDIT_TO_CREDIT_NOT_ALLOWED", "카드 간 이체는 불가합니다")
        }
    }

    private fun Transfer.toResponse() = TransferResponse(
        id = id,
        coupleId = couple.id,
        author = UserSummary(
            id = author.id,
            nickname = author.nickname,
            profileImageUrl = author.profileImageUrl
        ),
        sourcePaymentMethod = PaymentMethodSummary(
            id = sourcePaymentMethod.id,
            name = sourcePaymentMethod.name,
            type = sourcePaymentMethod.type.name
        ),
        destinationPaymentMethod = PaymentMethodSummary(
            id = destinationPaymentMethod.id,
            name = destinationPaymentMethod.name,
            type = destinationPaymentMethod.type.name
        ),
        amount = amount,
        description = description,
        memo = memo,
        transferDate = transferDate,
        createdAt = createdAt
    )
}
