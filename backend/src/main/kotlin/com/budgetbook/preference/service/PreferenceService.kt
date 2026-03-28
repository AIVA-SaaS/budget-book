package com.budgetbook.preference.service

import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.preference.domain.CouplePreference
import com.budgetbook.preference.dto.FavoriteToggleRequest
import com.budgetbook.preference.dto.FavoriteType
import com.budgetbook.preference.dto.FavoritesRequest
import com.budgetbook.preference.dto.FavoritesResponse
import com.budgetbook.preference.repository.CouplePreferenceRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class PreferenceService(
    private val couplePreferenceRepository: CouplePreferenceRepository,
    override val coupleResolver: CoupleResolver,
    private val categoryRepository: CategoryRepository,
    private val paymentMethodRepository: PaymentMethodRepository
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun getFavorites(userId: UUID): FavoritesResponse {
        val couple = getActiveCouple(userId)
        val pref = couplePreferenceRepository.findByCoupleId(couple.id)
        return pref?.toResponse() ?: FavoritesResponse(emptyList(), emptyList())
    }

    @Transactional
    fun updateFavorites(userId: UUID, request: FavoritesRequest): FavoritesResponse {
        val couple = getActiveCouple(userId)
        val pref = couplePreferenceRepository.findByCoupleId(couple.id)
            ?: CouplePreference(couple = couple)

        pref.favoriteCategoryIds = request.categoryIds
        pref.favoritePaymentMethodIds = request.paymentMethodIds

        val saved = couplePreferenceRepository.save(pref)
        return saved.toResponse()
    }

    @Transactional
    fun toggleFavorite(userId: UUID, request: FavoriteToggleRequest): FavoritesResponse {
        val type = try {
            FavoriteType.valueOf(request.type)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid type: ${request.type}. Must be CATEGORY or PAYMENT_METHOD.")
        }

        val couple = getActiveCouple(userId)

        // Validate that the referenced entity exists
        when (type) {
            FavoriteType.CATEGORY -> {
                if (!categoryRepository.existsById(request.itemId)) {
                    throw NotFoundException("CATEGORY_NOT_FOUND", "Category does not exist.")
                }
            }
            FavoriteType.PAYMENT_METHOD -> {
                if (!paymentMethodRepository.existsById(request.itemId)) {
                    throw NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Payment method does not exist.")
                }
            }
        }

        val pref = couplePreferenceRepository.findByCoupleId(couple.id)
            ?: CouplePreference(couple = couple)

        when (type) {
            FavoriteType.CATEGORY -> {
                val current = pref.favoriteCategoryIds.toMutableList()
                if (current.contains(request.itemId)) {
                    current.remove(request.itemId)
                } else {
                    current.add(request.itemId)
                }
                pref.favoriteCategoryIds = current
            }
            FavoriteType.PAYMENT_METHOD -> {
                val current = pref.favoritePaymentMethodIds.toMutableList()
                if (current.contains(request.itemId)) {
                    current.remove(request.itemId)
                } else {
                    current.add(request.itemId)
                }
                pref.favoritePaymentMethodIds = current
            }
        }

        val saved = couplePreferenceRepository.save(pref)
        return saved.toResponse()
    }

    private fun CouplePreference.toResponse() = FavoritesResponse(
        categoryIds = favoriteCategoryIds,
        paymentMethodIds = favoritePaymentMethodIds
    )
}
