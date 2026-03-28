package com.budgetbook.spendingplan.domain

/**
 * Frequency enum for spending plans.
 * Limited to WEEKLY/MONTHLY per DB constraint ck_spending_plan_frequency.
 */
enum class SpendingPlanFrequency {
    WEEKLY, MONTHLY
}
