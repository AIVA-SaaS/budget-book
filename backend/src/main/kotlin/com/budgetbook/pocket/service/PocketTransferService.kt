package com.budgetbook.pocket.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.pocket.domain.PocketTransfer
import com.budgetbook.pocket.dto.CreateTransferRequest
import com.budgetbook.pocket.dto.DistributeRequest
import com.budgetbook.pocket.dto.DistributeResponse
import com.budgetbook.pocket.dto.DistributionResult
import com.budgetbook.pocket.dto.PocketSummary
import com.budgetbook.pocket.dto.PocketTransferResponse
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.pocket.repository.PocketTransferRepository
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class PocketTransferService(
    private val pocketTransferRepository: PocketTransferRepository,
    private val moneyPocketRepository: MoneyPocketRepository,
    override val coupleResolver: CoupleResolver,
    private val userRepository: UserRepository,
    private val syncEventPublisher: SyncEventPublisher
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun getTransfers(userId: UUID): List<PocketTransferResponse> {
        val couple = getActiveCouple(userId)
        val transfers = pocketTransferRepository.findByCoupleId(couple.id)
        return transfers.map { it.toResponse() }
    }

    @Transactional
    fun createTransfer(userId: UUID, request: CreateTransferRequest): PocketTransferResponse {
        val couple = getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        if (request.fromPocketId == request.toPocketId) {
            throw BusinessException("VALIDATION_ERROR", "Cannot transfer to the same pocket.")
        }

        val fromPocket = moneyPocketRepository.findByIdAndCoupleId(request.fromPocketId, couple.id)
            ?: throw NotFoundException("POCKET_NOT_FOUND", "Source pocket does not exist.")
        if (!fromPocket.isActive) {
            throw NotFoundException("POCKET_NOT_FOUND", "Source pocket does not exist.")
        }

        val toPocket = moneyPocketRepository.findByIdAndCoupleId(request.toPocketId, couple.id)
            ?: throw NotFoundException("POCKET_NOT_FOUND", "Destination pocket does not exist.")
        if (!toPocket.isActive) {
            throw NotFoundException("POCKET_NOT_FOUND", "Destination pocket does not exist.")
        }

        val transfer = PocketTransfer(
            couple = couple,
            fromPocket = fromPocket,
            toPocket = toPocket,
            amount = request.amount,
            description = request.description,
            transferDate = request.transferDate,
            author = user
        )

        val saved = pocketTransferRepository.save(transfer)
        syncEventPublisher.publish(SyncEvent(
            type = "POCKET_TRANSFER_CREATED",
            entityType = "POCKET_TRANSFER",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        return saved.toResponse()
    }

    @Transactional
    fun distribute(userId: UUID, request: DistributeRequest): DistributeResponse {
        val couple = getActiveCouple(userId)

        val distributionSum = request.distributions.sumOf { it.amount }
        if (distributionSum != request.totalAmount) {
            throw BusinessException("VALIDATION_ERROR",
                "Sum of distributions ($distributionSum) does not match totalAmount (${request.totalAmount}).")
        }

        val results = request.distributions.map { item ->
            val pocket = moneyPocketRepository.findByIdAndCoupleId(item.pocketId, couple.id)
                ?: throw NotFoundException("POCKET_NOT_FOUND", "Pocket ${item.pocketId} does not exist.")
            if (!pocket.isActive) {
                throw NotFoundException("POCKET_NOT_FOUND", "Pocket ${item.pocketId} is not active.")
            }

            pocket.allocatedAmount += item.amount
            moneyPocketRepository.save(pocket)

            DistributionResult(
                pocketId = pocket.id,
                pocketName = pocket.name,
                amount = item.amount
            )
        }

        syncEventPublisher.publish(SyncEvent(
            type = "POCKET_DISTRIBUTED",
            entityType = "POCKET",
            entityId = couple.id,
            coupleId = couple.id,
            authorId = userId
        ))

        return DistributeResponse(
            distributions = results,
            totalDistributed = distributionSum
        )
    }

    private fun PocketTransfer.toResponse() = PocketTransferResponse(
        id = id,
        fromPocket = PocketSummary(id = fromPocket.id, name = fromPocket.name),
        toPocket = PocketSummary(id = toPocket.id, name = toPocket.name),
        amount = amount,
        description = description,
        transferDate = transferDate,
        authorId = author.id,
        createdAt = createdAt,
        updatedAt = updatedAt
    )
}
