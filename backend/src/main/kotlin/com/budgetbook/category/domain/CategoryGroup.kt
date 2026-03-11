package com.budgetbook.category.domain

import com.budgetbook.common.entity.BaseTimeEntity
import com.budgetbook.couple.domain.Couple
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.FetchType
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.util.UUID

@Entity
@Table(name = "category_groups")
class CategoryGroup(
    @Id
    val id: UUID = UUID.randomUUID(),

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "couple_id", nullable = false)
    val couple: Couple,

    @Column(nullable = false, length = 50)
    var name: String,

    @Column(length = 50)
    var icon: String? = null,

    @Column(length = 7)
    var color: String? = null,

    @Enumerated(EnumType.STRING)
    @Column(name = "budget_type", nullable = false, length = 20)
    var budgetType: BudgetType = BudgetType.MONTHLY,

    @Column(name = "display_order", nullable = false)
    var displayOrder: Int = 0,

    @Column(name = "is_default", nullable = false)
    val isDefault: Boolean = false
) : BaseTimeEntity()

enum class BudgetType { WEEKLY, MONTHLY, NONE }
