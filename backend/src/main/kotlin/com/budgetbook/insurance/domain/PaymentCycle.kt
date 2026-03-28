package com.budgetbook.insurance.domain

enum class PaymentCycle(val monthsPerCycle: Int) {
    MONTHLY(1),
    QUARTERLY(3),
    SEMI_ANNUAL(6),
    YEARLY(12);

    /**
     * Returns true if the given month (1-12) is a payment month,
     * assuming January (month 1) is always a payment month.
     */
    fun isPaymentMonth(month: Int): Boolean {
        if (this == MONTHLY) return true
        return (month - 1) % monthsPerCycle == 0
    }
}
