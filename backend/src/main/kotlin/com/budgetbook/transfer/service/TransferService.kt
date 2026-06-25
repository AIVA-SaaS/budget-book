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
import com.budgetbook.transfer.domain.TransferKind
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
@Suppress("DEPRECATION") // Transfer.isCardSettlement 는 V55 까지 유지.
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

        // Phase 22: TransferKind 자동 판정. 사용자 명시 값이 있으면 우선.
        val resolvedKind = request.kind ?: resolveDefaultKind(source.type, destination.type)

        val transfer = Transfer(
            couple = couple,
            author = user,
            sourcePaymentMethod = source,
            destinationPaymentMethod = destination,
            amount = request.amount,
            description = request.description,
            memo = request.memo,
            transferDate = request.transferDate,
            kind = resolvedKind,
            isCardSettlement = resolvedKind == TransferKind.CARD_SETTLEMENT
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

        // V63: 카드 정산은 paid_at 재조정이 필요하므로 일반 수정 경로로 변경할 수 없다.
        // 전용 편집 엔드포인트(updateCardSettlement)를 사용해야 한다.
        if (transfer.kind == TransferKind.CARD_SETTLEMENT) {
            throw BusinessException(
                "CARD_SETTLEMENT_EDIT_NOT_ALLOWED",
                "카드 정산은 정산 편집 화면에서 수정하세요."
            )
        }

        request.amount?.let { transfer.amount = it }
        request.transferDate?.let { transfer.transferDate = it }
        request.description?.let { patchValue ->
            // Mirror create-side @Size(max=255); PatchValue wrapper bypasses Bean Validation.
            patchValue.value?.let { desc ->
                if (desc.length > 255) {
                    throw BusinessException("VALIDATION_ERROR", "description must be 255 characters or less.")
                }
            }
            transfer.description = patchValue.value
        }
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

        // Phase 22: kind 변경 반영. PatchValue<TransferKind> 는 null 값을 허용하지 않음.
        request.kind?.let { patchValue ->
            val newKind = patchValue.value
                ?: throw BusinessException("VALIDATION_ERROR", "Transfer kind cannot be null.")
            transfer.kind = newKind
            transfer.isCardSettlement = newKind == TransferKind.CARD_SETTLEMENT
        }

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

        // V63: 카드 정산 삭제 시 연결된 거래의 paid_at 을 복원 (미결제 목록에 다시 포함).
        // FK 의 ON DELETE SET NULL 만으로는 paid_at 이 복원되지 않으므로 먼저 unmark 한다.
        if (transfer.kind == TransferKind.CARD_SETTLEMENT) {
            transactionRepository.unmarkBySettlementTransfer(transferId)
        }

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

        val resolvedKind = resolveDefaultKind(source.type, destination.type)

        val transfer = Transfer(
            couple = couple,
            author = author,
            sourcePaymentMethod = source,
            destinationPaymentMethod = destination,
            amount = amount,
            description = description,
            transferDate = transferDate,
            autoSettlementKey = autoSettlementKey,
            kind = resolvedKind,
            isCardSettlement = resolvedKind == TransferKind.CARD_SETTLEMENT
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
     * 1. kind=CARD_SETTLEMENT 인 Transfer 생성 (통계 이중 계산 방지)
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

        // 1. Transfer 생성 (kind=CARD_SETTLEMENT)
        val transfer = Transfer(
            couple = couple,
            author = user,
            sourcePaymentMethod = source,
            destinationPaymentMethod = destination,
            amount = amount,
            description = description ?: "카드 결제",
            transferDate = transferDate,
            kind = TransferKind.CARD_SETTLEMENT,
            isCardSettlement = true
        )
        val saved = transferRepository.save(transfer)

        // 2. 선택된 거래들의 paid_at 업데이트 + 정산 이체 링크 저장 (미결제 목록에서 제외).
        //    V63: 링크를 저장해야 정산 수정/삭제 시 paid_at 을 양방향 재조정할 수 있다.
        if (transactionIds.isNotEmpty()) {
            transactionRepository.markAsPaidForSettlement(transactionIds, transferDate, saved.id)
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

    /**
     * 카드 정산 편집 (V63):
     * 1. 정산 이체 조회 + 소유권 검증 + kind==CARD_SETTLEMENT 확인.
     * 2. 기존 링크 거래들의 paid_at 복원 (unmark).
     * 3. source/destination 검증 + 이체 필드 갱신.
     * 4. 새로 선택된 거래들을 paid 로 마킹 + 링크 저장.
     *
     * 한 트랜잭션 내에서 처리되어 원자성 보장. 미결제 합계가 새 선택 기준으로 재계산된다.
     */
    @Transactional
    fun updateCardSettlement(
        userId: UUID,
        transferId: UUID,
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
        val transfer = transferRepository.findByIdAndCoupleId(transferId, couple.id)
            ?: throw NotFoundException("TRANSFER_NOT_FOUND", "Transfer does not exist.")

        if (transfer.kind != TransferKind.CARD_SETTLEMENT) {
            throw BusinessException(
                "NOT_A_CARD_SETTLEMENT",
                "이 이체는 카드 정산이 아닙니다."
            )
        }

        val source = paymentMethodRepository.findById(sourcePaymentMethodId)
            .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Source payment method does not exist.") }
        OwnershipValidator.validateOwnership(source.couple.id, couple, "Payment method")

        val destination = paymentMethodRepository.findById(destinationPaymentMethodId)
            .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Destination payment method does not exist.") }
        OwnershipValidator.validateOwnership(destination.couple.id, couple, "Payment method")

        // 카드 결제는 반드시 destination이 CREDIT 카드여야 함 (생성과 동일).
        if (destination.type != PaymentMethodType.CREDIT) {
            throw BusinessException("VALIDATION_ERROR", "카드 결제는 destination이 CREDIT 타입이어야 합니다.")
        }
        validateNotCreditToCredit(source.type, destination.type)

        // 1. 기존 링크 거래 미결제 복원.
        transactionRepository.unmarkBySettlementTransfer(transferId)

        // 2. 이체 필드 갱신.
        transfer.sourcePaymentMethod = source
        transfer.destinationPaymentMethod = destination
        transfer.amount = amount
        transfer.transferDate = transferDate
        transfer.description = description ?: "카드 결제"
        val saved = transferRepository.save(transfer)

        // 3. 새로 선택된 거래 마킹 + 링크 저장.
        if (transactionIds.isNotEmpty()) {
            transactionRepository.markAsPaidForSettlement(transactionIds, transferDate, saved.id)
        }

        syncEventPublisher.publish(SyncEvent(
            type = "CARD_SETTLEMENT_UPDATED",
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

    /**
     * Phase 22 §2.1 — TransferKind 자동 판정.
     *
     * 규칙:
     * - BANK → CREDIT: 카드 결제 흐름 (CARD_SETTLEMENT 기본)
     * - CREDIT → CREDIT: 금지 (이 메서드 호출 전에 [validateNotCreditToCredit] 에서 차단됨)
     * - 나머지(CREDIT→BANK, BANK↔BANK, CASH↔BANK 등): GENERIC
     *
     * EXPENSE_TRANSFER / INCOME_TRANSFER 는 의미상 자동 판정 불가능 — 사용자가 명시적으로
     * 지정해야 함(요청 본문의 `kind` 필드). 즉 이 함수는 EXPENSE/INCOME_TRANSFER 를 리턴하지 않는다.
     */
    internal fun resolveDefaultKind(sourceType: PaymentMethodType, destType: PaymentMethodType): TransferKind = when {
        sourceType == PaymentMethodType.BANK && destType == PaymentMethodType.CREDIT -> TransferKind.CARD_SETTLEMENT
        else -> TransferKind.GENERIC
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
        kind = kind,
        createdAt = createdAt
    )
}
