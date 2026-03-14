package com.budgetbook.pocket.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.pocket.domain.MoneyPocket
import com.budgetbook.pocket.domain.PocketType
import com.budgetbook.pocket.dto.CreatePocketRequest
import com.budgetbook.pocket.dto.PocketResponse
import com.budgetbook.pocket.dto.UpdatePocketRequest
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.pocket.repository.PocketTransferRepository
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.util.UUID

@Service
class MoneyPocketService(
    private val moneyPocketRepository: MoneyPocketRepository,
    private val coupleRepository: CoupleRepository,
    private val syncEventPublisher: SyncEventPublisher,
    private val pocketTransferRepository: PocketTransferRepository,
    private val transactionRepository: TransactionRepository
) {

    @Transactional(readOnly = true)
    fun getPockets(userId: UUID): List<PocketResponse> {
        val couple = getActiveCouple(userId)
        val pockets = moneyPocketRepository.findByCoupleIdAndIsActiveTrue(couple.id)
        return pockets.map { it.toResponse(calculateBalance(it)) }
    }

    @Transactional
    fun createPocket(userId: UUID, request: CreatePocketRequest): PocketResponse {
        val couple = getActiveCouple(userId)

        val pocketType = try {
            PocketType.valueOf(request.type)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid pocket type: ${request.type}")
        }

        val maxOrder = moneyPocketRepository.maxDisplayOrderByCoupleId(couple.id)

        val pocket = MoneyPocket(
            couple = couple,
            name = request.name,
            type = pocketType,
            allocatedAmount = request.allocatedAmount,
            icon = request.icon,
            color = request.color,
            displayOrder = maxOrder + 1,
            goalAmount = request.goalAmount,
            targetDate = request.targetDate
        )

        val saved = moneyPocketRepository.save(pocket)
        syncEventPublisher.publish(SyncEvent(
            type = "POCKET_CREATED",
            entityType = "POCKET",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse(calculateBalance(saved))
    }

    @Transactional
    fun updatePocket(userId: UUID, pocketId: UUID, request: UpdatePocketRequest): PocketResponse {
        val couple = getActiveCouple(userId)
        val pocket = moneyPocketRepository.findByIdAndCoupleId(pocketId, couple.id)
            ?: throw NotFoundException("POCKET_NOT_FOUND", "Pocket does not exist.")

        if (!pocket.isActive) {
            throw NotFoundException("POCKET_NOT_FOUND", "Pocket does not exist.")
        }

        if (pocket.couple.id != couple.id) {
            throw ForbiddenException("FORBIDDEN", "Pocket belongs to a different couple.")
        }

        request.name?.let { pocket.name = it }
        request.allocatedAmount?.let { pocket.allocatedAmount = it }
        request.icon?.let { pocket.icon = it }
        request.color?.let { pocket.color = it }
        request.displayOrder?.let { pocket.displayOrder = it }
        request.goalAmount?.let { pocket.goalAmount = it }
        request.targetDate?.let { pocket.targetDate = it }

        val saved = moneyPocketRepository.save(pocket)
        syncEventPublisher.publish(SyncEvent(
            type = "POCKET_UPDATED",
            entityType = "POCKET",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse(calculateBalance(saved))
    }

    @Transactional
    fun deletePocket(userId: UUID, pocketId: UUID) {
        val couple = getActiveCouple(userId)
        val pocket = moneyPocketRepository.findByIdAndCoupleId(pocketId, couple.id)
            ?: throw NotFoundException("POCKET_NOT_FOUND", "Pocket does not exist.")

        if (!pocket.isActive) {
            throw NotFoundException("POCKET_NOT_FOUND", "Pocket does not exist.")
        }

        pocket.isActive = false
        moneyPocketRepository.save(pocket)
        syncEventPublisher.publish(SyncEvent(
            type = "POCKET_DELETED",
            entityType = "POCKET",
            entityId = pocketId,
            coupleId = couple.id,
            authorId = userId
        ))
    }

    @Transactional
    fun seedDefaultPockets(couple: Couple): List<MoneyPocket> {
        val defaults = listOf(
            Triple("생활비", PocketType.LIVING, "wallet"),
            Triple("고정지출", PocketType.FIXED, "receipt_long"),
            Triple("카드대기", PocketType.CARD_PENDING, "credit_card"),
            Triple("저축", PocketType.SAVINGS, "savings")
        )

        return defaults.mapIndexed { index, (name, type, icon) ->
            moneyPocketRepository.save(
                MoneyPocket(
                    couple = couple,
                    name = name,
                    type = type,
                    icon = icon,
                    displayOrder = index + 1
                )
            )
        }
    }

    internal fun calculateBalance(pocket: MoneyPocket): Long {
        val transfersIn = pocketTransferRepository.sumAmountByToPocketId(pocket.id)
        val transfersOut = pocketTransferRepository.sumAmountByFromPocketId(pocket.id)
        val expenses = transactionRepository.sumExpenseByPocketId(pocket.id)
        return pocket.allocatedAmount + transfersIn - transfersOut - expenses
    }

    internal fun getActiveCouple(userId: UUID): Couple {
        return coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
            ?: throw NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")
    }

    private fun MoneyPocket.toResponse(balance: Long) = PocketResponse(
        id = id,
        name = name,
        type = type.name,
        allocatedAmount = allocatedAmount,
        balance = balance,
        icon = icon,
        color = color,
        displayOrder = displayOrder,
        isActive = isActive,
        goalAmount = goalAmount,
        targetDate = targetDate,
        createdAt = createdAt,
        updatedAt = updatedAt
    )
}
