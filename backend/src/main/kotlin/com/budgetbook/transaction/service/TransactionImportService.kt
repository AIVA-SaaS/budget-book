package com.budgetbook.transaction.service

import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.dto.CsvImportResponse
import com.budgetbook.transaction.dto.CsvImportError
import com.budgetbook.transaction.repository.TransactionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.multipart.MultipartFile
import java.io.BufferedReader
import java.io.InputStreamReader
import java.time.LocalDate
import java.time.format.DateTimeParseException
import java.util.UUID

@Service
class TransactionImportService(
    private val transactionRepository: TransactionRepository,
    private val coupleResolver: CoupleResolver,
    private val userRepository: UserRepository,
    private val categoryRepository: CategoryRepository,
    private val paymentMethodRepository: PaymentMethodRepository
) {

    companion object {
        private const val MAX_ROWS = 1000
        private const val BATCH_SIZE = 50
        private const val BOM = "\uFEFF"
    }

    @Transactional
    fun importCsv(userId: UUID, file: MultipartFile): CsvImportResponse {
        val couple = coupleResolver.getActiveCouple(userId)
        val user = userRepository.findById(userId)
            .orElseThrow { NotFoundException("USER_NOT_FOUND", "User not found.") }

        val lines = readCsvLines(file)
        if (lines.isEmpty()) {
            return CsvImportResponse(imported = 0, skipped = 0, errors = emptyList())
        }

        if (lines.size > MAX_ROWS) {
            throw BusinessException("VALIDATION_ERROR", "CSV file exceeds maximum of $MAX_ROWS rows.")
        }

        // Pre-fetch categories and payment methods for the couple (batch lookup)
        val categories = categoryRepository.findByCoupleId(couple.id)
        val categoryByNameLower = categories.associateBy { it.name.lowercase() }

        val paymentMethods = paymentMethodRepository.findByCoupleIdOrderByDisplayOrder(couple.id)
        val pmByNameLower = paymentMethods.associateBy { it.name.lowercase() }

        val errors = mutableListOf<CsvImportError>()
        val transactionsToSave = mutableListOf<Transaction>()

        for ((index, line) in lines.withIndex()) {
            val rowNumber = index + 2 // 1-based, skip header row
            val result = parseCsvRow(line, rowNumber, couple, user, categoryByNameLower, pmByNameLower)
            when (result) {
                is RowParseResult.Success -> transactionsToSave.add(result.transaction)
                is RowParseResult.Error -> errors.add(result.error)
            }
        }

        // Batch insert in chunks of BATCH_SIZE
        for (batch in transactionsToSave.chunked(BATCH_SIZE)) {
            transactionRepository.saveAll(batch)
        }

        return CsvImportResponse(
            imported = transactionsToSave.size,
            skipped = errors.size,
            errors = errors
        )
    }

    private fun readCsvLines(file: MultipartFile): List<String> {
        val reader = BufferedReader(InputStreamReader(file.inputStream, Charsets.UTF_8))
        val allLines = reader.use { it.readLines() }

        if (allLines.isEmpty()) return emptyList()

        // Skip header (first line), strip BOM if present
        val header = allLines[0].removePrefix(BOM).trim()
        if (header.isBlank()) return emptyList()

        // Return data lines only (skip empty lines)
        return allLines.drop(1).filter { it.isNotBlank() }
    }

    private fun parseCsvRow(
        line: String,
        rowNumber: Int,
        couple: Couple,
        user: com.budgetbook.auth.domain.User,
        categoryByNameLower: Map<String, com.budgetbook.category.domain.Category>,
        pmByNameLower: Map<String, com.budgetbook.paymentmethod.domain.PaymentMethod>
    ): RowParseResult {
        val fields = parseCsvFields(line)

        // Expected columns: date, type, amount, description, categoryName, paymentMethodName
        if (fields.size < 4) {
            return RowParseResult.Error(CsvImportError(rowNumber, "Not enough columns. Expected at least: date, type, amount, description."))
        }

        val dateStr = fields[0].trim()
        val typeStr = fields[1].trim()
        val amountStr = fields[2].trim()
        val description = fields[3].trim()
        val categoryName = fields.getOrNull(4)?.trim() ?: ""
        val paymentMethodName = fields.getOrNull(5)?.trim() ?: ""

        // Parse date
        val date = try {
            LocalDate.parse(dateStr)
        } catch (e: DateTimeParseException) {
            return RowParseResult.Error(CsvImportError(rowNumber, "Invalid date format: $dateStr"))
        }

        // Parse type (accept both Korean and enum names)
        val transactionType = when (typeStr.lowercase()) {
            "income", "\uc218\uc785" -> TransactionType.INCOME
            "expense", "\uc9c0\ucd9c" -> TransactionType.EXPENSE
            else -> return RowParseResult.Error(CsvImportError(rowNumber, "Invalid transaction type: $typeStr"))
        }

        // Parse amount
        val amount = try {
            amountStr.toLong()
        } catch (e: NumberFormatException) {
            return RowParseResult.Error(CsvImportError(rowNumber, "Invalid amount: $amountStr"))
        }

        if (amount <= 0) {
            return RowParseResult.Error(CsvImportError(rowNumber, "Amount must be positive: $amount"))
        }

        if (description.isBlank()) {
            return RowParseResult.Error(CsvImportError(rowNumber, "Description cannot be empty."))
        }

        // Match category by name (case-insensitive)
        val category = if (categoryName.isNotBlank()) {
            val matched = categoryByNameLower[categoryName.lowercase()]
            if (matched == null) {
                return RowParseResult.Error(CsvImportError(rowNumber, "Category not found: $categoryName"))
            }
            matched
        } else {
            null
        }

        // Match payment method by name (case-insensitive)
        val paymentMethod = if (paymentMethodName.isNotBlank()) {
            val matched = pmByNameLower[paymentMethodName.lowercase()]
            if (matched == null) {
                return RowParseResult.Error(CsvImportError(rowNumber, "Payment method not found: $paymentMethodName"))
            }
            matched
        } else {
            null
        }

        val transaction = Transaction(
            couple = couple,
            author = user,
            category = category,
            type = transactionType,
            amount = amount,
            description = description,
            transactionDate = date,
            paymentMethod = paymentMethod
        )

        return RowParseResult.Success(transaction)
    }

    /**
     * Parse CSV fields handling quoted fields with embedded commas and quotes.
     */
    private fun parseCsvFields(line: String): List<String> {
        val fields = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        var i = 0

        while (i < line.length) {
            val c = line[i]
            when {
                c == '"' && !inQuotes -> {
                    inQuotes = true
                }
                c == '"' && inQuotes -> {
                    // Check for escaped quote ""
                    if (i + 1 < line.length && line[i + 1] == '"') {
                        current.append('"')
                        i++ // skip next quote
                    } else {
                        inQuotes = false
                    }
                }
                c == ',' && !inQuotes -> {
                    fields.add(current.toString())
                    current.clear()
                }
                else -> {
                    current.append(c)
                }
            }
            i++
        }
        fields.add(current.toString())

        return fields
    }

    private sealed class RowParseResult {
        data class Success(val transaction: Transaction) : RowParseResult()
        data class Error(val error: CsvImportError) : RowParseResult()
    }
}
