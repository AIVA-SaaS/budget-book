package com.budgetbook.spendingplan.repository

import com.budgetbook.spendingplan.domain.SpendingPlanStatusHistory
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface SpendingPlanStatusHistoryRepository : JpaRepository<SpendingPlanStatusHistory, UUID> {

    @Query("""
        SELECT h FROM SpendingPlanStatusHistory h
        LEFT JOIN FETCH h.changedBy
        LEFT JOIN FETCH h.linkedTransaction
        WHERE h.spendingPlan.id = :planId
        ORDER BY h.createdAt ASC
    """)
    fun findByPlanId(@Param("planId") planId: UUID): List<SpendingPlanStatusHistory>
}
