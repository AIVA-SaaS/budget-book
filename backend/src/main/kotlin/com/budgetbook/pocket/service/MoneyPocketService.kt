package com.budgetbook.pocket.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
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
import com.budgetbook.transaction.service.TransactionService
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.util.UUID

@Service
class MoneyPocketService(
    private val moneyPocketRepository: MoneyPocketRepository,
    override val coupleResolver: CoupleResolver,
    private val syncEventPublisher: SyncEventPublisher,
    private val pocketTransferRepository: PocketTransferRepository,
    private val transactionRepository: TransactionRepository,
    private val userRepository: UserRepository
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun getPockets(userId: UUID): List<PocketResponse> {
        val couple = getActiveCouple(userId)
        val pockets = moneyPocketRepository.findByCoupleIdAndIsActiveTrueAndUserId(couple.id, userId)

        if (pockets.isEmpty()) return emptyList()

        val pocketIds = pockets.map { it.id }.toSet()

        // Batch queries for balance calculation
        val transfersInMap = pocketTransferRepository.sumAmountByToPocketIdIn(pocketIds)
            .associate { (it[0] as UUID) to (it[1] as Long) }
        val transfersOutMap = pocketTransferRepository.sumAmountByFromPocketIdIn(pocketIds)
            .associate { (it[0] as UUID) to (it[1] as Long) }
        val expensesMap = transactionRepository.sumExpenseByPocketIdIn(pocketIds, userId)
            .associate { (it[0] as UUID) to (it[1] as Long) }

        return pockets.map { pocket ->
            val transfersIn = transfersInMap[pocket.id] ?: 0L
            val transfersOut = transfersOutMap[pocket.id] ?: 0L
            val expenses = expensesMap[pocket.id] ?: 0L
            val balance = pocket.allocatedAmount + transfersIn - transfersOut - expenses
            pocket.toResponse(balance)
        }
    }

    @Transactional
    fun createPocket(userId: UUID, request: CreatePocketRequest): PocketResponse {
        val couple = getActiveCouple(userId)

        val pocketType = try {
            PocketType.valueOf(request.type)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid pocket type: ${request.type}")
        }

        val visibility = TransactionService.parseVisibility(request.visibility)
        val maxOrder = moneyPocketRepository.maxDisplayOrderByCoupleId(couple.id)

        val owner = if (visibility == Visibility.PRIVATE) {
            userRepository.findById(userId)
                .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
        } else null

        val pocket = MoneyPocket(
            couple = couple,
            name = request.name,
            type = pocketType,
            allocatedAmount = request.allocatedAmount,
            icon = request.icon,
            color = request.color,
            displayOrder = maxOrder + 1,
            goalAmount = request.goalAmount,
            targetDate = request.targetDate,
            visibility = visibility,
            owner = owner
        )

        val saved = moneyPocketRepository.save(pocket)
        syncEventPublisher.publish(SyncEvent(
            type = "POCKET_CREATED",
            entityType = "POCKET",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse(calculateBalance(saved, userId))
    }

    @Transactional
    fun updatePocket(userId: UUID, pocketId: UUID, request: UpdatePocketRequest): PocketResponse {
        val couple = getActiveCouple(userId)
        val pocket = moneyPocketRepository.findByIdAndCoupleId(pocketId, couple.id)
            ?: throw NotFoundException("POCKET_NOT_FOUND", "Pocket does not exist.")

        if (!pocket.isActive) {
            throw NotFoundException("POCKET_NOT_FOUND", "Pocket does not exist.")
        }

        OwnershipValidator.validateOwnership(pocket.couple.id, couple, "Pocket")
        validatePrivateOwner(pocket, userId)

        request.name?.let { pocket.name = it }
        request.allocatedAmount?.let { pocket.allocatedAmount = it }
        request.icon?.let { pocket.icon = it }
        request.color?.let { pocket.color = it }
        request.displayOrder?.let { pocket.displayOrder = it }
        request.goalAmount?.let { pocket.goalAmount = it }
        request.targetDate?.let { pocket.targetDate = it }

        // Handle visibility change
        request.visibility?.let { visStr ->
            val newVisibility = TransactionService.parseVisibility(visStr)
            pocket.visibility = newVisibility
            if (newVisibility == Visibility.PRIVATE) {
                val user = userRepository.findById(userId)
                    .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
                pocket.owner = user
            } else {
                pocket.owner = null
            }
        }

        val saved = moneyPocketRepository.save(pocket)
        syncEventPublisher.publish(SyncEvent(
            type = "POCKET_UPDATED",
            entityType = "POCKET",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse(calculateBalance(saved, userId))
    }

    @Transactional
    fun deletePocket(userId: UUID, pocketId: UUID) {
        val couple = getActiveCouple(userId)
        val pocket = moneyPocketRepository.findByIdAndCoupleId(pocketId, couple.id)
            ?: throw NotFoundException("POCKET_NOT_FOUND", "Pocket does not exist.")

        if (!pocket.isActive) {
            throw NotFoundException("POCKET_NOT_FOUND", "Pocket does not exist.")
        }

        validatePrivateOwner(pocket, userId)

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

    internal fun calculateBalance(pocket: MoneyPocket, userId: UUID): Long {
        val transfersIn = pocketTransferRepository.sumAmountByToPocketId(pocket.id)
        val transfersOut = pocketTransferRepository.sumAmountByFromPocketId(pocket.id)
        val expenses = transactionRepository.sumExpenseByPocketId(pocket.id, userId)
        return pocket.allocatedAmount + transfersIn - transfersOut - expenses
    }

    private fun validatePrivateOwner(pocket: MoneyPocket, userId: UUID) {
        if (pocket.visibility == Visibility.PRIVATE && pocket.owner?.id != null && pocket.owner?.id != userId) {
            throw ForbiddenException("FORBIDDEN", "Only the owner can modify a private pocket.")
        }
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
        visibility = visibility.name,
        ownerId = owner?.id,
        createdAt = createdAt,
        updatedAt = updatedAt
    )
}
