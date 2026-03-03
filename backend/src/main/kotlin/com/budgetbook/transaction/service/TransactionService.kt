package com.budgetbook.transaction.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.ForbiddenException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.couple.repository.CoupleRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CategorySummary
import com.budgetbook.transaction.dto.CreateTransactionRequest
import com.budgetbook.transaction.dto.PageResponse
import com.budgetbook.transaction.dto.TransactionResponse
import com.budgetbook.transaction.dto.UpdateTransactionRequest
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.data.domain.PageRequest
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class TransactionService(
    private val transactionRepository: TransactionRepository,
    private val coupleRepository: CoupleRepository,
    private val userRepository: UserRepository,
    private val categoryRepository: CategoryRepository
) {

    @Transactional(readOnly = true)
    fun listTransactions(
        userId: UUID,
        year: Int?,
        month: Int?,
        type: String?,
        categoryId: UUID?,
        page: Int,
        size: Int
    ): PageResponse<TransactionResponse> {
        val couple = getActiveCouple(userId)

        val now = LocalDate.now()
        val targetYear = year ?: now.year
        val targetMonth = month ?: now.monthValue
        val yearMonth = YearMonth.of(targetYear, targetMonth)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        val transactionType = type?.let {
            try { TransactionType.valueOf(it) } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: $it")
            }
        }

        val pageSize = size.coerceIn(1, 100)
        val pageable = PageRequest.of(page, pageSize)

        val result = transactionRepository.findByCoupleIdAndFilters(
            coupleId = couple.id,
            startDate = startDate,
            endDate = endDate,
            type = transactionType,
            categoryId = categoryId,
            pageable = pageable
        )

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
            if (cat.couple.id != couple.id) {
                throw ForbiddenException("FORBIDDEN", "Category belongs to a different couple.")
            }
            cat
        }

        val transaction = Transaction(
            couple = couple,
            author = user,
            category = category,
            type = transactionType,
            amount = request.amount,
            description = request.description,
            memo = request.memo,
            transactionDate = request.transactionDate
        )

        return transactionRepository.save(transaction).toResponse()
    }

    @Transactional(readOnly = true)
    fun getTransaction(userId: UUID, transactionId: UUID): TransactionResponse {
        val couple = getActiveCouple(userId)
        val transaction = transactionRepository.findById(transactionId)
            .orElseThrow { NotFoundException("TRANSACTION_NOT_FOUND", "Transaction does not exist.") }

        if (transaction.couple.id != couple.id) {
            throw ForbiddenException("FORBIDDEN", "Transaction belongs to a different couple.")
        }

        return transaction.toResponse()
    }

    @Transactional
    fun updateTransaction(userId: UUID, transactionId: UUID, request: UpdateTransactionRequest): TransactionResponse {
        val couple = getActiveCouple(userId)
        val transaction = transactionRepository.findById(transactionId)
            .orElseThrow { NotFoundException("TRANSACTION_NOT_FOUND", "Transaction does not exist.") }

        if (transaction.couple.id != couple.id) {
            throw ForbiddenException("FORBIDDEN", "Transaction belongs to a different couple.")
        }

        request.amount?.let { transaction.amount = it }
        request.description?.let { transaction.description = it }
        request.transactionDate?.let { transaction.transactionDate = it }
        request.memo?.let { transaction.memo = it.value }

        if (request.categoryId != null) {
            val cat = categoryRepository.findById(request.categoryId)
                .orElseThrow { NotFoundException("CATEGORY_NOT_FOUND", "Specified category does not exist.") }
            if (cat.couple.id != couple.id) {
                throw ForbiddenException("FORBIDDEN", "Category belongs to a different couple.")
            }
            transaction.category = cat
        }

        return transactionRepository.save(transaction).toResponse()
    }

    @Transactional
    fun deleteTransaction(userId: UUID, transactionId: UUID) {
        val couple = getActiveCouple(userId)
        val transaction = transactionRepository.findById(transactionId)
            .orElseThrow { NotFoundException("TRANSACTION_NOT_FOUND", "Transaction does not exist.") }

        if (transaction.couple.id != couple.id) {
            throw ForbiddenException("FORBIDDEN", "Transaction belongs to a different couple.")
        }

        transactionRepository.delete(transaction)
    }

    private fun getActiveCouple(userId: UUID): Couple {
        return coupleRepository.findByUserIdAndStatus(userId, CoupleStatus.ACTIVE)
            ?: throw NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")
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
                color = it.color
            )
        },
        type = type.name,
        amount = amount,
        description = description,
        memo = memo,
        transactionDate = transactionDate,
        createdAt = createdAt,
        updatedAt = updatedAt
    )
}
