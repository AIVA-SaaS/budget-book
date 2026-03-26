package com.budgetbook.paymentmethod.repository

import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface PaymentMethodRepository : JpaRepository<PaymentMethod, UUID> {
    fun findByCoupleIdAndIsActiveTrue(coupleId: UUID): List<PaymentMethod>
    fun findByCoupleIdOrderByDisplayOrder(coupleId: UUID): List<PaymentMethod>
    fun findByIdAndCoupleId(id: UUID, coupleId: UUID): PaymentMethod?
    fun findByCoupleIdAndTypeAndIsActiveTrue(coupleId: UUID, type: PaymentMethodType): List<PaymentMethod>

    fun findByCoupleIdAndNameIn(coupleId: UUID, names: List<String>): List<PaymentMethod>

    fun findBySettlementDayAndLinkedBankIsNotNullAndIsActiveTrue(settlementDay: Int): List<PaymentMethod>
}
