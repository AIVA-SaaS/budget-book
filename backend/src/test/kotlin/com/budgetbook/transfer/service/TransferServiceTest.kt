package com.budgetbook.transfer.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.common.dto.PatchValue
import com.budgetbook.common.exception.BusinessException
import com.budgetbook.common.exception.NotFoundException
import com.budgetbook.couple.domain.Couple
import com.budgetbook.couple.domain.CoupleStatus
import com.budgetbook.couple.service.CoupleResolver
import com.budgetbook.paymentmethod.domain.PaymentMethod
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.paymentmethod.repository.PaymentMethodRepository
import com.budgetbook.sync.SyncEventPublisher
import com.budgetbook.transfer.domain.Transfer
import com.budgetbook.transfer.domain.TransferKind
import com.budgetbook.transfer.repository.TransferRepository
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.time.LocalDate
import java.util.Optional
import java.util.UUID

class TransferServiceTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val transferRepository = mockk<TransferRepository>()
    val coupleResolver = mockk<CoupleResolver>()
    val userRepository = mockk<UserRepository>()
    val paymentMethodRepository = mockk<PaymentMethodRepository>()
    val syncEventPublisher = mockk<SyncEventPublisher>(relaxed = true)
    val transactionRepository = mockk<com.budgetbook.transaction.repository.TransactionRepository>(relaxed = true)
    val service = TransferService(transferRepository, coupleResolver, userRepository, paymentMethodRepository, syncEventPublisher, transactionRepository)

    val user1 = User(email = "u1@test.com", nickname = "U1", provider = AuthProvider.GOOGLE, providerId = "g1")
    val user2 = User(email = "u2@test.com", nickname = "U2", provider = AuthProvider.KAKAO, providerId = "k2")
    val couple = Couple(user1 = user1, user2 = user2, status = CoupleStatus.ACTIVE)
    val otherCouple = Couple(user1 = user2, user2 = user1, status = CoupleStatus.ACTIVE)

    val sourcePm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
    val destPm = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH)
    val otherCouplePm = PaymentMethod(couple = otherCouple, name = "Other", type = PaymentMethodType.BANK)

    // --- createTransfer ---

    Given("a user in an active couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        When("creating a transfer with valid data") {
            every { paymentMethodRepository.findById(sourcePm.id) } returns Optional.of(sourcePm)
            every { paymentMethodRepository.findById(destPm.id) } returns Optional.of(destPm)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val request = com.budgetbook.transfer.dto.CreateTransferRequest(
                sourcePaymentMethodId = sourcePm.id,
                destinationPaymentMethodId = destPm.id,
                amount = 100000,
                description = "ATM 출금",
                transferDate = LocalDate.of(2026, 3, 25)
            )
            val result = service.createTransfer(user1.id, request)

            Then("creates transfer with correct fields") {
                result.amount shouldBe 100000
                result.description shouldBe "ATM 출금"
                result.sourcePaymentMethod.id shouldBe sourcePm.id
                result.destinationPaymentMethod.id shouldBe destPm.id
                result.author.id shouldBe user1.id
            }
        }

        When("creating a transfer where source equals destination") {
            val request = com.budgetbook.transfer.dto.CreateTransferRequest(
                sourcePaymentMethodId = sourcePm.id,
                destinationPaymentMethodId = sourcePm.id,
                amount = 50000,
                transferDate = LocalDate.of(2026, 3, 25)
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.createTransfer(user1.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }

        When("creating a transfer with payment method from another couple") {
            every { paymentMethodRepository.findById(sourcePm.id) } returns Optional.of(sourcePm)
            every { paymentMethodRepository.findById(otherCouplePm.id) } returns Optional.of(otherCouplePm)

            val request = com.budgetbook.transfer.dto.CreateTransferRequest(
                sourcePaymentMethodId = sourcePm.id,
                destinationPaymentMethodId = otherCouplePm.id,
                amount = 50000,
                transferDate = LocalDate.of(2026, 3, 25)
            )

            Then("throws ForbiddenException") {
                shouldThrow<com.budgetbook.common.exception.ForbiddenException> {
                    service.createTransfer(user1.id, request)
                }
            }
        }

        When("creating a transfer with nonexistent payment method") {
            val fakeId = UUID.randomUUID()
            every { paymentMethodRepository.findById(fakeId) } returns Optional.empty()

            val request = com.budgetbook.transfer.dto.CreateTransferRequest(
                sourcePaymentMethodId = fakeId,
                destinationPaymentMethodId = destPm.id,
                amount = 50000,
                transferDate = LocalDate.of(2026, 3, 25)
            )

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.createTransfer(user1.id, request)
                }
                ex.code shouldBe "PAYMENT_METHOD_NOT_FOUND"
            }
        }
    }

    // --- CREDIT↔CREDIT transfer validation ---

    Given("a user creating CREDIT to CREDIT transfer") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        val creditSource = PaymentMethod(couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT, settlementDay = 15, closingDay = 10)
        val creditDest = PaymentMethod(couple = couple, name = "국민카드", type = PaymentMethodType.CREDIT, settlementDay = 20, closingDay = 15)

        When("creating a transfer from CREDIT to CREDIT") {
            every { paymentMethodRepository.findById(creditSource.id) } returns Optional.of(creditSource)
            every { paymentMethodRepository.findById(creditDest.id) } returns Optional.of(creditDest)

            val request = com.budgetbook.transfer.dto.CreateTransferRequest(
                sourcePaymentMethodId = creditSource.id,
                destinationPaymentMethodId = creditDest.id,
                amount = 50000,
                transferDate = LocalDate.of(2026, 3, 25)
            )

            Then("throws BusinessException with TRANSFER_CREDIT_TO_CREDIT_NOT_ALLOWED") {
                val ex = shouldThrow<BusinessException> {
                    service.createTransfer(user1.id, request)
                }
                ex.code shouldBe "TRANSFER_CREDIT_TO_CREDIT_NOT_ALLOWED"
            }
        }

        When("creating a transfer from CREDIT to BANK (allowed)") {
            val bankPm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
            every { paymentMethodRepository.findById(creditSource.id) } returns Optional.of(creditSource)
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val request = com.budgetbook.transfer.dto.CreateTransferRequest(
                sourcePaymentMethodId = creditSource.id,
                destinationPaymentMethodId = bankPm.id,
                amount = 50000,
                transferDate = LocalDate.of(2026, 3, 25)
            )
            val result = service.createTransfer(user1.id, request)

            Then("succeeds") {
                result.amount shouldBe 50000
            }
        }
    }

    // --- updateTransfer CREDIT↔CREDIT ---

    Given("an existing transfer to update with CREDIT sources") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val creditSource = PaymentMethod(couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT, settlementDay = 15, closingDay = 10)
        val creditDest = PaymentMethod(couple = couple, name = "국민카드", type = PaymentMethodType.CREDIT, settlementDay = 20, closingDay = 15)

        val transfer = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = sourcePm, destinationPaymentMethod = destPm,
            amount = 50000, transferDate = LocalDate.of(2026, 3, 15)
        )
        every { transferRepository.findByIdAndCoupleId(transfer.id, couple.id) } returns transfer
        every { paymentMethodRepository.findById(creditSource.id) } returns Optional.of(creditSource)
        every { paymentMethodRepository.findById(creditDest.id) } returns Optional.of(creditDest)
        every { transferRepository.save(any()) } answers { firstArg() }

        When("updating both source and dest to CREDIT") {
            val request = com.budgetbook.transfer.dto.UpdateTransferRequest(
                sourcePaymentMethodId = PatchValue(creditSource.id),
                destinationPaymentMethodId = PatchValue(creditDest.id)
            )

            Then("throws TRANSFER_CREDIT_TO_CREDIT_NOT_ALLOWED") {
                val ex = shouldThrow<BusinessException> {
                    service.updateTransfer(user1.id, transfer.id, request)
                }
                ex.code shouldBe "TRANSFER_CREDIT_TO_CREDIT_NOT_ALLOWED"
            }
        }
    }

    // --- listTransfers ---

    Given("transfers exist for a couple") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val transfer = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = sourcePm, destinationPaymentMethod = destPm,
            amount = 100000, description = "ATM", transferDate = LocalDate.of(2026, 3, 15)
        )
        every {
            transferRepository.findByCoupleIdAndTransferDateBetweenOrderByTransferDateDesc(
                couple.id, LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 31)
            )
        } returns listOf(transfer)

        When("listing transfers for March 2026") {
            val result = service.listTransfers(user1.id, 2026, 3)

            Then("returns the transfer list") {
                result.size shouldBe 1
                result[0].amount shouldBe 100000
            }
        }
    }

    // --- getTransfer ---

    Given("a transfer exists") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val transfer = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = sourcePm, destinationPaymentMethod = destPm,
            amount = 50000, description = "이체", transferDate = LocalDate.of(2026, 3, 10)
        )

        When("getting the transfer by id") {
            every { transferRepository.findByIdAndCoupleId(transfer.id, couple.id) } returns transfer

            val result = service.getTransfer(user1.id, transfer.id)

            Then("returns the transfer") {
                result.id shouldBe transfer.id
                result.amount shouldBe 50000
            }
        }

        When("getting a nonexistent transfer") {
            val fakeId = UUID.randomUUID()
            every { transferRepository.findByIdAndCoupleId(fakeId, couple.id) } returns null

            Then("throws NotFoundException") {
                val ex = shouldThrow<NotFoundException> {
                    service.getTransfer(user1.id, fakeId)
                }
                ex.code shouldBe "TRANSFER_NOT_FOUND"
            }
        }
    }

    // --- updateTransfer ---

    Given("an existing transfer to update") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val transfer = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = sourcePm, destinationPaymentMethod = destPm,
            amount = 100000, description = "ATM", transferDate = LocalDate.of(2026, 3, 15)
        )
        every { transferRepository.findByIdAndCoupleId(transfer.id, couple.id) } returns transfer

        When("updating amount and description") {
            every { transferRepository.save(any()) } answers { firstArg() }

            val request = com.budgetbook.transfer.dto.UpdateTransferRequest(
                amount = 200000,
                description = PatchValue("Updated ATM")
            )
            val result = service.updateTransfer(user1.id, transfer.id, request)

            Then("updates the fields") {
                result.amount shouldBe 200000
                result.description shouldBe "Updated ATM"
            }
        }

        When("updating source to same as destination") {
            every { paymentMethodRepository.findById(destPm.id) } returns Optional.of(destPm)
            every { transferRepository.save(any()) } answers { firstArg() }

            val request = com.budgetbook.transfer.dto.UpdateTransferRequest(
                sourcePaymentMethodId = PatchValue(destPm.id)
            )

            Then("throws BusinessException") {
                val ex = shouldThrow<BusinessException> {
                    service.updateTransfer(user1.id, transfer.id, request)
                }
                ex.code shouldBe "VALIDATION_ERROR"
            }
        }
    }

    // --- deleteTransfer ---

    Given("a transfer to delete") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val transfer = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = sourcePm, destinationPaymentMethod = destPm,
            amount = 30000, transferDate = LocalDate.of(2026, 3, 5)
        )

        When("deleting the transfer") {
            every { transferRepository.findByIdAndCoupleId(transfer.id, couple.id) } returns transfer
            every { transferRepository.delete(transfer) } returns Unit

            service.deleteTransfer(user1.id, transfer.id)

            Then("deletes and publishes event") {
                verify { transferRepository.delete(transfer) }
                verify { syncEventPublisher.publish(match { it.type == "TRANSFER_DELETED" }) }
            }
        }

        When("deleting a nonexistent transfer") {
            val fakeId = UUID.randomUUID()
            every { transferRepository.findByIdAndCoupleId(fakeId, couple.id) } returns null

            Then("throws NotFoundException") {
                shouldThrow<NotFoundException> {
                    service.deleteTransfer(user1.id, fakeId)
                }
            }
        }
    }

    // --- Phase 22: TransferKind 자동 판정 (§2.1) ---

    Given("a user creating a transfer without specifying kind") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        // 다양한 결제수단 타입 준비
        val bankPm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
        val bankPm2 = PaymentMethod(couple = couple, name = "국민은행", type = PaymentMethodType.BANK)
        val cashPm = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH)
        val creditPm = PaymentMethod(
            couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
            settlementDay = 15, closingDay = 10
        )

        fun makeRequest(src: PaymentMethod, dst: PaymentMethod) =
            com.budgetbook.transfer.dto.CreateTransferRequest(
                sourcePaymentMethodId = src.id,
                destinationPaymentMethodId = dst.id,
                amount = 100000,
                transferDate = LocalDate.of(2026, 4, 1)
            )

        When("src=BANK, dst=CREDIT (카드 결제 흐름)") {
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            every { paymentMethodRepository.findById(creditPm.id) } returns Optional.of(creditPm)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val result = service.createTransfer(user1.id, makeRequest(bankPm, creditPm))

            Then("auto-resolves to CARD_SETTLEMENT") {
                result.kind shouldBe TransferKind.CARD_SETTLEMENT
                @Suppress("DEPRECATION")
                transferSlot.captured.isCardSettlement shouldBe true
            }
        }

        When("src=CREDIT, dst=BANK (카드→은행 환급성 이체)") {
            every { paymentMethodRepository.findById(creditPm.id) } returns Optional.of(creditPm)
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val result = service.createTransfer(user1.id, makeRequest(creditPm, bankPm))

            Then("auto-resolves to GENERIC (사용자 명시로 INCOME_TRANSFER 전환 가능)") {
                result.kind shouldBe TransferKind.GENERIC
                @Suppress("DEPRECATION")
                transferSlot.captured.isCardSettlement shouldBe false
            }
        }

        When("src=BANK, dst=BANK (순수 내부 이동)") {
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            every { paymentMethodRepository.findById(bankPm2.id) } returns Optional.of(bankPm2)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val result = service.createTransfer(user1.id, makeRequest(bankPm, bankPm2))

            Then("auto-resolves to GENERIC") {
                result.kind shouldBe TransferKind.GENERIC
            }
        }

        When("src=CASH, dst=BANK (현금→은행)") {
            every { paymentMethodRepository.findById(cashPm.id) } returns Optional.of(cashPm)
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val result = service.createTransfer(user1.id, makeRequest(cashPm, bankPm))

            Then("auto-resolves to GENERIC") {
                result.kind shouldBe TransferKind.GENERIC
            }
        }

        When("src=BANK, dst=CASH (은행→현금)") {
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            every { paymentMethodRepository.findById(cashPm.id) } returns Optional.of(cashPm)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val result = service.createTransfer(user1.id, makeRequest(bankPm, cashPm))

            Then("auto-resolves to GENERIC") {
                result.kind shouldBe TransferKind.GENERIC
            }
        }
    }

    Given("a user explicitly specifying kind overrides auto-judgment") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        val bankPm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
        val cashPm = PaymentMethod(couple = couple, name = "현금", type = PaymentMethodType.CASH)

        When("BANK → CASH 이체에 kind=EXPENSE_TRANSFER 명시") {
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            every { paymentMethodRepository.findById(cashPm.id) } returns Optional.of(cashPm)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val request = com.budgetbook.transfer.dto.CreateTransferRequest(
                sourcePaymentMethodId = bankPm.id,
                destinationPaymentMethodId = cashPm.id,
                amount = 50000,
                transferDate = LocalDate.of(2026, 4, 1),
                kind = TransferKind.EXPENSE_TRANSFER
            )
            val result = service.createTransfer(user1.id, request)

            Then("uses explicitly-specified EXPENSE_TRANSFER, not GENERIC") {
                result.kind shouldBe TransferKind.EXPENSE_TRANSFER
            }
        }

        When("CASH → BANK 이체에 kind=INCOME_TRANSFER 명시") {
            every { paymentMethodRepository.findById(cashPm.id) } returns Optional.of(cashPm)
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val request = com.budgetbook.transfer.dto.CreateTransferRequest(
                sourcePaymentMethodId = cashPm.id,
                destinationPaymentMethodId = bankPm.id,
                amount = 50000,
                transferDate = LocalDate.of(2026, 4, 1),
                kind = TransferKind.INCOME_TRANSFER
            )
            val result = service.createTransfer(user1.id, request)

            Then("uses explicitly-specified INCOME_TRANSFER") {
                result.kind shouldBe TransferKind.INCOME_TRANSFER
            }
        }
    }

    Given("createCardSettlement always forces kind=CARD_SETTLEMENT") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        val bankPm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
        val creditPm = PaymentMethod(
            couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
            settlementDay = 15, closingDay = 10
        )

        When("creating a card settlement") {
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            every { paymentMethodRepository.findById(creditPm.id) } returns Optional.of(creditPm)
            val transferSlot = slot<Transfer>()
            every { transferRepository.save(capture(transferSlot)) } answers { transferSlot.captured }

            val result = service.createCardSettlement(
                userId = user1.id,
                sourcePaymentMethodId = bankPm.id,
                destinationPaymentMethodId = creditPm.id,
                amount = 500000,
                transferDate = LocalDate.of(2026, 4, 15),
                description = "카드 결제",
                transactionIds = emptyList()
            )

            Then("saved Transfer has kind=CARD_SETTLEMENT and isCardSettlement=true") {
                result.kind shouldBe TransferKind.CARD_SETTLEMENT
                @Suppress("DEPRECATION")
                transferSlot.captured.isCardSettlement shouldBe true
            }
        }
    }

    Given("updateTransfer allows changing kind") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val transfer = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = sourcePm, destinationPaymentMethod = destPm,
            amount = 100000, transferDate = LocalDate.of(2026, 4, 1),
            kind = TransferKind.GENERIC
        )
        every { transferRepository.findByIdAndCoupleId(transfer.id, couple.id) } returns transfer
        every { transferRepository.save(any()) } answers { firstArg() }

        When("kind is patched to EXPENSE_TRANSFER") {
            val request = com.budgetbook.transfer.dto.UpdateTransferRequest(
                kind = com.budgetbook.common.dto.PatchValue(TransferKind.EXPENSE_TRANSFER)
            )
            val result = service.updateTransfer(user1.id, transfer.id, request)

            Then("kind is updated") {
                result.kind shouldBe TransferKind.EXPENSE_TRANSFER
            }
        }
    }

    // --- V63: card settlement link persistence ---

    Given("createCardSettlement with selected transactions") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple
        every { userRepository.findById(user1.id) } returns Optional.of(user1)

        val bankPm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
        val creditPm = PaymentMethod(
            couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
            settlementDay = 15, closingDay = 10
        )
        val txnIds = listOf(UUID.randomUUID(), UUID.randomUUID())

        When("creating a card settlement linking those transactions") {
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            every { paymentMethodRepository.findById(creditPm.id) } returns Optional.of(creditPm)
            val savedTransfer = Transfer(
                couple = couple, author = user1,
                sourcePaymentMethod = bankPm, destinationPaymentMethod = creditPm,
                amount = 500000, transferDate = LocalDate.of(2026, 4, 15),
                kind = TransferKind.CARD_SETTLEMENT, isCardSettlement = true
            )
            every { transferRepository.save(any()) } returns savedTransfer
            every {
                transactionRepository.markAsPaidForSettlement(txnIds, LocalDate.of(2026, 4, 15), savedTransfer.id)
            } returns txnIds.size

            service.createCardSettlement(
                userId = user1.id,
                sourcePaymentMethodId = bankPm.id,
                destinationPaymentMethodId = creditPm.id,
                amount = 500000,
                transferDate = LocalDate.of(2026, 4, 15),
                description = "카드 결제",
                transactionIds = txnIds
            )

            Then("marks transactions as paid with the settlement transfer link") {
                verify {
                    transactionRepository.markAsPaidForSettlement(txnIds, LocalDate.of(2026, 4, 15), savedTransfer.id)
                }
            }
        }
    }

    Given("updateCardSettlement re-adjusts paid_at for old and new selections") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val bankPm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
        val creditPm = PaymentMethod(
            couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
            settlementDay = 15, closingDay = 10
        )
        val settlement = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = bankPm, destinationPaymentMethod = creditPm,
            amount = 300000, transferDate = LocalDate.of(2026, 4, 15),
            kind = TransferKind.CARD_SETTLEMENT, isCardSettlement = true
        )
        val newTxnIds = listOf(UUID.randomUUID())

        When("updating with a new transaction selection") {
            every { transferRepository.findByIdAndCoupleId(settlement.id, couple.id) } returns settlement
            every { paymentMethodRepository.findById(bankPm.id) } returns Optional.of(bankPm)
            every { paymentMethodRepository.findById(creditPm.id) } returns Optional.of(creditPm)
            every { transferRepository.save(any()) } answers { firstArg() }
            every { transactionRepository.unmarkBySettlementTransfer(settlement.id) } returns 2
            every {
                transactionRepository.markAsPaidForSettlement(newTxnIds, LocalDate.of(2026, 4, 20), settlement.id)
            } returns newTxnIds.size

            val result = service.updateCardSettlement(
                userId = user1.id,
                transferId = settlement.id,
                sourcePaymentMethodId = bankPm.id,
                destinationPaymentMethodId = creditPm.id,
                amount = 450000,
                transferDate = LocalDate.of(2026, 4, 20),
                description = "수정된 카드 결제",
                transactionIds = newTxnIds
            )

            Then("unmarks old links then marks the new selection, and updates fields") {
                verify { transactionRepository.unmarkBySettlementTransfer(settlement.id) }
                verify {
                    transactionRepository.markAsPaidForSettlement(newTxnIds, LocalDate.of(2026, 4, 20), settlement.id)
                }
                result.amount shouldBe 450000
                result.transferDate shouldBe LocalDate.of(2026, 4, 20)
                verify { syncEventPublisher.publish(match { it.type == "CARD_SETTLEMENT_UPDATED" }) }
            }
        }

        When("updating a transfer that is not a card settlement") {
            val generic = Transfer(
                couple = couple, author = user1,
                sourcePaymentMethod = bankPm, destinationPaymentMethod = creditPm,
                amount = 100000, transferDate = LocalDate.of(2026, 4, 1),
                kind = TransferKind.GENERIC
            )
            every { transferRepository.findByIdAndCoupleId(generic.id, couple.id) } returns generic

            Then("throws NOT_A_CARD_SETTLEMENT") {
                val ex = shouldThrow<BusinessException> {
                    service.updateCardSettlement(
                        userId = user1.id,
                        transferId = generic.id,
                        sourcePaymentMethodId = bankPm.id,
                        destinationPaymentMethodId = creditPm.id,
                        amount = 100000,
                        transferDate = LocalDate.of(2026, 4, 1),
                        description = null,
                        transactionIds = emptyList()
                    )
                }
                ex.code shouldBe "NOT_A_CARD_SETTLEMENT"
            }
        }
    }

    Given("deleting a card settlement restores linked transactions") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val bankPm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
        val creditPm = PaymentMethod(
            couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
            settlementDay = 15, closingDay = 10
        )
        val settlement = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = bankPm, destinationPaymentMethod = creditPm,
            amount = 300000, transferDate = LocalDate.of(2026, 4, 15),
            kind = TransferKind.CARD_SETTLEMENT, isCardSettlement = true
        )

        When("deleting the card settlement") {
            every { transferRepository.findByIdAndCoupleId(settlement.id, couple.id) } returns settlement
            every { transactionRepository.unmarkBySettlementTransfer(settlement.id) } returns 2
            every { transferRepository.delete(settlement) } returns Unit

            service.deleteTransfer(user1.id, settlement.id)

            Then("unmarks linked transactions before deleting") {
                verify { transactionRepository.unmarkBySettlementTransfer(settlement.id) }
                verify { transferRepository.delete(settlement) }
            }
        }
    }

    Given("a generic transfer delete does not touch settlement links") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val generic = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = sourcePm, destinationPaymentMethod = destPm,
            amount = 30000, transferDate = LocalDate.of(2026, 3, 5),
            kind = TransferKind.GENERIC
        )

        When("deleting the generic transfer") {
            every { transferRepository.findByIdAndCoupleId(generic.id, couple.id) } returns generic
            every { transferRepository.delete(generic) } returns Unit

            service.deleteTransfer(user1.id, generic.id)

            Then("does not call unmarkBySettlementTransfer") {
                verify(exactly = 0) { transactionRepository.unmarkBySettlementTransfer(any()) }
                verify { transferRepository.delete(generic) }
            }
        }
    }

    Given("updateTransfer rejects card settlements") {
        every { coupleResolver.getActiveCouple(user1.id) } returns couple

        val bankPm = PaymentMethod(couple = couple, name = "신한은행", type = PaymentMethodType.BANK)
        val creditPm = PaymentMethod(
            couple = couple, name = "신한카드", type = PaymentMethodType.CREDIT,
            settlementDay = 15, closingDay = 10
        )
        val settlement = Transfer(
            couple = couple, author = user1,
            sourcePaymentMethod = bankPm, destinationPaymentMethod = creditPm,
            amount = 300000, transferDate = LocalDate.of(2026, 4, 15),
            kind = TransferKind.CARD_SETTLEMENT, isCardSettlement = true
        )

        When("attempting to update a CARD_SETTLEMENT via the generic update path") {
            every { transferRepository.findByIdAndCoupleId(settlement.id, couple.id) } returns settlement

            Then("throws CARD_SETTLEMENT_EDIT_NOT_ALLOWED") {
                val ex = shouldThrow<BusinessException> {
                    service.updateTransfer(
                        user1.id,
                        settlement.id,
                        com.budgetbook.transfer.dto.UpdateTransferRequest(amount = 999999)
                    )
                }
                ex.code shouldBe "CARD_SETTLEMENT_EDIT_NOT_ALLOWED"
            }
        }
    }
})
