package com.budgetbook.transaction.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import com.budgetbook.category.repository.CategoryRepository
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.repository.TransactionRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.springframework.web.multipart.MultipartFile
import java.io.ByteArrayInputStream
import java.util.Optional
import java.util.UUID

class TransactionImportServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transactionRepository = mockk<TransactionRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val userRepository = mockk<UserRepository>()
    val categoryRepository = mockk<CategoryRepository>()
    val paymentMethodRepository = mockk<PaymentMethodRepository>()
    val service = TransactionImportService(
        transactionRepository, coupleResolver, userRepository, categoryRepository, paymentMethodRepository
    )

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)

    val foodCategory = Category(couple = couple, name = "Food", type = CategoryType.EXPENSE, icon = "restaurant", color = "#FF0000")
    val salaryCategory = Category(couple = couple, name = "Salary", type = CategoryType.INCOME, icon = "work", color = "#00FF00")

    val creditCard = PaymentMethod(couple = couple, name = "Shinhan Card", type = PaymentMethodType.CREDIT)
    val cashMethod = PaymentMethod(couple = couple, name = "Cash", type = PaymentMethodType.CASH)

    fun mockFile(content: String): MultipartFile {
        val file = mockk<MultipartFile>()
        every { file.inputStream } returns ByteArrayInputStream(content.toByteArray(Charsets.UTF_8))
        return file
    }

    fun setupCommonMocks() {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)
        every { categoryRepository.findByCoupleId(couple.id) } returns listOf(foodCategory, salaryCategory)
        every { paymentMethodRepository.findByCoupleIdOrderByDisplayOrder(couple.id) } returns listOf(creditCard, cashMethod)
    }

    Given("a valid CSV file with matching categories and payment methods") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = """date,type,amount,description,categoryName,paymentMethodName
2026-03-01,INCOME,3000000,Monthly salary,Salary,
2026-03-05,EXPENSE,15000,Lunch,Food,Shinhan Card
2026-03-10,EXPENSE,5000,Coffee,Food,Cash"""

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("all rows are imported successfully") {
                result.imported shouldBe 3
                result.skipped shouldBe 0
                result.errors.size shouldBe 0
            }

            Then("transactions are saved in batches") {
                verify(exactly = 1) { transactionRepository.saveAll(any<List<Transaction>>()) }
            }
        }
    }

    Given("a CSV file with BOM prefix") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "\uFEFFdate,type,amount,description,categoryName,paymentMethodName\n2026-03-01,EXPENSE,10000,Test,Food,"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("BOM is handled correctly") {
                result.imported shouldBe 1
                result.skipped shouldBe 0
            }
        }
    }

    Given("a CSV file with Korean type names") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\n2026-03-01,\uc218\uc785,3000000,\uc6d4\uae09,Salary,\n2026-03-05,\uc9c0\ucd9c,15000,\uc810\uc2ec,Food,"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("Korean type names are parsed correctly") {
                result.imported shouldBe 2
                result.skipped shouldBe 0
            }
        }
    }

    Given("a CSV file with unmatched category") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\n2026-03-01,EXPENSE,10000,Test,NonExistentCategory,"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("the row is skipped with error") {
                result.imported shouldBe 0
                result.skipped shouldBe 1
                result.errors[0].row shouldBe 2
                result.errors[0].reason shouldBe "Category not found: NonExistentCategory"
            }
        }
    }

    Given("a CSV file with unmatched payment method") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\n2026-03-01,EXPENSE,10000,Test,Food,Unknown Card"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("the row is skipped with error") {
                result.imported shouldBe 0
                result.skipped shouldBe 1
                result.errors[0].row shouldBe 2
                result.errors[0].reason shouldBe "Payment method not found: Unknown Card"
            }
        }
    }

    Given("a CSV file with invalid date") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\nnot-a-date,EXPENSE,10000,Test,Food,"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("the row is skipped with date error") {
                result.imported shouldBe 0
                result.skipped shouldBe 1
                result.errors[0].row shouldBe 2
                result.errors[0].reason shouldBe "Invalid date format: not-a-date"
            }
        }
    }

    Given("a CSV file with invalid amount") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\n2026-03-01,EXPENSE,abc,Test,Food,"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("the row is skipped with amount error") {
                result.imported shouldBe 0
                result.skipped shouldBe 1
                result.errors[0].row shouldBe 2
                result.errors[0].reason shouldBe "Invalid amount: abc"
            }
        }
    }

    Given("a CSV file with zero amount") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\n2026-03-01,EXPENSE,0,Test,Food,"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("the row is skipped with positive amount error") {
                result.imported shouldBe 0
                result.skipped shouldBe 1
                result.errors[0].reason shouldBe "Amount must be positive: 0"
            }
        }
    }

    Given("a CSV file with invalid transaction type") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\n2026-03-01,INVALID_TYPE,10000,Test,Food,"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("the row is skipped with type error") {
                result.imported shouldBe 0
                result.skipped shouldBe 1
                result.errors[0].reason shouldBe "Invalid transaction type: INVALID_TYPE"
            }
        }
    }

    Given("a CSV file with mixed valid and invalid rows") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = """date,type,amount,description,categoryName,paymentMethodName
2026-03-01,EXPENSE,15000,Valid row,Food,
bad-date,EXPENSE,10000,Bad date row,,
2026-03-03,EXPENSE,5000,Another valid,Food,Cash"""

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("valid rows are imported, invalid rows are skipped") {
                result.imported shouldBe 2
                result.skipped shouldBe 1
                result.errors[0].row shouldBe 3
            }
        }
    }

    Given("an empty CSV file") {
        setupCommonMocks()

        val csv = ""

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("returns zero imported") {
                result.imported shouldBe 0
                result.skipped shouldBe 0
            }
        }
    }

    Given("a CSV file with only header") {
        setupCommonMocks()

        val csv = "date,type,amount,description,categoryName,paymentMethodName"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("returns zero imported") {
                result.imported shouldBe 0
                result.skipped shouldBe 0
            }
        }
    }

    Given("a CSV file with case-insensitive category matching") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\n2026-03-01,EXPENSE,10000,Test,food,shinhan card"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("category and payment method are matched case-insensitively") {
                result.imported shouldBe 1
                result.skipped shouldBe 0
            }
        }
    }

    Given("a CSV file with quoted fields containing commas") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\n2026-03-01,EXPENSE,10000,\"Coffee, cake\",Food,"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("quoted fields are parsed correctly") {
                result.imported shouldBe 1
                result.skipped shouldBe 0
            }
        }
    }

    Given("a CSV file with too few columns") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description\n2026-03-01,EXPENSE,10000"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("the row is skipped with not enough columns error") {
                result.imported shouldBe 0
                result.skipped shouldBe 1
                result.errors[0].reason shouldBe "Not enough columns. Expected at least: date, type, amount, description."
            }
        }
    }

    Given("a user not in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } throws NotFoundException("COUPLE_NOT_FOUND", "User is not in an active couple.")

        When("importCsv is called") {
            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.importCsv(user1.id, mockFile("header\ndata"))
                }
                ex.code shouldBe "COUPLE_NOT_FOUND"
            }
        }
    }

    Given("a CSV with more than 1000 rows") {
        setupCommonMocks()

        val header = "date,type,amount,description,categoryName,paymentMethodName"
        val rows = (1..1001).joinToString("\n") { "2026-03-01,EXPENSE,1000,Item $it,Food," }
        val csv = "$header\n$rows"

        When("importCsv is called") {
            Then("throws BusinessException for exceeding max rows") {
                val ex = shouldThrow<BusinessException> {
                    service.importCsv(user1.id, mockFile(csv))
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    Given("a CSV with rows that need batching") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        // 60 rows should result in 2 batch saves (50 + 10)
        val header = "date,type,amount,description,categoryName,paymentMethodName"
        val rows = (1..60).joinToString("\n") { "2026-03-01,EXPENSE,1000,Item $it,Food," }
        val csv = "$header\n$rows"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("all rows are imported in batches") {
                result.imported shouldBe 60
                result.skipped shouldBe 0
            }

            Then("saveAll is called twice (batch size 50)") {
                verify(exactly = 2) { transactionRepository.saveAll(any<List<Transaction>>()) }
            }
        }
    }

    Given("a CSV file with empty description") {
        setupCommonMocks()
        every { transactionRepository.saveAll(any<List<Transaction>>()) } answers { firstArg() }

        val csv = "date,type,amount,description,categoryName,paymentMethodName\n2026-03-01,EXPENSE,10000,,Food,"

        When("importCsv is called") {
            val result = service.importCsv(user1.id, mockFile(csv))

            Then("the row is skipped with empty description error") {
                result.imported shouldBe 0
                result.skipped shouldBe 1
                result.errors[0].reason shouldBe "Description cannot be empty."
            }
        }
    }
})
