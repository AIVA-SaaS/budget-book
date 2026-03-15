package com.budgetbook.transaction.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transaction.repository.TransactionSpecifications
import org.springframework.data.domain.Sort
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth
import java.util.UUID

@Service
class TransactionExportService(
    private val transactionRepository: TransactionRepository,
    private val coupleResolver: CoupleResolver
) {

    @Transactional(readOnly = true)
    fun exportCsv(
        userId: UUID,
        year: Int,
        month: Int,
        type: String?,
        categoryId: UUID?
    ): String {
        val couple = getActiveCouple(userId)

        val transactionType = type?.let {
            try {
                TransactionType.valueOf(it)
            } catch (e: IllegalArgumentException) {
                throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: $it")
            }
        }

        val yearMonth = YearMonth.of(year, month)
        val startDate = yearMonth.atDay(1)
        val endDate = yearMonth.atEndOfMonth()

        val spec = TransactionSpecifications.withFilters(
            coupleId = couple.id,
            startDate = startDate,
            endDate = endDate,
            type = transactionType,
            categoryId = categoryId,
            keyword = null,
            paymentMethodId = null,
            pocketId = null,
            amountMin = null,
            amountMax = null
        )

        val sort = Sort.by(Sort.Order.asc("transactionDate"), Sort.Order.asc("createdAt"))
        val transactions = transactionRepository.findAll(spec, sort)

        return buildCsv(transactions)
    }

    private fun buildCsv(transactions: List<Transaction>): String {
        val sb = StringBuilder()

        // UTF-8 BOM for Excel compatibility
        sb.append("\uFEFF")

        // Header
        sb.appendLine("날짜,유형,카테고리,설명,금액,메모,결제수단")

        // Data rows
        for (tx in transactions) {
            val date = tx.transactionDate.toString()
            val typeName = when (tx.type) {
                TransactionType.INCOME -> "수입"
                TransactionType.EXPENSE -> "지출"
            }
            val category = tx.category?.name ?: ""
            val description = escapeCsvField(tx.description)
            val amount = tx.amount.toString()
            val memo = escapeCsvField(tx.memo ?: "")
            val paymentMethod = tx.paymentMethod?.name ?: ""

            sb.appendLine("$date,$typeName,$category,$description,$amount,$memo,$paymentMethod")
        }

        return sb.toString()
    }

    private fun escapeCsvField(value: String): String {
        return if (value.contains(",") || value.contains("\"") || value.contains("\n")) {
            "\"${value.replace("\"", "\"\"")}\""
        } else {
            value
        }
    }

    private fun getActiveCouple(userId: UUID): Couple {
        return coupleResolver.getActiveCouple(userId)
    }
}
