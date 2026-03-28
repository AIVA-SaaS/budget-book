package com.budgetbook.preference.domain

import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.couple.domain.Couple
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.OneToOne
import jakarta.persistence.Table
import org.hibernate.annotations.JdbcTypeCode
import org.hibernate.type.SqlTypes
import java.util.UUID

@Entity
@Table(name = "couple_preferences")
class CouplePreference(
    @Id
    val id: UUID = UUID.randomUUID(),

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", unique = true, nullable = false)
    val couple: Couple,

    @Column(name = "favorite_category_ids", columnDefinition = "uuid[]")
    @JdbcTypeCode(SqlTypes.ARRAY)
    var favoriteCategoryIds: List<UUID> = emptyList(),

    @Column(name = "favorite_payment_method_ids", columnDefinition = "uuid[]")
    @JdbcTypeCode(SqlTypes.ARRAY)
    var favoritePaymentMethodIds: List<UUID> = emptyList(),
) : BaseTimeEntity()
