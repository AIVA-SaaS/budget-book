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
    val service = TransferService(transferRepository, coupleResolver, userRepository, paymentMethodRepository, syncEventPublisher)

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
})
