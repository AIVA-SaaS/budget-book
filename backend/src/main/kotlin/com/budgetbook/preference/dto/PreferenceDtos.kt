package com.budgetbook.preference.dto

import java.util.UUID

data class FavoritesResponse(
    val categoryIds: List<UUID>,
    val paymentMethodIds: List<UUID>
)

data class FavoritesRequest(
    val categoryIds: List<UUID>,
    val paymentMethodIds: List<UUID>
)

data class FavoriteToggleRequest(
    val type: String,
    val itemId: UUID
)

enum class FavoriteType {
    CATEGORY,
    PAYMENT_METHOD
}
