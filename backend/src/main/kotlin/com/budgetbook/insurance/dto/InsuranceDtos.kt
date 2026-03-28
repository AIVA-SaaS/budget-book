package com.budgetbook.insurance.dto

import com.budgetbook.common.dto.PatchValue
import com.budgetbook.common.dto.StringPatchValueDeserializer
import com.budgetbook.common.dto.UUIDPatchValueDeserializer
import com.budgetbook.insurance.domain.Insurance
import com.budgetbook.insurance.domain.InsuranceType
import com.budgetbook.insurance.domain.PaymentCycle
import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
import com.fasterxml.jackson.databind.annotation.JsonDeserialize
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

// ── Create Request ──

data class CreateInsuranceRequest(
    @field:NotBlank
    @field:Size(max = 100)
    val name: String,

    @field:Size(max = 100)
    val insurer: String? = null,

    @field:NotNull
    val insuranceType: InsuranceType,

    @field:NotNull
    @field:Min(1)
    val premiumAmount: Long,

    @field:Min(1)
    @field:Max(31)
    val paymentDay: Int? = null,

    val paymentCycle: PaymentCycle = PaymentCycle.MONTHLY,

    val paymentMethodId: UUID? = null,
    val categoryId: UUID? = null,
    val startDate: LocalDate? = null,
    val endDate: LocalDate? = null,
    val memo: String? = null,
    val visibility: String? = null
)

// ── Update Request (PatchValue semantics) ──

data class UpdateInsuranceRequest(
    @field:Size(max = 100)
    val name: String? = null,

    @JsonDeserialize(using = StringPatchValueDeserializer::class)
    val insurer: PatchValue<String>? = null,

    val insuranceType: InsuranceType? = null,

    @field:Min(1)
    val premiumAmount: Long? = null,

    @JsonDeserialize(using = IntPatchValueDeserializer::class)
    val paymentDay: PatchValue<Int>? = null,

    val paymentCycle: PaymentCycle? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val paymentMethodId: PatchValue<UUID>? = null,

    @JsonDeserialize(using = UUIDPatchValueDeserializer::class)
    val categoryId: PatchValue<UUID>? = null,

    @JsonDeserialize(using = LocalDatePatchValueDeserializer::class)
    val startDate: PatchValue<LocalDate>? = null,

    @JsonDeserialize(using = LocalDatePatchValueDeserializer::class)
    val endDate: PatchValue<LocalDate>? = null,

    @JsonDeserialize(using = StringPatchValueDeserializer::class)
    val memo: PatchValue<String>? = null,

    val isActive: Boolean? = null,
    val visibility: String? = null
)

// ── Response ──

data class InsuranceResponse(
    val id: UUID,
    val coupleId: UUID,
    val userId: UUID,
    val name: String,
    val insurer: String?,
    val insuranceType: InsuranceType,
    val premiumAmount: Long,
    val paymentDay: Int?,
    val paymentCycle: PaymentCycle,
    val paymentMethodId: UUID?,
    val categoryId: UUID?,
    val startDate: LocalDate?,
    val endDate: LocalDate?,
    val memo: String?,
    val isActive: Boolean,
    val visibility: String,
    val ownerId: UUID?,
    val createdAt: Instant,
    val updatedAt: Instant
)

// ── Summary ──

data class InsuranceSummaryResponse(
    val year: Int,
    val month: Int,
    val totalPremium: Long,
    val activeCount: Int,
    val items: List<InsuranceSummaryItem>
)

data class InsuranceSummaryItem(
    val id: UUID,
    val name: String,
    val insuranceType: InsuranceType,
    val premiumAmount: Long,
    val paymentCycle: PaymentCycle,
    val paymentDay: Int?,
    val isActive: Boolean
)

// ── Mapping ──

fun Insurance.toResponse() = InsuranceResponse(
    id = id,
    coupleId = couple.id,
    userId = user.id,
    name = name,
    insurer = insurer,
    insuranceType = insuranceType,
    premiumAmount = premiumAmount,
    paymentDay = paymentDay,
    paymentCycle = paymentCycle,
    paymentMethodId = paymentMethod?.id,
    categoryId = category?.id,
    startDate = startDate,
    endDate = endDate,
    memo = memo,
    isActive = isActive,
    visibility = visibility.name,
    ownerId = owner?.id,
    createdAt = createdAt,
    updatedAt = updatedAt
)

fun Insurance.toSummaryItem() = InsuranceSummaryItem(
    id = id,
    name = name,
    insuranceType = insuranceType,
    premiumAmount = premiumAmount,
    paymentCycle = paymentCycle,
    paymentDay = paymentDay,
    isActive = isActive
)

// ── Custom PatchValue deserializers ──

class IntPatchValueDeserializer : JsonDeserializer<PatchValue<Int>>() {
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext): PatchValue<Int> {
        return PatchValue(p.intValue)
    }

    override fun getNullValue(ctxt: DeserializationContext): PatchValue<Int> {
        return PatchValue(null)
    }
}

class LocalDatePatchValueDeserializer : JsonDeserializer<PatchValue<LocalDate>>() {
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext): PatchValue<LocalDate> {
        val text = p.valueAsString
        return PatchValue(if (text != null) LocalDate.parse(text) else null)
    }

    override fun getNullValue(ctxt: DeserializationContext): PatchValue<LocalDate> {
        return PatchValue(null)
    }
}
