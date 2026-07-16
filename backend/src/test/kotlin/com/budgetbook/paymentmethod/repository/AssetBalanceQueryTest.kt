package com.budgetbook.paymentmethod.repository

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.transaction.domain.Transaction
import com.budgetbook.transaction.domain.TransactionType
import com.budgetbook.transaction.repository.TransactionRepository
import com.budgetbook.transfer.domain.Transfer
import com.budgetbook.transfer.repository.TransferRepository
import io.kotest.core.spec.style.FunSpec
import io.kotest.extensions.spring.SpringExtension
import io.kotest.matchers.shouldBe
import jakarta.persistence.EntityManager
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.context.TestPropertySource
import org.springframework.transaction.PlatformTransactionManager
import org.springframework.transaction.support.TransactionTemplate
import java.time.LocalDate
import java.util.UUID

/**
 * Repository-level test for the date-bounded (`< asOf`) asset-balance queries.
 *
 * Runs against H2 (PostgreSQL mode) via @DataJpaTest so the JPQL `AND ... < :asOf`
 * boundary is actually executed — proving exclusivity of the upper bound, which a
 * MockK service test cannot verify.
 */
@DataJpaTest
@ActiveProfiles("test")
@TestPropertySource(properties = [
    "spring.datasource.url=jdbc:h2:mem:asset-balance;DB_CLOSE_DELAY=-1;MODE=PostgreSQL",
    "spring.jpa.hibernate.ddl-auto=create-drop",
    "spring.flyway.enabled=false",
    "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect"
])
class AssetBalanceQueryTest(
    @Autowired private val transactionRepository: TransactionRepository,
    @Autowired private val transferRepository: TransferRepository,
    @Autowired private val em: EntityManager,
    @Autowired private val txManager: PlatformTransactionManager,
) : FunSpec() {

    override fun extensions() = listOf(SpringExtension)

    init {
        lateinit var coupleId: UUID
        lateinit var bankId: UUID
        lateinit var cashId: UUID

        val asOf = LocalDate.of(2024, 5, 1)

        beforeSpec {
            TransactionTemplate(txManager).execute {
            val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
            val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
            em.persist(user1)
            em.persist(user2)
            val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
            em.persist(couple)
            coupleId = couple.id

            val bank = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK, displayOrder = 0)
            val cash = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH, displayOrder = 1)
            em.persist(bank)
            em.persist(cash)
            bankId = bank.id
            cashId = cash.id

            fun tx(type: TransactionType, amount: Long, date: LocalDate, pm: PaymentMethod) {
                em.persist(
                    Transaction(
                        couple = couple, author = user1, type = type, amount = amount,
                        description = "t", transactionDate = date, paymentMethod = pm
                    )
                )
            }

            fun transfer(amount: Long, date: LocalDate, src: PaymentMethod, dest: PaymentMethod) {
                em.persist(
                    Transfer(
                        couple = couple, author = user1, sourcePaymentMethod = src,
                        destinationPaymentMethod = dest, amount = amount, transferDate = date
                    )
                )
            }

            // --- bank transactions ---
            tx(TransactionType.INCOME, 500_000L, LocalDate.of(2024, 4, 20), bank)   // before asOf: counts
            tx(TransactionType.EXPENSE, 100_000L, LocalDate.of(2024, 4, 25), bank)  // before asOf: counts
            tx(TransactionType.ADJUSTMENT, -20_000L, LocalDate.of(2024, 4, 30), bank) // signed delta, counts
            tx(TransactionType.INCOME, 999_999L, asOf, bank)                         // ON asOf: EXCLUDED
            tx(TransactionType.INCOME, 999_999L, LocalDate.of(2024, 6, 1), bank)     // after asOf: EXCLUDED

            // --- transfers: cash -> bank (bank is dest = inflow, cash is source = outflow) ---
            transfer(100_000L, LocalDate.of(2024, 4, 28), cash, bank)               // before asOf: counts
            transfer(70_000L, asOf, cash, bank)                                     // ON asOf: EXCLUDED

            em.flush()
            em.clear()
            }
        }

        test("netAmountByPaymentMethodForCoupleUpTo: excludes tx on/after asOf, includes ADJUSTMENT as signed delta") {
            val net = transactionRepository.netAmountByPaymentMethodForCoupleUpTo(coupleId, asOf)
                .associate { it[0] as UUID to (it[1] as Number).toLong() }

            // 500000 (INCOME) - 100000 (EXPENSE) + (-20000) (ADJUSTMENT) = 380000
            // the 999999 income ON asOf and the one AFTER asOf are excluded
            net[bankId] shouldBe 380_000L
        }

        test("transfer sums up to asOf: dest inflow counted before asOf, on-asOf transfer excluded") {
            val inflow = transferRepository.sumAmountByDestinationForCoupleUpTo(coupleId, asOf)
                .associate { it[0] as UUID to (it[1] as Number).toLong() }
            val outflow = transferRepository.sumAmountBySourceForCoupleUpTo(coupleId, asOf)
                .associate { it[0] as UUID to (it[1] as Number).toLong() }

            // only the 100000 transfer (2024-04-28) is < asOf; the 70000 ON asOf is excluded
            inflow[bankId] shouldBe 100_000L      // bank as destination
            outflow[cashId] shouldBe 100_000L     // cash as source
        }

        test("full asOf balance: bank = txNet + transferIn - transferOut") {
            val net = transactionRepository.netAmountByPaymentMethodForCoupleUpTo(coupleId, asOf)
                .associate { it[0] as UUID to (it[1] as Number).toLong() }
            val inflow = transferRepository.sumAmountByDestinationForCoupleUpTo(coupleId, asOf)
                .associate { it[0] as UUID to (it[1] as Number).toLong() }
            val outflow = transferRepository.sumAmountBySourceForCoupleUpTo(coupleId, asOf)
                .associate { it[0] as UUID to (it[1] as Number).toLong() }

            val bankBalance = (net[bankId] ?: 0L) + (inflow[bankId] ?: 0L) - (outflow[bankId] ?: 0L)
            // 380000 + 100000 - 0 = 480000
            bankBalance shouldBe 480_000L
        }
    }
}
