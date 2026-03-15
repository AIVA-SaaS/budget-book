package com.budgetbook.pocket.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.pocket.domain.DistributionRatio
import com.budgetbook.pocket.dto.DistributionRatioResponse
import com.budgetbook.pocket.dto.SaveDistributionRatiosRequest
import com.budgetbook.pocket.repository.DistributionRatioRepository
import com.budgetbook.pocket.repository.MoneyPocketRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal
import java.util.UUID

@Service
class DistributionRatioService(
    private val distributionRatioRepository: DistributionRatioRepository,
    private val moneyPocketRepository: MoneyPocketRepository,
    private val coupleResolver: CoupleResolver
) {

    @Transactional(readOnly = true)
    fun getRatios(userId: UUID): List<DistributionRatioResponse> {
        val couple = getActiveCouple(userId)
        val ratios = distributionRatioRepository.findByCoupleId(couple.id)
        return ratios.map {
            DistributionRatioResponse(
                pocketId = it.pocket.id,
                pocketName = it.pocket.name,
                ratio = it.ratio
            )
        }
    }

    @Transactional
    fun saveRatios(userId: UUID, request: SaveDistributionRatiosRequest): List<DistributionRatioResponse> {
        val couple = getActiveCouple(userId)

        // Validate total ratio equals 100 (with 0.01 tolerance for floating-point rounding)
        val totalRatio = request.ratios.fold(BigDecimal.ZERO) { acc, entry -> acc.add(entry.ratio) }
        val lowerBound = BigDecimal("99.99")
        val upperBound = BigDecimal("100.01")
        if (totalRatio < lowerBound || totalRatio > upperBound) {
            throw BusinessException("VALIDATION_ERROR", "Total ratio must equal 100.00, but was $totalRatio")
        }

        // Normalize: adjust the last ratio so the sum is exactly 100.00
        val normalizedRatios = request.ratios.toMutableList()
        if (totalRatio.compareTo(BigDecimal("100.00")) != 0 && normalizedRatios.isNotEmpty()) {
            val lastEntry = normalizedRatios.last()
            val adjustment = BigDecimal("100.00") - totalRatio
            normalizedRatios[normalizedRatios.lastIndex] = lastEntry.copy(ratio = lastEntry.ratio + adjustment)
        }

        // Validate all pocket IDs belong to this couple and are active
        val pocketIds = normalizedRatios.map { it.pocketId }.toSet()
        val pockets = moneyPocketRepository.findByCoupleIdAndIsActiveTrue(couple.id)
        val activePocketIds = pockets.map { it.id }.toSet()

        val invalidIds = pocketIds - activePocketIds
        if (invalidIds.isNotEmpty()) {
            throw NotFoundException("POCKET_NOT_FOUND", "Pockets not found or inactive: $invalidIds")
        }

        // Check for duplicate pocket IDs in request
        if (pocketIds.size != normalizedRatios.size) {
            throw BusinessException("VALIDATION_ERROR", "Duplicate pocket IDs in request.")
        }

        val pocketMap = pockets.associateBy { it.id }

        // Delete existing ratios and replace
        distributionRatioRepository.deleteByCoupleId(couple.id)

        val saved = normalizedRatios.map { entry ->
            distributionRatioRepository.save(
                DistributionRatio(
                    couple = couple,
                    pocket = pocketMap[entry.pocketId]!!,
                    ratio = entry.ratio
                )
            )
        }

        return saved.map {
            DistributionRatioResponse(
                pocketId = it.pocket.id,
                pocketName = it.pocket.name,
                ratio = it.ratio
            )
        }
    }

    private fun getActiveCouple(userId: UUID): Couple {
        return coupleResolver.getActiveCouple(userId)
    }
}
