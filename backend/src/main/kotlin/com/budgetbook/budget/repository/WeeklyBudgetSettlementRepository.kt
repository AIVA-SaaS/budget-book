package com.budgetbook.budget.repository

import com.budgetbook.budget.domain.WeeklyBudgetSettlement
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface WeeklyBudgetSettlementRepository : JpaRepository<WeeklyBudgetSettlement, UUID> {

    fun findByCoupleIdAndYearMonth(coupleId: UUID, yearMonth: String): List<WeeklyBudgetSettlement>

    fun findByBudgetIdAndYearMonthAndWeekNumber(
        budgetId: UUID,
        yearMonth: String,
        weekNumber: Int
    ): List<WeeklyBudgetSettlement>
}
