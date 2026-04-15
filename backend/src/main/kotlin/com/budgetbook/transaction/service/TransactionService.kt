package com.budgetbook.transaction.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.entity.Visibility
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.common.security.OwnershipValidator
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.common.service.CoupleAwareService
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.pocket.repository.MoneyPocketRepository
import com.budgetbook.smart.service.PatternLearningService
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CategorySummary
import com.budgetbook.transaction.dto.CreateTransactionRequest
import com.budgetbook.transaction.dto.PageResponse
import com.budgetbook.transaction.dto.TransactionResponse
import com.budgetbook.transaction.dto.UpdateTransactionRequest
import com.budgetbook.sync.SyncEvent
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transaction.repository.TransactionSpecifications
import com.budgetbook.transfer.repository.TransferRepository
import org.slf4j.LoggerFactory
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class TransactionService(
    private val transactionRepository: TransactionRepository,
    override val coupleResolver: CoupleResolver,
    private val userRepository: UserRepository,
    private val categoryRepository: CategoryRepository,
    private val paymentMethodRepository: PaymentMethodRepository,
    private val moneyPocketRepository: MoneyPocketRepository,
    private val syncEventPublisher: SyncEventPublisher,
    private val patternLearningService: PatternLearningService,
    private val transferRepository: TransferRepository
) : CoupleAwareService {

    private val log = LoggerFactory.getLogger(javaClass)

    @Transactional(readOnly = true)
    fun listTransactions(
        userId: UUID,
        year: Int?,
        month: Int?,
        type: String?,
        categoryId: UUID?,
        keyword: String? = null,
        paymentMethodId: UUID? = null,
        pocketId: UUID? = null,
        amountMin: Long? = null,
        amountMax: Long? = null,
        dateFrom: LocalDate? = null,
        dateTo: LocalDate? = null,
        page: Int,
        size: Int
    ): PageResponse<TransactionResponse> {
        val couple = getActiveCouple(userId)

        val startDate: LocalDate
        val endDate: LocalDate

        if (dateFrom != null || dateTo != null) {
            startDate = dateFrom ?: LocalDate.of(2000, 1, 1)
            endDate = dateTo ?: LocalDate.of(2099, 12, 31)
        } else {
            val now = LocalDate.now()
            val targetYear = year ?: now.year
            val targetMonth = month ?: now.monthValue
            val yearMonth = YearMonth.of(targetYear, targetMonth)
            startDate = yearMonth.atDay(1)
            endDate = yearMonth.atEndOfMonth()
        }

        val transactionType = type?.let {
            try { TransactionType.valueOf(it) } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: $it")
            }
        }

        val pageSize = size.coerceIn(1, 100)
        val sort = Sort.by(Sort.Order.desc("transactionDate"), Sort.Order.desc("createdAt"))
        val pageable = PageRequest.of(page, pageSize, sort)

        val hasExtendedFilters = keyword != null || paymentMethodId != null ||
            pocketId != null || amountMin != null || amountMax != null

        val result = if (hasExtendedFilters) {
            val spec = TransactionSpecifications.withFilters(
                coupleId = couple.id,
                startDate = startDate,
                endDate = endDate,
                type = transactionType,
                categoryId = categoryId,
                keyword = keyword,
                paymentMethodId = paymentMethodId,
                pocketId = pocketId,
                amountMin = amountMin,
                amountMax = amountMax,
                userId = userId
            )
            transactionRepository.findAll(spec, pageable)
        } else {
            transactionRepository.findByCoupleIdAndFilters(
                coupleId = couple.id,
                startDate = startDate,
                endDate = endDate,
                type = transactionType,
                categoryId = categoryId,
                userId = userId,
                pageable = pageable
            )
        }

        return PageResponse(
            content = result.content.map { it.toResponse() },
            page = result.number,
            size = result.size,
            totalElements = result.totalElements,
            totalPages = result.totalPages,
            first = result.isFirst,
            last = result.isLast
        )
    }

    @Transactional
    fun createTransaction(userId: UUID, request: CreateTransactionRequest): TransactionResponse {
        val couple = getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val transactionType = try {
            TransactionType.valueOf(request.type)
        } catch (e: IllegalArgumentException) {
            throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: ${request.type}")
        }

        val category = request.categoryId?.let { catId ->
            val cat = categoryRepository.findById(catId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified category does not exist.") }
            OwnershipValidator.validateOwnership(cat.couple.id, couple, "Category")
            cat
        }

        // Visibility is always derived from the category (not from request)
        val effectiveVisibility = category?.visibility ?: Visibility.SHARED

        val paymentMethod = request.paymentMethodId?.let { pmId ->
            val pm = paymentMethodRepository.findById(pmId)
                .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified payment method does not exist.") }
            OwnershipValidator.validateOwnership(pm.couple.id, couple, "Payment method")
            pm
        }

        val settlementDate = paymentMethod?.let {
            calculateSettlementDate(it, request.transactionDate)
        }

        val pocket = request.pocketId?.let { pocketId ->
            val p = moneyPocketRepository.findById(pocketId)
                .orElseThrow { NotFoundException("POCKET_NOT_FOUND", "Specified pocket does not exist.") }
            OwnershipValidator.validateOwnership(p.couple.id, couple, "Pocket")
            if (!p.isActive) {
                throw NotFoundException("POCKET_NOT_FOUND", "Specified pocket is not active.")
            }
            p
        }

        val transaction = Transaction(
            couple = couple,
            author = user,
            category = category,
            type = transactionType,
            amount = request.amount,
            description = request.description,
            memo = request.memo,
            transactionDate = request.transactionDate,
            paymentMethod = paymentMethod,
            settlementDate = settlementDate,
            pocket = pocket,
            visibility = effectiveVisibility,
            owner = if (effectiveVisibility == Visibility.PRIVATE) user else null
        )

        val saved = transactionRepository.save(transaction)
        syncEventPublisher.publish(SyncEvent(
            type = "TRANSACTION_CREATED",
            entityType = "TRANSACTION",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        learnPattern(couple.id, saved.description, saved.category?.id)
        return saved.toResponse()
    }

    @Transactional(readOnly = true)
    fun getTransaction(userId: UUID, transactionId: UUID): TransactionResponse {
        val couple = getActiveCouple(userId)
        val transaction = transactionRepository.findById(transactionId)
            .orElseThrow { NotFoundException("TRANSACTION_NOT_FOUND", "Transaction does not exist.") }

        OwnershipValidator.validateOwnership(transaction.couple.id, couple, "Transaction")
        validateVisibilityAccess(transaction.visibility, transaction.owner?.id, userId)

        return transaction.toResponse()
    }

    @Transactional
    fun updateTransaction(userId: UUID, transactionId: UUID, request: UpdateTransactionRequest): TransactionResponse {
        val couple = getActiveCouple(userId)
        val transaction = transactionRepository.findById(transactionId)
            .orElseThrow { NotFoundException("TRANSACTION_NOT_FOUND", "Transaction does not exist.") }

        OwnershipValidator.validateOwnership(transaction.couple.id, couple, "Transaction")
        validatePrivateOwner(transaction.visibility, transaction.owner?.id, userId)

        request.amount?.let { transaction.amount = it }
        request.description?.let { transaction.description = it }
        request.transactionDate?.let { transaction.transactionDate = it }
        request.memo?.let { transaction.memo = it.value }

        // Handle categoryId with PatchValue (before visibility, as category may force PRIVATE)
        request.categoryId?.let { patchValue ->
            val catId = patchValue.value
            if (catId != null) {
                val cat = categoryRepository.findById(catId)
                    .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified category does not exist.") }
                OwnershipValidator.validateOwnership(cat.couple.id, couple, "Category")
                transaction.category = cat
            } else {
                transaction.category = null
            }
        }

        // Visibility is always derived from the category (not from request)
        val newVisibility = transaction.category?.visibility ?: Visibility.SHARED
        transaction.visibility = newVisibility
        if (newVisibility == Visibility.PRIVATE) {
            if (transaction.owner == null) {
                val user = userRepository.findById(userId)
                    .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }
                transaction.owner = user
            }
        } else {
            transaction.owner = null
        }

        // Handle paymentMethodId with PatchValue
        var paymentMethodChanged = false
        request.paymentMethodId?.let { patchValue ->
            val pmId = patchValue.value
            if (pmId != null) {
                val pm = paymentMethodRepository.findById(pmId)
                    .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified payment method does not exist.") }
                OwnershipValidator.validateOwnership(pm.couple.id, couple, "Payment method")
                transaction.paymentMethod = pm
                transaction.settlementDate = calculateSettlementDate(pm, transaction.transactionDate)
                paymentMethodChanged = true
            } else {
                transaction.paymentMethod = null
                transaction.settlementDate = null
                paymentMethodChanged = true
            }
        }

        // Handle pocketId with PatchValue
        request.pocketId?.let { patchValue ->
            val pocketIdVal = patchValue.value
            if (pocketIdVal != null) {
                val p = moneyPocketRepository.findById(pocketIdVal)
                    .orElseThrow { NotFoundException("POCKET_NOT_FOUND", "Specified pocket does not exist.") }
                OwnershipValidator.validateOwnership(p.couple.id, couple, "Pocket")
                if (!p.isActive) {
                    throw NotFoundException("POCKET_NOT_FOUND", "Specified pocket is not active.")
                }
                transaction.pocket = p
            } else {
                transaction.pocket = null
            }
        }

        // If transactionDate changed but paymentMethod was not changed, recalculate settlement date
        if (request.transactionDate != null && !paymentMethodChanged) {
            transaction.paymentMethod?.let { pm ->
                transaction.settlementDate = calculateSettlementDate(pm, transaction.transactionDate)
            }
        }

        val saved = transactionRepository.save(transaction)
        syncEventPublisher.publish(SyncEvent(
            type = "TRANSACTION_UPDATED",
            entityType = "TRANSACTION",
            entityId = saved.id,
            coupleId = couple.id,
            authorId = userId
        ))
        learnPattern(couple.id, saved.description, saved.category?.id)
        return saved.toResponse()
    }

    @Transactional
    fun deleteTransaction(userId: UUID, transactionId: UUID) {
        val couple = getActiveCouple(userId)
        val transaction = transactionRepository.findById(transactionId)
            .orElseThrow { NotFoundException("TRANSACTION_NOT_FOUND", "Transaction does not exist.") }

        OwnershipValidator.validateOwnership(transaction.couple.id, couple, "Transaction")
        validatePrivateOwner(transaction.visibility, transaction.owner?.id, userId)

        transactionRepository.delete(transaction)
        syncEventPublisher.publish(SyncEvent(
            type = "TRANSACTION_DELETED",
            entityType = "TRANSACTION",
            entityId = transactionId,
            coupleId = couple.id,
            authorId = userId
        ))
    }

    @Transactional(readOnly = true)
    fun getSuggestions(userId: UUID, query: String, limit: Int = 5): List<com.budgetbook.transaction.dto.SuggestionResponse> {
        if (query.length < 2) return emptyList()
        val couple = getActiveCouple(userId)
        val safeLimit = limit.coerceIn(1, 20)

        val rows = transactionRepository.findSuggestionPatterns(couple.id, query)

        // Group by description, then collect patterns per description
        val grouped = linkedMapOf<String, MutableList<com.budgetbook.transaction.dto.SuggestionPattern>>()
        for (row in rows) {
            val description = row[0] as String
            val pattern = com.budgetbook.transaction.dto.SuggestionPattern(
                categoryId = row[1] as? UUID,
                categoryName = row[2] as? String,
                categoryIcon = row[3] as? String,
                categoryColor = row[4] as? String,
                paymentMethodId = row[5] as? UUID,
                paymentMethodName = row[6] as? String,
                count = (row[7] as Long)
            )
            grouped.getOrPut(description) { mutableListOf() }.add(pattern)
        }

        return grouped.entries
            .sortedByDescending { entry -> entry.value.sumOf { it.count } }
            .take(safeLimit)
            .map { (desc, patterns) ->
                com.budgetbook.transaction.dto.SuggestionResponse(
                    description = desc,
                    patterns = patterns.take(5)
                )
            }
    }

    @Transactional(readOnly = true)
    fun getSettlementTransactions(userId: UUID, paymentMethodId: UUID, year: Int, month: Int): com.budgetbook.transaction.dto.SettlementTransactionsResponse {
        val couple = getActiveCouple(userId)
        val pm = paymentMethodRepository.findById(paymentMethodId)
            .orElseThrow { NotFoundException("PAYMENT_METHOD_NOT_FOUND", "Specified payment method does not exist.") }
        OwnershipValidator.validateOwnership(pm.couple.id, couple, "Payment method")

        val yearMonth = YearMonth.of(year, month)
        val prevMonth = yearMonth.minusMonths(1)

        // 1. Transactions with settlementDate in the requested month
        val bySettlement = transactionRepository.findByPaymentMethodAndSettlementDateRange(
            paymentMethodId, yearMonth.atDay(1), yearMonth.atEndOfMonth(), userId
        )
        // Fallback: transactions from previous month with null settlementDate
        val transactions = if (bySettlement.isNotEmpty()) {
            bySettlement
        } else {
            transactionRepository.findByPaymentMethodAndTransactionDateRangeWithNullSettlement(
                paymentMethodId, prevMonth.atDay(1), prevMonth.atEndOfMonth(), userId
            )
        }

        // 2. Transfers where source = this card (카드에서 출금한 이체)
        //    Previous month transfers represent card usage to be settled this month
        val transfers = transferRepository.findBySourcePaymentMethodAndDateRange(
            paymentMethodId, prevMonth.atDay(1), prevMonth.atEndOfMonth()
        )

        // 3. Combine transaction items + transfer items
        val txnItems = transactions.map { t ->
            com.budgetbook.transaction.dto.SettlementTransactionItem(
                id = t.id,
                transactionDate = t.transactionDate,
                settlementDate = t.settlementDate,
                description = t.description,
                amount = t.amount,
                categoryName = t.category?.name,
                categoryIcon = t.category?.icon,
                type = "TRANSACTION"
            )
        }
        val transferItems = transfers.map { tr ->
            com.budgetbook.transaction.dto.SettlementTransactionItem(
                id = tr.id,
                transactionDate = tr.transferDate,
                settlementDate = null,
                description = tr.description ?: "이체",
                amount = tr.amount,
                categoryName = null,
                categoryIcon = null,
                type = "TRANSFER"
            )
        }
        val allItems = (txnItems + transferItems).sortedBy { it.transactionDate }

        return com.budgetbook.transaction.dto.SettlementTransactionsResponse(
            totalAmount = allItems.sumOf { it.amount },
            transactionCount = allItems.size,
            transactions = allItems
        )
    }

    private fun calculateSettlementDate(
        paymentMethod: com.budgetbook.paymentmethod.domain.PaymentMethod,
        transactionDate: LocalDate
    ): LocalDate? {
        if (paymentMethod.type != PaymentMethodType.CREDIT) return null
        val closingDay = paymentMethod.closingDay ?: return null
        val settlementDay = paymentMethod.settlementDay ?: return null

        val settlementMonth = if (transactionDate.dayOfMonth <= closingDay) {
            transactionDate.plusMonths(1)
        } else {
            transactionDate.plusMonths(2)
        }

        val yearMonth = YearMonth.of(settlementMonth.year, settlementMonth.month)
        val day = settlementDay.coerceAtMost(yearMonth.lengthOfMonth())
        return LocalDate.of(yearMonth.year, yearMonth.month, day)
    }

    private fun Transaction.toResponse() = TransactionResponse(
        id = id,
        coupleId = couple.id,
        author = UserSummary(
            id = author.id,
            nickname = author.nickname,
            profileImageUrl = author.profileImageUrl
        ),
        category = category?.let {
            CategorySummary(
                id = it.id,
                name = it.name,
                type = it.type.name,
                icon = it.icon,
                color = it.color,
                groupId = it.group?.id,
                groupName = it.group?.name
            )
        },
        type = type.name,
        amount = amount,
        description = description,
        memo = memo,
        transactionDate = transactionDate,
        paymentMethodId = paymentMethod?.id,
        paymentMethodName = paymentMethod?.name,
        paymentMethodType = paymentMethod?.type?.name,
        settlementDate = settlementDate?.toString(),
        pocketId = pocket?.id,
        pocketName = pocket?.name,
        visibility = visibility.name,
        ownerId = owner?.id,
        createdAt = createdAt,
        updatedAt = updatedAt
    )

    private fun learnPattern(coupleId: UUID, description: String, categoryId: UUID?) {
        if (categoryId == null) return
        try {
            patternLearningService.learn(coupleId, description, categoryId)
        } catch (e: Exception) {
            log.warn("Pattern learning failed for coupleId={}: {}", coupleId, e.message)
        }
    }

    companion object {
        fun parseVisibility(visibilityStr: String?): Visibility {
            return when (visibilityStr?.uppercase()) {
                "PRIVATE" -> Visibility.PRIVATE
                "SHARED", null -> Visibility.SHARED
                else -> throw BusinessException("VALIDATION_ERROR", "Invalid visibility: $visibilityStr")
            }
        }

        fun validateVisibilityAccess(visibility: Visibility, ownerId: UUID?, currentUserId: UUID) {
            if (visibility == Visibility.PRIVATE && ownerId != null && ownerId != currentUserId) {
                throw NotFoundException("TRANSACTION_NOT_FOUND", "Transaction does not exist.")
            }
        }

        fun validatePrivateOwner(visibility: Visibility, ownerId: UUID?, currentUserId: UUID) {
            if (visibility == Visibility.PRIVATE && ownerId != null && ownerId != currentUserId) {
                throw ForbiddenException("FORBIDDEN", "Only the owner can modify a private entity.")
            }
        }
    }
}
