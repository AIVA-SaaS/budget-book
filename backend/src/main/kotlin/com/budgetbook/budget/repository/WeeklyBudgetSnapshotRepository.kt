package com.budgetbook.budget.repository

import com.budgetbook.budget.domain.WeeklyBudgetSnapshot
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface WeeklyBudgetSnapshotRepository : JpaRepository<WeeklyBudgetSnapshot, UUID> {
    fun findByCoupleIdAndYearMonth(coupleId: UUID, yearMonth: String): List<WeeklyBudgetSnapshot>
    fun findByCoupleIdAndYearMonthAndWeekNumber(coupleId: UUID, yearMonth: String, weekNumber: Int): WeeklyBudgetSnapshot?
    fun findByCoupleIdAndGroupIdAndYearMonth(coupleId: UUID, groupId: UUID, yearMonth: String): List<WeeklyBudgetSnapshot>
}
