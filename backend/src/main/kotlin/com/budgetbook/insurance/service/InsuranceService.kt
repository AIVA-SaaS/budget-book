package com.budgetbook.insurance.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.insurance.domain.Insurance
import com.budgetbook.insurance.dto.CreateInsuranceRequest
import com.budgetbook.insurance.dto.InsuranceResponse
import com.budgetbook.insurance.dto.InsuranceSummaryItem
import com.budgetbook.insurance.dto.InsuranceSummaryResponse
import com.budgetbook.insurance.dto.UpdateInsuranceRequest
import com.budgetbook.insurance.dto.toResponse
import com.budgetbook.insurance.dto.toSummaryItem
import com.budgetbook.insurance.repository.InsuranceRepository
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

@Service
class InsuranceService(
    private val insuranceRepository: InsuranceRepository,
    override val coupleResolver: CoupleResolver,
    private val userRepository: UserRepository,
    private val paymentMethodRepository: PaymentMethodRepository,
    private val categoryRepository: CategoryRepository
) : CoupleAwareService {

    @Transactional(readOnly = true)
    fun listInsurances(userId: UUID, active: Boolean?): List<InsuranceResponse> {
        val couple = getActiveCouple(userId)
        val insurances = if (active == true) {
            insuranceRepository.findByCoupleIdAndActiveAndVisible(couple.id, userId)
        } else {
            insuranceRepository.findByCoupleIdAndVisible(couple.id, userId)
        }
        return insurances.map { it.toResponse() }
    }

    @Transactional
    fun createInsurance(userId: UUID, request: CreateInsuranceRequest): InsuranceResponse {
        val couple = getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val paymentMethod = request.paymentMethodId?.let { pmId ->
            paymentMethodRepository.findById(pmId)
                .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified paymentMethodId does not exist.") }
                .also { OwnershipValidator.validateOwnership(it.couple.id, couple, "Payment method") }
        }

        val category = request.categoryId?.let { catId ->
            categoryRepository.findById(catId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified categoryId does not exist.") }
        }

        val visibility = request.visibility?.let {
            try { Visibility.valueOf(it) } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid visibility value: $it")
            }
        } ?: Visibility.SHARED

        val insurance = Insurance(
            couple = couple,
            user = user,
            name = request.name,
            insurer = request.insurer,
            insuranceType = request.insuranceType,
            premiumAmount = request.premiumAmount,
            paymentDay = request.paymentDay,
            paymentCycle = request.paymentCycle,
            paymentMethod = paymentMethod,
            category = category,
            startDate = request.startDate,
            endDate = request.endDate,
            memo = request.memo,
            visibility = visibility,
            owner = if (visibility == Visibility.PRIVATE) user else null
        )

        return insuranceRepository.save(insurance).toResponse()
    }

    @Transactional
    fun updateInsurance(userId: UUID, insuranceId: UUID, request: UpdateInsuranceRequest): InsuranceResponse {
        val couple = getActiveCouple(userId)
        val insurance = findInsuranceWithAccess(insuranceId, couple.id, userId)

        request.name?.let { insurance.name = it }
        request.insurer?.let { patchValue ->
            // Mirror create-side @Size(max=100); PatchValue wrapper bypasses Bean Validation.
            patchValue.value?.let { insurer ->
                if (insurer.length > 100) {
                    throw BusinessException("VALIDATION_ERROR", "insurer must be 100 characters or less.")
                }
            }
            insurance.insurer = patchValue.value
        }
        request.insuranceType?.let { insurance.insuranceType = it }
        request.premiumAmount?.let { insurance.premiumAmount = it }
        request.paymentDay?.let { patchValue ->
            // Mirror create-side @Min(1)@Max(31); PatchValue wrapper bypasses Bean Validation.
            patchValue.value?.let { day ->
                if (day < 1 || day > 31) {
                    throw BusinessException("VALIDATION_ERROR", "paymentDay must be between 1 and 31.")
                }
            }
            insurance.paymentDay = patchValue.value
        }
        request.paymentCycle?.let { insurance.paymentCycle = it }

        request.paymentMethodId?.let { patchValue ->
            insurance.paymentMethod = patchValue.value?.let { pmId ->
                paymentMethodRepository.findById(pmId)
                    .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified paymentMethodId does not exist.") }
                    .also { OwnershipValidator.validateOwnership(it.couple.id, couple, "Payment method") }
            }
        }

        request.categoryId?.let { patchValue ->
            insurance.category = patchValue.value?.let { catId ->
                categoryRepository.findById(catId)
                    .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified categoryId does not exist.") }
            }
        }

        request.startDate?.let { insurance.startDate = it.value }
        request.endDate?.let { insurance.endDate = it.value }
        request.memo?.let { insurance.memo = it.value }
        request.isActive?.let { insurance.isActive = it }

        request.visibility?.let { visStr ->
            val newVisibility = try { Visibility.valueOf(visStr) } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid visibility value: $visStr")
            }
            insurance.visibility = newVisibility
            if (newVisibility == Visibility.PRIVATE && insurance.owner == null) {
                val user = userRepository.findById(userId)
                    .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
                insurance.owner = user
            } else if (newVisibility == Visibility.SHARED) {
                insurance.owner = null
            }
        }

        return insuranceRepository.save(insurance).toResponse()
    }

    @Transactional
    fun deleteInsurance(userId: UUID, insuranceId: UUID) {
        val couple = getActiveCouple(userId)
        val insurance = findInsuranceWithAccess(insuranceId, couple.id, userId)
        insuranceRepository.delete(insurance)
    }

    @Transactional(readOnly = true)
    fun getInsuranceSummary(userId: UUID, year: Int, month: Int): InsuranceSummaryResponse {
        val couple = getActiveCouple(userId)
        val activeInsurances = insuranceRepository.findByCoupleIdAndActiveAndVisible(couple.id, userId)

        // Filter by payment cycle: only include insurances that are due in this month
        val dueInsurances = activeInsurances.filter { insurance ->
            // Check if policy is active during this period
            val queryStart = java.time.LocalDate.of(year, month, 1)
            val queryEnd = queryStart.withDayOfMonth(queryStart.lengthOfMonth())

            val startOk = insurance.startDate == null || !insurance.startDate!!.isAfter(queryEnd)
            val endOk = insurance.endDate == null || !insurance.endDate!!.isBefore(queryStart)

            if (!startOk || !endOk) return@filter false

            // Check payment cycle
            insurance.paymentCycle.isPaymentMonth(month)
        }

        val totalPremium = dueInsurances.sumOf { it.premiumAmount }

        return InsuranceSummaryResponse(
            year = year,
            month = month,
            totalPremium = totalPremium,
            activeCount = dueInsurances.size,
            items = dueInsurances.map { it.toSummaryItem() }
        )
    }

    private fun findInsuranceWithAccess(insuranceId: UUID, coupleId: UUID, userId: UUID): Insurance {
        val insurance = insuranceRepository.findByIdAndCoupleId(insuranceId, coupleId)
            ?: throw NotFoundException("INSURANCE_NOT_FOUND", "Insurance does not exist or belongs to another couple.")

        // PRIVATE insurance can only be accessed by the owner
        if (insurance.visibility == Visibility.PRIVATE && insurance.owner?.id != null && insurance.owner?.id != userId) {
            throw ForbiddenException("PRIVATE_ACCESS_DENIED", "Insurance is PRIVATE and caller is not the owner.")
        }

        return insurance
    }
}
