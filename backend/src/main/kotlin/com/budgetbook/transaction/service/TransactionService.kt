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
        visibility: String? = null,
        page: Int,
        size: Int,
        // PR-C2 다중/그룹 필터. 단수 파라미터는 호환성을 위해 유지되며,
        // 내부에서 Set 으로 합쳐 TransactionSpecifications 에 전달된다.
        categoryIds: List<UUID> = emptyList(),
        categoryGroupIds: List<UUID> = emptyList(),
        paymentMethodIds: List<UUID> = emptyList(),
        pocketIds: List<UUID> = emptyList(),
        // Phase 22 T10: 다중 타입 필터. null/빈 리스트 = 필터 없음.
        // 단수 `type` 과 병존 시 `transactionTypes` 우선 (FE toQueryParams 와 일치).
        transactionTypes: List<String>? = null
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

        // Phase 22 T10: 다중 타입 우선 파싱.
        // 각 원소는 EXPENSE/INCOME/ADJUSTMENT 여야 하며, 그 외(예: FE-only TRANSFER) 는 400.
        val effectiveTransactionTypes: Set<TransactionType> = transactionTypes
            ?.filter { it.isNotBlank() }
            ?.map { raw ->
                try { TransactionType.valueOf(raw) } catch (e: IllegalArgumentException) {
                    throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: $raw")
                }
            }
            ?.toSet()
            ?: emptySet()

        // 단수 `type` 파싱 — `transactionTypes` 가 비어있을 때만 의미 있음.
        val transactionType = type?.let {
            try { TransactionType.valueOf(it) } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: $it")
            }
        }

        // visibility 필터: 'ALL'/null 은 기본 동작(공유 + 본인 개인), 'SHARED'/'PRIVATE' 는 명시적 필터.
        // 유효하지 않은 값은 VALIDATION_ERROR.
        val visibilityFilter = visibility?.uppercase()?.takeIf { it != "ALL" }
        if (visibilityFilter != null && visibilityFilter != "SHARED" && visibilityFilter != "PRIVATE") {
            throw BusinessException("VALIDATION_ERROR", "Invalid visibility: $visibility")
        }

        // PR-C2: 다중/그룹 필터 병합.
        // 단수 파라미터는 복수 Set 에 합쳐 TransactionSpecifications 로 한 번에 전달.
        // categoryGroupIds 는 BE 에서 하위 카테고리로 펼친 뒤 categoryIds Set 에 합쳐 IN-clause 적용 (원칙 1.4 — B-tree 인덱스 스캔 1회).
        val effectiveCategoryIds = categoryIds.toMutableSet().also { set ->
            categoryId?.let { set.add(it) }
            if (categoryGroupIds.isNotEmpty()) {
                // 그룹 펼치기: SELECT id FROM categories WHERE group_id IN (:groupIds) 한 번 호출.
                set.addAll(categoryRepository.findByGroupIdIn(categoryGroupIds).map { it.id })
            }
        }
        val effectivePaymentMethodIds = paymentMethodIds.toMutableSet().also { set ->
            paymentMethodId?.let { set.add(it) }
        }
        val effectivePocketIds = pocketIds.toMutableSet().also { set ->
            pocketId?.let { set.add(it) }
        }

        val pageSize = size.coerceIn(1, 100)
        val sort = Sort.by(Sort.Order.desc("transactionDate"), Sort.Order.desc("createdAt"))
        val pageable = PageRequest.of(page, pageSize, sort)

        // SHARED/PRIVATE visibility 필터, extended 필터, 또는 다중/그룹 필터가 들어오면 Spec 경로로 강제.
        // (legacy JPQL 은 단일 categoryId/type 만 지원)
        val hasMultiFilters = effectiveCategoryIds.isNotEmpty() ||
            effectivePaymentMethodIds.isNotEmpty() ||
            effectivePocketIds.isNotEmpty() ||
            effectiveTransactionTypes.isNotEmpty()
        val hasExtendedFilters = keyword != null || paymentMethodId != null ||
            pocketId != null || amountMin != null || amountMax != null ||
            visibilityFilter != null || hasMultiFilters

        val result = if (hasExtendedFilters) {
            // 단수 categoryId 는 Set 에 이미 합쳐졌으므로 Spec 에는 Set 만 전달 (중복 조건 방지).
            // paymentMethod/pocket 도 동일하게 Set 에 합침.
            // 단수 `type` 은 `transactionTypes` 가 비어있을 때만 사용 (FE `toQueryParams` 우선순위와 일치).
            val specCategoryId = if (effectiveCategoryIds.isNotEmpty()) null else categoryId
            val specPaymentMethodId = if (effectivePaymentMethodIds.isNotEmpty()) null else paymentMethodId
            val specPocketId = if (effectivePocketIds.isNotEmpty()) null else pocketId
            val specType = if (effectiveTransactionTypes.isNotEmpty()) null else transactionType
            val spec = TransactionSpecifications.withFilters(
                coupleId = couple.id,
                startDate = startDate,
                endDate = endDate,
                type = specType,
                categoryId = specCategoryId,
                keyword = keyword,
                paymentMethodId = specPaymentMethodId,
                pocketId = specPocketId,
                amountMin = amountMin,
                amountMax = amountMax,
                userId = userId,
                visibility = visibilityFilter,
                categoryIds = effectiveCategoryIds,
                paymentMethodIds = effectivePaymentMethodIds,
                pocketIds = effectivePocketIds,
                types = effectiveTransactionTypes
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

        validateAmountForType(transactionType, request.amount)

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

        request.amount?.let {
            validateAmountForType(transaction.type, it)
            transaction.amount = it
        }
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

    /**
     * Phase 22 T11: type 별 amount 부호 검증.
     *
     * - `EXPENSE` / `INCOME`: 양수만 허용 (> 0). DTO 의 `@Min(0)` 을 대체.
     * - `ADJUSTMENT`: 부호 있는 증감값. 0 은 의미 없는 조정이므로 거부.
     *
     * DB CHECK 제약(`ck_transactions_amount`, V54) 과 일치하며,
     * DTO 에서 일괄 `@Min(0)` 하는 대신 type 별로 정밀하게 검증한다.
     */
    private fun validateAmountForType(type: TransactionType, amount: Long) {
        when (type) {
            TransactionType.EXPENSE, TransactionType.INCOME -> {
                if (amount <= 0) {
                    throw BusinessException(
                        "VALIDATION_ERROR",
                        "${type.name} amount 는 0 보다 커야 합니다. (입력: $amount)"
                    )
                }
            }
            TransactionType.ADJUSTMENT -> {
                if (amount == 0L) {
                    throw BusinessException(
                        "VALIDATION_ERROR",
                        "ADJUSTMENT amount 는 0 이 될 수 없습니다. 잔액 조정 증감값을 입력하세요."
                    )
                }
            }
        }
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
